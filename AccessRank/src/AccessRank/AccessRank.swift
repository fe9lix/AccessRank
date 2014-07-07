// AccessRank Algorithm by Fitchett and Cockburn:
// http://www.cosc.canterbury.ac.nz/andrew.cockburn/papers/AccessRank-camera.pdf

import Foundation

protocol AccessRankDelegate {
    func accessRankDidUpdatePredictions(accessRank: AccessRank)
}

class AccessRank {

    var delegate: AccessRankDelegate?
    
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
    var useTimeWeighting = true
    
    var items = Dictionary<String, ItemState>()
    var initialItemID = "<initial>"
    var visitNumber: Int = 0
    
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
            updatePredictionList()
        }
    }
    
    // Item updating and removal
    
    var mostRecentItem: String? {
        didSet {
            visitNumber += 1
            
            let previousItem = oldValue ? oldValue! : initialItemID
            var previousItemState = stateForItem(previousItem)
            previousItemState.addVisitToItem(mostRecentItemID, visitNumber: visitNumber)
            items[previousItem] = previousItemState
            
            var newItemState = stateForItem(mostRecentItemID)
            newItemState.increaseVisits()
            items[mostRecentItemID] = newItemState
            
            updatePredictionList()
        }
    }
    
    func stateForItem(item: String) -> ItemState {
        return items[item] ? items[item]! : ItemState()
    }
    
    var mostRecentItemID: String {
        return mostRecentItem ? mostRecentItem! : initialItemID
    }
    
    func removeItems(itemsToRemove: String[]) {
        for item in itemsToRemove {
            removeItem(item)
        }
        
        if contains(itemsToRemove, mostRecentItemID) {
            let oldMostRecentItem = mostRecentItemID
            mostRecentItem = nil
            items.removeValueForKey(oldMostRecentItem)
        } else {
            updatePredictionList()
        }
    }
    
    func removeItem(item: String) {
        for (itemID, var itemState) in items {
            if itemID == item {
                items.removeValueForKey(itemID)
            } else {
                itemState.removeVisitsToItem(item)
            }
        }
        
        for (index, scoredItem) in enumerate(predictionList) {
            if (scoredItem.id == item) {
                predictionList.removeAtIndex(index)
            }
        }
    }
    
    // Prediction list
    
    func updatePredictionList()  {
        updateScoredItems()
        sortPredictionList()
        updateItemRanks()
        addItemsToPredictionList()
        
        delegate?.accessRankDidUpdatePredictions(self)
    }
    
    func updateScoredItems() {
        for (index, scoredItem) in enumerate(predictionList) {
            predictionList[index] = ScoredItem(
                id: scoredItem.id,
                score: scoreForItem(scoredItem.id))
        }
    }
    
    func sortPredictionList() {
        predictionList.sort { [unowned self] A, B in
            var itemA = self.items[A.id]!
            var itemB = self.items[B.id]!
            
            if (itemA.rank < itemB.rank) && (B.score > A.score) {
                let stableScoreA = A.score + self.listStabilityValue.d
                if B.score > stableScoreA {
                    return false
                } else {
                    if B.score == stableScoreA {
                        return itemA.timeOfLastVisit > itemB.timeOfLastVisit
                    } else {
                        return true
                    }
                }
            }
            
            if (itemA.rank > itemB.rank) && (B.score < A.score) {
                let stableScoreB = B.score + self.listStabilityValue.d
                if A.score > stableScoreB {
                    return true
                } else {
                    if A.score == stableScoreB {
                        return itemA.timeOfLastVisit > itemB.timeOfLastVisit
                    } else {
                        return false
                    }
                }
            }
            
            return A.score > B.score
        }
    }
    
    func updateItemRanks() {
        for (index, scoredItem) in enumerate(predictionList) {
            var item = items[scoredItem.id]!
            item.changeRank(index)
            items[scoredItem.id] = item
        }
    }
    
    func addItemsToPredictionList() {
        let item = items[mostRecentItemID]!
        if (mostRecentItemID != initialItemID) && item.numberOfVisits == 1 {
            predictionList += ScoredItem(id: mostRecentItemID, score: 0.0)
        }
    }
    
    // Combined score
    
    func scoreForItem(item: String) -> Double {
        let l = listStabilityValue.l
        let wm = markovWeightForItem(item)
        let wcrf = combinedRecencyFrequencyWeightForItem(item)
        let wt = useTimeWeighting ? timeWeightForItem(item) : 1.0
        
        return pow(wm, l) * pow(wcrf, 1 / l) * wt
    }
    
    // Markov weight
    
    func markovWeightForItem(item: String) -> Double {
        let xn = Double(numberOfVisitsForMostRecentItem())
        let x = Double(numberOfTransitionsFromMostRecentItemToItem(item))
        
        return (x + 1) / (xn + 1)
    }
    
    func numberOfVisitsForMostRecentItem() -> Int {
        let numVisits = items[mostRecentItemID]?.numberOfVisits
        return numVisits ? numVisits! : 0
    }
    
    func numberOfTransitionsFromMostRecentItemToItem(item: String) -> Int {
        let numTransitions = items[mostRecentItemID]?.numberOfTransitionsToItem(item)
        return numTransitions ? numTransitions! : 0
    }
    
    // CRF weight
    
    func combinedRecencyFrequencyWeightForItem(item: String) -> Double {
        let p = 2.0
        let l = 0.1
        
        return visitsToItem(item).reduce(0.0, { [unowned self] weight, itemVisit in
            return weight + pow(1 / p, l * Double(self.visitNumber - itemVisit.visitNumber))
        })
    }
    
    func visitsToItem(item: String) -> ItemVisit[] {
        var visits = ItemVisit[]()
        for (_, itemState) in items {
            if let itemVisits = itemState.nextVisits[item] {
                visits += itemVisits
            }
        }
        return visits
    }
    
    // Time weight

    func timeWeightForItem(item: String) -> Double {
        let rh = hourOfDayRatioForItem(item)
        let rd = dayOfWeekRatioForItem(item)
        
        return pow(max(0.8, min(1.25, rh * rd)), 0.25)
    }
    
    // Time weight: Ratio for time of day
    
    func hourOfDayRatioForItem(item: String) -> Double {
        if (numberOfCurrentHourItemVisits() < 10) {
            return 1.0
        }
        return Double(numberOfCurrentHourVisitsToItem(item)) / averageNumberOfCurrentHourVisitsToItem(item)
    }
    
    func numberOfCurrentHourItemVisits() -> Int {
        var numVisits = 0
        for (_, itemState) in items {
            numVisits += itemState.numberOfVisitsToItemsInCurrentHourSlot()
        }
        return numVisits
    }
    
    func numberOfCurrentHourVisitsToItem(item: String) -> Int {
        let currentHour = NSCalendar.currentCalendar().components(
            NSCalendarUnit.CalendarUnitHour, fromDate: NSDate()).hour
        return numberOfVisitsToItem(item, inTimeSlotAtHour: currentHour)
    }
    
    func averageNumberOfCurrentHourVisitsToItem(item: String) -> Double {
        var totalVisits = 0
        var hourOfDay = 1
        
        while hourOfDay < 24 {
            totalVisits += numberOfVisitsToItem(item, inTimeSlotAtHour: hourOfDay)
            hourOfDay += 3
        }
        return Double(totalVisits) / 8
    }
    
    func numberOfVisitsToItem(item: String, inTimeSlotAtHour hourOfDay: Int) -> Int {
        var numVisits = 0
        for (itemID, itemState) in items {
            numVisits += itemState.numberOfVisitsToItem(itemID, inTimeSlotAtHour: hourOfDay)
        }
        return numVisits;
    }
    
    // Time weight: Ratio for day of week
    
    func dayOfWeekRatioForItem(item: String) -> Double {
        if (numberOfCurrentWeekdayItemVisits() < 10) {
            return 1.0
        }
        return Double(numberOfCurrentWeekdayVisitsToItem(item)) / averageNumberOfWeekdayVisitsToItem(item)
    }
    
    func numberOfCurrentWeekdayItemVisits() -> Int {
        var numVisits = 0
        for (_, itemState) in items {
            numVisits += itemState.numberOfVisitsToItemsAtCurrentWeekday()
        }
        return numVisits
    }
    
    func numberOfCurrentWeekdayVisitsToItem(item: String) -> Int {
        let currentWeekday = NSCalendar.currentCalendar().components(
            NSCalendarUnit.CalendarUnitWeekday, fromDate: NSDate()).weekday
        return numberOfVisitsToItem(item, atWeekday: currentWeekday)
    }
    
    func averageNumberOfWeekdayVisitsToItem(item: String) -> Double {
        var totalVisits = 0
        for weekday in 1...7 {
            totalVisits += numberOfVisitsToItem(item, atWeekday: weekday)
        }
        return Double(totalVisits) / 7
    }
    
    func numberOfVisitsToItem(item: String, atWeekday weekday: Int) -> Int {
        var numVisits = 0
        for (itemID, itemState) in items {
            numVisits += itemState.numberOfVisitsToItem(itemID, atWeekday: weekday)
        }
        return numVisits;
    }
    
    // Convenience methods for persisting and restoring the data structure
    
    func toDictionary() -> Dictionary<String, AnyObject> {
        var itemsObj = Dictionary<String, Dictionary<String, AnyObject>>()
        for (itemID, itemState) in items {
            itemsObj[itemID] = itemState.toDictionary()
        }
        
        let predictionsListObj = predictionList.map { $0.toDictionary() }
        
        return [
            "items": itemsObj,
            "predictionList": predictionsListObj,
            "mostRecentItem": mostRecentItemID,
            "visitNumber": visitNumber]
    }
    
    func fromDictionary(dict: Dictionary<String, AnyObject>) {
        if let itemsObj = dict["items"]! as? Dictionary<String, Dictionary<String, AnyObject>> {
            items = Dictionary<String, ItemState>()
            for (itemID, itemStateObj) in itemsObj {
                items[itemID] = ItemState(data: itemStateObj)
            }
        }
        
        if let predictionListObj = dict["predictionList"]! as? Dictionary<String, AnyObject>[] {
            predictionList = predictionListObj.map { ScoredItem(data: $0) }
        }
        
        mostRecentItem = dict["mostRecentItem"]! as? String
        
        if let visitNumberValue = dict["visitNumber"]! as? Int {
            visitNumber = visitNumberValue
        }
    }
    
    // Structs
    
    struct ItemVisit {
        var id: String
        var hour: Int
        var weekday: Int
        var visitNumber: Int
        
        init(id: String, hour: Int, weekday: Int, visitNumber: Int) {
            self.id = id
            self.hour = hour
            self.weekday = weekday
            self.visitNumber = visitNumber
        }
        
        init(data: Dictionary<String, AnyObject>) {
            let idValue: AnyObject = data["id"]!
            let hourValue: AnyObject = data["hour"]!
            let weekdayValue: AnyObject = data["weekday"]!
            let visitNumberValue: AnyObject = data["visitNumber"]!
            
            self.id = idValue as String
            self.hour = hourValue as Int
            self.weekday = weekdayValue as Int
            self.visitNumber = visitNumberValue as Int
        }
        
        func toDictionary() -> Dictionary<String, AnyObject> {
            return [
                "id": id,
                "hour": hour,
                "weekday": weekday,
                "visitNumber": visitNumber]
        }
    }
    
    struct ItemState {
        var numberOfVisits: Int = 0
        var timeOfLastVisit: NSTimeInterval = 0
        var rank = Int.max
        var nextVisits = Dictionary<String, ItemVisit[]>()
        
        init() {}
        
        init(data: Dictionary<String, AnyObject>) {
            let numberOfVisitsValue: AnyObject = data["numberOfVisits"]!
            let timeOfLastVisitValue: AnyObject = data["timeOfLastVisit"]!
            let rankValue: AnyObject = data["rank"]!
            
            let nextVisitsObj = data["nextVisits"]! as? Dictionary<String,  Dictionary<String, AnyObject>[]>
            var nextVisitsValue = Dictionary<String, ItemVisit[]>()
            for (itemID, itemVisitsObj) in nextVisitsObj! {
                nextVisitsValue[itemID] = itemVisitsObj.map { ItemVisit(data: $0) }
            }
            
            self.numberOfVisits = numberOfVisitsValue as Int
            self.timeOfLastVisit = timeOfLastVisitValue as NSTimeInterval
            self.rank = rankValue as Int
            self.nextVisits = nextVisitsValue
        }
        
        mutating func increaseVisits() {
            numberOfVisits += 1
            timeOfLastVisit = NSDate().timeIntervalSince1970
        }
        
        mutating func addVisitToItem(item: String, visitNumber: Int) {
            var nextVisitsToItem = nextVisits[item] ? nextVisits[item]! : ItemVisit[]()
            let calendarComponents = NSCalendar.currentCalendar().components(
                NSCalendarUnit.CalendarUnitHour | NSCalendarUnit.CalendarUnitWeekday,
                fromDate: NSDate())
            
            nextVisitsToItem += ItemVisit(
                id: item,
                hour: calendarComponents.hour,
                weekday: calendarComponents.weekday,
                visitNumber: visitNumber)
            
            nextVisits[item] = nextVisitsToItem
        }
        
        mutating func removeVisitsToItem(item: String) {
            nextVisits.removeValueForKey(item)
        }
        
        mutating func changeRank(rank: Int) {
            self.rank = rank
        }
        
        func numberOfTransitionsToItem(item: String) -> Int {
            let num = nextVisits[item]?.count
            return num ? num! : 0
        }
        
        func numberOfVisitsToItemsInCurrentHourSlot() -> Int {
            let currentHour = NSCalendar.currentCalendar().components(
                NSCalendarUnit.CalendarUnitHour, fromDate: NSDate()).hour
            var numVisits = 0
            
            for (itemID, _) in nextVisits {
                numVisits += numberOfVisitsToItem(itemID, inTimeSlotAtHour: currentHour)
            }
            return numVisits
        }
        
        func numberOfVisitsToItem(item: String, inTimeSlotAtHour hourOfDay: Int) -> Int {
            var numVisits = 0
            
            if let itemVisits = nextVisits[item] {
                for itemVisit in itemVisits {
                    if (itemVisit.hour >= (hourOfDay - 1)) && (itemVisit.hour <= (hourOfDay + 1)) {
                        numVisits += 1
                    }
                }
            }
            return numVisits
        }
        
        func numberOfVisitsToItemsAtCurrentWeekday() -> Int {
            let currentWeekday = NSCalendar.currentCalendar().components(
                NSCalendarUnit.CalendarUnitHour, fromDate: NSDate()).weekday
            var numVisits = 0
            
            for (itemID, _) in nextVisits {
                numVisits += numberOfVisitsToItem(itemID, atWeekday: currentWeekday)
            }
            return numVisits
        }
        
        func numberOfVisitsToItem(item: String, atWeekday weekday: Int) -> Int {
            var numVisits = 0
            
            if let itemVisits = nextVisits[item] {
                for itemVisit in itemVisits {
                    if itemVisit.weekday == weekday {
                        numVisits += 1
                    }
                }
            }
            return numVisits
        }
        
        func toDictionary() -> Dictionary<String, AnyObject> {
            var nextVisitsObj = Dictionary<String,  Dictionary<String, AnyObject>[]>()
            for (itemID, itemVisits) in nextVisits {
                nextVisitsObj[itemID] = itemVisits.map { $0.toDictionary() }
            }
            
            return [
                "numberOfVisits": numberOfVisits,
                "timeOfLastVisit": timeOfLastVisit,
                "rank": rank,
                "nextVisits": nextVisitsObj]
        }
        
        func markovDescription() -> String {
            var items = String[]()
            for (itemID, _) in nextVisits {
                let count = nextVisits[itemID]?.count
                items += "\(itemID) (\(String(count!)))"
            }
            return join(", ", items)
        }
    }
    
    struct ScoredItem {
        var id: String
        var score: Double
        
        init(id: String, score: Double) {
            self.id = id
            self.score = score
        }
        
        init(data: Dictionary<String, AnyObject>) {
            let idValue: AnyObject = data["id"]!
            let scoreValue: AnyObject = data["score"]!
            
            self.id = idValue as String
            self.score = scoreValue as Double
        }
        
        func toDictionary() -> Dictionary<String, AnyObject> {
            return [
                "id": id,
                "score": score]
        }
    }
    
    // Debugging
    
    func markovDescription() -> String {
        var str = ""
        for (item, itemState) in items {
            str += "\(item) > \(itemState.markovDescription())\n"
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