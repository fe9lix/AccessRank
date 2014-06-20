// AccessRank Algorithm by Fitchett and Cockburn:
// http://www.cosc.canterbury.ac.nz/andrew.cockburn/papers/AccessRank-camera.pdf

import Foundation

class AccessRank {
    
    struct ItemOccurrence {
        var id: String
        var time: NSTimeInterval
    }
    
    struct ScoredItem {
        var id: String
        var score: Double
    }
    
    enum ListStability {
        case Low, Medium, High
    }
    
    var listStability: ListStability
    var listStabilityValue: (l: Double, d: Double) {
        switch listStability {
        case .Low:
            return (l: 1.65, d: 0.0)
        case .Medium:
            return (l: 1.65, d: 0.2)
        case .High:
            return (l: 2.50, d: 0.5)
        }
    }
    
    let initialItem: String
    var items = Dictionary<String, ItemOccurrence[]>()
    
    var predictionList = ScoredItem[]()
    var predictions: String[] {
        return predictionList.map { $0.id }.filter { [unowned self] item in
           item != self.mostRecentItem
        }
    }
    
    init(listStability: ListStability = .Medium, initialItem: String = "<Initial>") {
        self.listStability = listStability
        self.initialItem = initialItem
        self.mostRecentItem = initialItem
    }
    
    var mostRecentItem: String {
        didSet {
            var nextItems = items[oldValue] ? items[oldValue]! : ItemOccurrence[]()
            nextItems += ItemOccurrence(id: mostRecentItem, time: NSDate().timeIntervalSince1970)
            items[oldValue] = nextItems
            updatePredictionList()
        }
    }
    
    func updatePredictionList()  {
        for (index, scoredItem) in enumerate(predictionList) {
            predictionList[index] = ScoredItem(id: scoredItem.id, score: scoreForItem(scoredItem.id))
        }
        
        predictionList.sort { [unowned self] A, B in
            return A.score > (B.score + self.listStabilityValue.d)
        }
        
        if !predictionsListContainsItem(mostRecentItem) {
            predictionList += ScoredItem(id: mostRecentItem, score: 0.0)
        }
    }
    
    func predictionsListContainsItem(item: String) -> Bool {
        for scoredItem in predictionList {
            if scoredItem.id == item {
                return true
            }
        }
        return false
    }
    
    func scoreForItem(item: String) -> Double {
        let a = 1.0 // adjust for different blend between Markov and CRF
        let wm = markovWeightForItem(item)
        let wcrf = combinedRecencyFrequencyWeightForItem(item)
        let wt = timeWeightForItem(item)
        
        return pow(wm, a) * pow(wcrf, 1 / a) * wt
    }
    
    func markovWeightForItem(item: String) -> Double {
        let xn = Double(numberOfOccurrencesForMostRecentItem())
        let x = Double(numberOfTransitionsFromMostRecentItemToItem(item))
        
        return (x + 1) / (xn + 1)
    }
    
    func numberOfOccurrencesForMostRecentItem() -> Int {
        return occurrencesForItem(mostRecentItem).count
    }
    
    func numberOfTransitionsFromMostRecentItemToItem(item: String) -> Int {
        if let nextItems = items[mostRecentItem] {
            return nextItems.reduce(0, { numTransitions, itemOccurrence in
                return itemOccurrence.id == item ? numTransitions + 1 : numTransitions
            })
        }
        return 0
    }
    
    func combinedRecencyFrequencyWeightForItem(item: String) -> Double {
        let currentTime = NSDate().timeIntervalSince1970
        let p = 2.0
        let l = listStabilityValue.l
        
        return occurrencesForItem(item).reduce(0.0, { weight, itemOccurrence in
            return weight + pow(1 / p, l * (currentTime - itemOccurrence.time))
        })
    }

    func timeWeightForItem(item: String) -> Double {
        let h = hourOfDayRatioForItem(item)
        let d = dayOfWeekRatioForItem(item)
        
        return pow(max(0.8, min(1.25, h * d)), 0.25)
    }
    
    func hourOfDayRatioForItem(item: String) -> Double {
        let numOfOccurrencesInCurrentHourSlot = numberOfOccurrencesInCurrentHourSlotForItem(item)
        if (numOfOccurrencesInCurrentHourSlot < 10) {
            return 1.0
        }
        return Double(numOfOccurrencesInCurrentHourSlot) / averageNumberOfOccurrencesInHourSlotForItem(item)
    }
    
    func numberOfOccurrencesInCurrentHourSlotForItem(item: String) -> Int {
        let currentHour = NSCalendar.currentCalendar().components(NSCalendarUnit.CalendarUnitHour, fromDate: NSDate()).hour
        return numberOfOccurrencesForItem(item, inTimeSlotAtHour: currentHour)
    }
    
    func averageNumberOfOccurrencesInHourSlotForItem(item: String) -> Double {
        var totalOccurrences = 0
        var hour = 1
        
        while hour < 24 {
            totalOccurrences += numberOfOccurrencesForItem(item, inTimeSlotAtHour: hour)
            hour += 3
        }
        return Double(totalOccurrences) / 8
    }
    
    func numberOfOccurrencesForItem(item: String, inTimeSlotAtHour hourOfDay: Int) -> Int {
        let calendar = NSCalendar.currentCalendar()
        
        return occurrencesForItem(item).filter({ itemOccurrence in
            let itemDate = NSDate(timeIntervalSince1970: itemOccurrence.time)
            let itemHour = calendar.components(NSCalendarUnit.CalendarUnitHour, fromDate: itemDate).hour
            return (itemHour >= (hourOfDay - 1)) && (itemHour <= (hourOfDay + 1))
        }).count
    }
    
    func dayOfWeekRatioForItem(item: String) -> Double {
        let numOccurrencesAtCurrentWeekday = numberOfOccurrencesAtCurrentWeekdayForItem(item)
        if (numOccurrencesAtCurrentWeekday < 10) {
            return 1.0
        }
        return Double(numOccurrencesAtCurrentWeekday) / averageNumberOfOccurrencesAcrossAllWeekdaysForItem(item)
    }
    
    func numberOfOccurrencesAtCurrentWeekdayForItem(item: String) -> Int {
        let currentWeekday = NSCalendar.currentCalendar().components(NSCalendarUnit.CalendarUnitWeekday, fromDate: NSDate()).weekday
        return numberOfOccurrencesForItem(item, atWeekday: currentWeekday)
    }
    
    func averageNumberOfOccurrencesAcrossAllWeekdaysForItem(item: String) -> Double {
        var totalOccurrences = 0
        for weekday in 1...7 {
            totalOccurrences += numberOfOccurrencesForItem(item, atWeekday: weekday)
        }
        return Double(totalOccurrences) / 7
    }
    
    func numberOfOccurrencesForItem(item: String, atWeekday weekday: Int) -> Int {
        let calendar = NSCalendar.currentCalendar()
        
        return occurrencesForItem(item).filter({ itemOccurrence in
            let itemDate = NSDate(timeIntervalSince1970: itemOccurrence.time)
            let itemWeekday = calendar.components(NSCalendarUnit.CalendarUnitWeekday, fromDate: itemDate).weekday
            return (itemWeekday == weekday)
        }).count
    }
    
    func occurrencesForItem(item: String) -> ItemOccurrence[] {
        var occurrences = ItemOccurrence[]()
        for (_, itemOccurrences) in items {
            for itemOccurrence in itemOccurrences {
                if (itemOccurrence.id == item) {
                    occurrences += itemOccurrence
                }
            }
        }
        return occurrences
    }
    
    func markovDescription() -> String {
        var str = ""
        for (item, itemOccurrences) in items {
            let nextItemsStr = join(", ", itemOccurrences.map { $0.id })
            str += "\(item) > \(nextItemsStr)\n"
        }
        return str
    }
    
    func scoreDescription() -> String {
        var str = ""
        for (_, scoredItem) in enumerate(predictionList) {
            str += "\(scoredItem.id): score: \(scoredItem.score), markov: \(markovWeightForItem(scoredItem.id)), crf: \(combinedRecencyFrequencyWeightForItem(scoredItem.id)), time: \(timeWeightForItem(scoredItem.id))\n"
        }
        return str
    }
    
    func predictionListDescription() -> String {
        var str = ""
        for scoredItem in predictionList {
            str += "\(scoredItem.id): \(scoredItem.score)\n"
        }
        return str
    }
    
}