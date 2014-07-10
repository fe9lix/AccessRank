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
    var visitNumber = 0
    
    var initialItem = "<access_rank_nil>"
    var mostRecentItemID: String
    var mostRecentItem: String? {
        return mostRecentItemID == initialItem ? nil : mostRecentItemID
    }
    
    var predictionList = ScoredItem[]()
    var predictions: String[] {
        return predictionList.map { $0.id }.filter { [unowned self] item in
           item != self.mostRecentItemID
        }
    }
    
    init(listStability: ListStability = .Medium, data: Dictionary<String, AnyObject>? = nil) {
        self.listStability = listStability
        self.mostRecentItemID = initialItem
        if (data) {
            fromDictionary(data!)
        }
    }
    
    // Item updating and removal
    
    func visitItem(item: String?) {
        if (!item) {
            mostRecentItemID = initialItem
            return
        }
            
        visitNumber += 1
            
        let previousItem = mostRecentItemID
        mostRecentItemID = item!
            
        var previousItemState = stateForItem(previousItem)
        previousItemState.addVisitToItem(mostRecentItemID)
        items[previousItem] = previousItemState
        
        var newItemState = stateForItem(mostRecentItemID)
        newItemState.updateVisits(visitNumber)
        items[mostRecentItemID] = newItemState
                    
        updatePredictionList()
    }
    
    func stateForItem(item: String) -> ItemState {
        return items[item] ? items[item]! : ItemState()
    }
    
    func removeItems(itemsToRemove: String[]) {
        for item in itemsToRemove {
            removeItem(item)
        }
        
        if contains(itemsToRemove, mostRecentItemID) {
            visitItem(nil)
        }
        
        updatePredictionList()
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
            let itemA = self.items[A.id]!
            let itemB = self.items[B.id]!
            var scoreA = A.score
            var scoreB = B.score
            
            if (itemA.rank < itemB.rank) && (scoreB > scoreA) {
                scoreA += self.listStabilityValue.d
            } else if (itemA.rank > itemB.rank) && (scoreB < scoreA) {
                scoreB += self.listStabilityValue.d
            }
            
            if scoreA == scoreB {
                return itemA.timeOfLastVisit > itemB.timeOfLastVisit
            } else {
                return scoreA > scoreB
            }
        }
    }
    
    func updateItemRanks() {
        for (index, scoredItem) in enumerate(predictionList) {
            var item = items[scoredItem.id]!
            item.updateRank(index)
            items[scoredItem.id] = item
        }
    }
    
    func addItemsToPredictionList() {
        let item = items[mostRecentItemID]!
        if (mostRecentItemID != initialItem) && item.numberOfVisits == 1 {
            predictionList += ScoredItem(id: mostRecentItemID, score: 0.0)
        }
    }
    
    // Combined score
    
    func scoreForItem(item: String) -> Double {
        let l = listStabilityValue.l
        let wm = markovWeightForItem(item)
        let wcrf = crfWeightForItem(item)
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
    
    func crfWeightForItem(item: String) -> Double {
        return items[item]!.crfWeight
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
        for (_, itemState) in items {
            numVisits += itemState.numberOfVisitsToItem(item, inTimeSlotAtHour: hourOfDay)
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
            numVisits += itemState.numberOfVisitsToItem(item, atWeekday: weekday)
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
            "visitNumber": visitNumber,
            "mostRecentItemID": mostRecentItemID]
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
        
        if let visitNumberValue = dict["visitNumber"]! as? Int {
            visitNumber = visitNumberValue
        }
        
        if let mostRecentItemIDValue = dict["mostRecentItemID"]! as? String {
            mostRecentItemID = mostRecentItemIDValue
        }
    }
    
    // Structs
    
    struct ItemVisit {
        var id: String
        var hour: Int
        var weekday: Int
        
        init(id: String, hour: Int, weekday: Int) {
            self.id = id
            self.hour = hour
            self.weekday = weekday
        }
        
        init(data: Dictionary<String, AnyObject>) {
            let idValue: AnyObject = data["id"]!
            let hourValue: AnyObject = data["hour"]!
            let weekdayValue: AnyObject = data["weekday"]!
            
            self.id = idValue as String
            self.hour = hourValue as Int
            self.weekday = weekdayValue as Int
        }
        
        func toDictionary() -> Dictionary<String, AnyObject> {
            return [
                "id": id,
                "hour": hour,
                "weekday": weekday]
        }
    }
    
    struct ItemState {
        var nextVisits = Dictionary<String, ItemVisit[]>()
        var visitNumber = 0
        var numberOfVisits = 0
        var timeOfLastVisit: NSTimeInterval = 0
        var crfWeight = 0.0
        var rank = Int.max
        
        init() {}
        
        init(data: Dictionary<String, AnyObject>) {
            let numberOfVisitsValue: AnyObject = data["numberOfVisits"]!
            let timeOfLastVisitValue: AnyObject = data["timeOfLastVisit"]!
            let rankValue: AnyObject = data["rank"]!
            let crfWeightValue: AnyObject = data["crfWeight"]!
            let visitNumberValue: AnyObject = data["visitNumber"]!
            
            let nextVisitsObj = data["nextVisits"]! as? Dictionary<String,  Dictionary<String, AnyObject>[]>
            var nextVisitsValue = Dictionary<String, ItemVisit[]>()
            for (itemID, itemVisitsObj) in nextVisitsObj! {
                nextVisitsValue[itemID] = itemVisitsObj.map { ItemVisit(data: $0) }
            }
            
            self.nextVisits = nextVisitsValue
            self.visitNumber = visitNumberValue as Int
            self.numberOfVisits = numberOfVisitsValue as Int
            self.timeOfLastVisit = timeOfLastVisitValue as NSTimeInterval
            self.crfWeight = crfWeightValue as Double
            self.rank = rankValue as Int
        }
        
        mutating func addVisitToItem(item: String) {
            let calendarComponents = NSCalendar.currentCalendar().components(
                NSCalendarUnit.CalendarUnitHour | NSCalendarUnit.CalendarUnitWeekday,
                fromDate: NSDate())
            
            var nextVisitsToItem = nextVisits[item] ? nextVisits[item]! : ItemVisit[]()
            nextVisitsToItem += ItemVisit(
                id: item,
                hour: calendarComponents.hour,
                weekday: calendarComponents.weekday)
            
            nextVisits[item] = nextVisitsToItem
        }
        
        mutating func removeVisitsToItem(item: String) {
            nextVisits.removeValueForKey(item)
        }
        
        mutating func updateVisits(visitNumber: Int) {
            numberOfVisits += 1
            timeOfLastVisit = NSDate().timeIntervalSince1970
            
            crfWeight = pow(2.0, -0.1 * Double(visitNumber - self.visitNumber)) * crfWeight
            crfWeight += 1.0
            self.visitNumber = visitNumber
        }
        
        mutating func updateRank(rank: Int) {
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
                "nextVisits": nextVisitsObj,
                "visitNumber": visitNumber,
                "numberOfVisits": numberOfVisits,
                "timeOfLastVisit": timeOfLastVisit,
                "crfWeight": crfWeight,
                "rank": rank]
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
            str += "\(scoredItem.id): score: \(scoredItem.score), markov: \(markovWeightForItem(scoredItem.id)), crf: \(crfWeightForItem(scoredItem.id)), time: \(timeWeightForItem(scoredItem.id))\n"
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