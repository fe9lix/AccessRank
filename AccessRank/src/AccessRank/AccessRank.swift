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
    
    var items = Dictionary<String, ItemOccurrence[]>()
    let initialItemID = "<initial>"
    
    var predictionList = ScoredItem[]()
    var predictions: String[] {
        return predictionList.map { $0.id }.filter { [unowned self] item in
           item != self.mostRecentItem
        }
    }
    
    init(listStability: ListStability = .Medium, data: Dictionary<String, AnyObject>? = nil) {
        self.listStability = listStability
        if (data) {
            fromDictionary(data!)
        }
    }
    
    // Item updating
    
    var mostRecentItem: String? {
        didSet {
            let previousItem = oldValue ? oldValue! : initialItemID
            var nextItems = items[previousItem] ? items[previousItem]! : ItemOccurrence[]()
            nextItems += ItemOccurrence(id: mostRecentItemID, time: NSDate().timeIntervalSince1970)
            items[previousItem] = nextItems
            updatePredictionList()
        }
    }
    
    var mostRecentItemID: String {
        return mostRecentItem ? mostRecentItem! : initialItemID
    }
    
    // Prediction list
    
    func updatePredictionList()  {
        for (index, scoredItem) in enumerate(predictionList) {
            predictionList[index] = ScoredItem(id: scoredItem.id, score: scoreForItem(scoredItem.id))
        }
        
        predictionList.sort { [unowned self] A, B in
            return A.score > (B.score + self.listStabilityValue.d)
        }
        
        if !predictionsListContainsItem(mostRecentItemID) {
            predictionList += ScoredItem(id: mostRecentItemID, score: 0.0)
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
    
    // Combined score
    
    func scoreForItem(item: String) -> Double {
        let a = 1.0 // adjust for different blend between Markov and CRF
        let wm = markovWeightForItem(item)
        let wcrf = combinedRecencyFrequencyWeightForItem(item)
        let wt = timeWeightForItem(item)
        
        return pow(wm, a) * pow(wcrf, 1 / a) * wt
    }
    
    // Markov weight
    
    func markovWeightForItem(item: String) -> Double {
        let xn = Double(numberOfOccurrencesForMostRecentItem())
        let x = Double(numberOfTransitionsFromMostRecentItemToItem(item))
        
        return (x + 1) / (xn + 1)
    }
    
    func numberOfOccurrencesForMostRecentItem() -> Int {
        return occurrencesForItem(mostRecentItemID).count
    }
    
    func numberOfTransitionsFromMostRecentItemToItem(item: String) -> Int {
        if let nextItems = items[mostRecentItemID] {
            return nextItems.reduce(0, { numTransitions, itemOccurrence in
                return itemOccurrence.id == item ? numTransitions + 1 : numTransitions
            })
        }
        return 0
    }
    
    // CRF weight
    
    func combinedRecencyFrequencyWeightForItem(item: String) -> Double {
        let currentTime = NSDate().timeIntervalSince1970
        let p = 2.0
        let l = listStabilityValue.l
        
        return occurrencesForItem(item).reduce(0.0, { weight, itemOccurrence in
            return weight + pow(1 / p, l * (currentTime - itemOccurrence.time))
        })
    }
    
    // Time weight

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
    
    // Helper methods
    
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
    
    // Convenience methods for persisting and restoring the data structure
    
    func toDictionary() -> Dictionary<String, AnyObject> {
        var itemsObj = Dictionary<String, Dictionary<String, AnyObject>[]>()
        for (itemID, itemOccurrences) in items {
            itemsObj[itemID] = itemOccurrences.map { ["id": $0.id, "time": $0.time] }
        }
        
        let predictionsListObj = predictionList.map { ["id": $0.id, "score": $0.score] }
        
        return [
            "mostRecentItem": mostRecentItemID,
            "items": itemsObj,
            "predictionList": predictionsListObj
        ]
    }
    
    func fromDictionary(dict: Dictionary<String, AnyObject>) {
        mostRecentItem = dict["mostRecentItem"]! as? String
        
        if let itemsObj = dict["items"]! as? Dictionary<String, Dictionary<String, AnyObject>[]> {
            items = Dictionary<String, ItemOccurrence[]>()
            for (itemID, itemOccurrencesObj) in itemsObj {
                items[itemID] = itemOccurrencesObj.map { itemOccurrenceObj in
                    let id: AnyObject = itemOccurrenceObj["id"]!
                    let time: AnyObject = itemOccurrenceObj["time"]!
                    return ItemOccurrence(id: id as String, time: time as NSTimeInterval)
                }
            }
        }
        
        if let predictionListObj = dict["predictionList"]! as? Dictionary<String, AnyObject>[] {
            predictionList = predictionListObj.map { scoredItemObj in
                let id: AnyObject = scoredItemObj["id"]!
                let score: AnyObject = scoredItemObj["score"]!
                return ScoredItem(id: id as String, score: score as Double)
            }
        }
    }
    
    // Debugging methods
    
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