// AccessRank Algorithm by Fitchett and Cockburn:
// http://www.cosc.canterbury.ac.nz/andrew.cockburn/papers/AccessRank-camera.pdf

import Foundation

public protocol AccessRankDelegate {
    func accessRankDidUpdatePredictions(accessRank: AccessRank)
}

public class AccessRank {

    public var delegate: AccessRankDelegate?
    
    public enum ListStability {
        case Low, Medium, High
    }
    public var listStability: ListStability
    private var listStabilityValue: (l: Double, d: Double) {
        switch listStability {
        case .Low:
            return (l: 1.65, d: 0.0)
        case .Medium:
            return (l: 1.65, d: 0.2)
        case .High:
            return (l: 2.50, d: 0.5)
        }
    }
    public var useTimeWeighting = true
    
    private var items = [String: ItemState]()
    private var visitNumber = 0
    
    public var initialItem = "<access_rank_nil>"
    private var mostRecentItemID: String
    public var mostRecentItem: String? {
        return mostRecentItemID == initialItem ? nil : mostRecentItemID
    }
    
    private var predictionList = [ScoredItem]()
    public var predictions: [String] {
        return predictionList.map { $0.id }.filter { [unowned self] item in
           item != self.mostRecentItemID
        }
    }
    
    public init(listStability: ListStability = .Medium, data: [String: AnyObject]? = nil) {
        self.listStability = listStability
        self.mostRecentItemID = initialItem
        if (data) {
            fromDictionary(data!)
        }
    }
    
    //MARK: Item updating and removal
    
    public func visitItem(item: String?) {
        if !item {
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
    
    private func stateForItem(item: String) -> ItemState {
        return items[item] ? items[item]! : ItemState()
    }
    
    public func removeItems(itemsToRemove: [String]) {
        for item in itemsToRemove {
            removeItem(item)
        }
        
        if contains(itemsToRemove, mostRecentItemID) {
            visitItem(nil)
        }
        
        updatePredictionList()
    }
    
    private func removeItem(item: String) {
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
    
    //MARK: Prediction list
    
    private func updatePredictionList()  {
        updateScoredItems()
        sortPredictionList()
        updateItemRanks()
        addItemsToPredictionList()
        
        delegate?.accessRankDidUpdatePredictions(self)
    }
    
    private func updateScoredItems() {
        for (index, scoredItem) in enumerate(predictionList) {
            predictionList[index] = ScoredItem(
                id: scoredItem.id,
                score: scoreForItem(scoredItem.id))
        }
    }
    
    private func sortPredictionList() {
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
    
    private func updateItemRanks() {
        for (index, scoredItem) in enumerate(predictionList) {
            var item = items[scoredItem.id]!
            item.updateRank(index)
            items[scoredItem.id] = item
        }
    }
    
    private func addItemsToPredictionList() {
        let item = items[mostRecentItemID]!
        if (mostRecentItemID != initialItem) && item.numberOfVisits == 1 {
            predictionList += ScoredItem(id: mostRecentItemID, score: 0.0)
        }
    }
    
    //MARK: Combined score
    
    private func scoreForItem(item: String) -> Double {
        let l = listStabilityValue.l
        let wm = markovWeightForItem(item)
        let wcrf = crfWeightForItem(item)
        let wt = useTimeWeighting ? timeWeightForItem(item) : 1.0
        
        return pow(wm, l) * pow(wcrf, 1 / l) * wt
    }
    
    //MARK: Markov weight
    
    private func markovWeightForItem(item: String) -> Double {
        let xn = Double(numberOfVisitsForMostRecentItem())
        let x = Double(numberOfTransitionsFromMostRecentItemToItem(item))
        
        return (x + 1) / (xn + 1)
    }
    
    private func numberOfVisitsForMostRecentItem() -> Int {
        let numVisits = items[mostRecentItemID]?.numberOfVisits
        return numVisits ? numVisits! : 0
    }
    
    private func numberOfTransitionsFromMostRecentItemToItem(item: String) -> Int {
        let numTransitions = items[mostRecentItemID]?.numberOfTransitionsToItem(item)
        return numTransitions ? numTransitions! : 0
    }
    
    //MARK: CRF weight
    
    private func crfWeightForItem(item: String) -> Double {
        return items[item]!.crfWeight
    }
    
    //MARK: Time weight

    private func timeWeightForItem(item: String) -> Double {
        let rh = hourOfDayRatioForItem(item)
        let rd = dayOfWeekRatioForItem(item)
        
        return pow(max(0.8, min(1.25, rh * rd)), 0.25)
    }
    
    //MARK: Time weight: Ratio for time of day
    
    private func hourOfDayRatioForItem(item: String) -> Double {
        if (numberOfCurrentHourItemVisits() < 10) {
            return 1.0
        }
        return Double(numberOfCurrentHourVisitsToItem(item)) / averageNumberOfCurrentHourVisitsToItem(item)
    }
    
    private func numberOfCurrentHourItemVisits() -> Int {
        var numVisits = 0
        for (_, itemState) in items {
            numVisits += itemState.numberOfVisitsToItemsInCurrentHourSlot()
        }
        return numVisits
    }
    
    private func numberOfCurrentHourVisitsToItem(item: String) -> Int {
        let currentHour = NSCalendar.currentCalendar().components(
            NSCalendarUnit.CalendarUnitHour, fromDate: NSDate()).hour
        
        return numberOfVisitsToItem(item, inTimeSlotAtHour: currentHour)
    }
    
    private func averageNumberOfCurrentHourVisitsToItem(item: String) -> Double {
        var totalVisits = 0
        var hourOfDay = 1
        
        while hourOfDay < 24 {
            totalVisits += numberOfVisitsToItem(item, inTimeSlotAtHour: hourOfDay)
            hourOfDay += 3
        }
        return Double(totalVisits) / 8
    }
    
    private func numberOfVisitsToItem(item: String, inTimeSlotAtHour hourOfDay: Int) -> Int {
        var numVisits = 0
        for (_, itemState) in items {
            numVisits += itemState.numberOfVisitsToItem(item, inTimeSlotAtHour: hourOfDay)
        }
        return numVisits;
    }
    
    //MARK: Time weight: Ratio for day of week
    
    private func dayOfWeekRatioForItem(item: String) -> Double {
        if (numberOfCurrentWeekdayItemVisits() < 10) {
            return 1.0
        }
        return Double(numberOfCurrentWeekdayVisitsToItem(item)) / averageNumberOfWeekdayVisitsToItem(item)
    }
    
    private func numberOfCurrentWeekdayItemVisits() -> Int {
        var numVisits = 0
        for (_, itemState) in items {
            numVisits += itemState.numberOfVisitsToItemsAtCurrentWeekday()
        }
        return numVisits
    }
    
    private func numberOfCurrentWeekdayVisitsToItem(item: String) -> Int {
        let currentWeekday = NSCalendar.currentCalendar().components(
            NSCalendarUnit.CalendarUnitWeekday, fromDate: NSDate()).weekday
        
        return numberOfVisitsToItem(item, atWeekday: currentWeekday)
    }
    
    private func averageNumberOfWeekdayVisitsToItem(item: String) -> Double {
        var totalVisits = 0
        for weekday in 1...7 {
            totalVisits += numberOfVisitsToItem(item, atWeekday: weekday)
        }
        return Double(totalVisits) / 7
    }
    
    private func numberOfVisitsToItem(item: String, atWeekday weekday: Int) -> Int {
        var numVisits = 0
        for (itemID, itemState) in items {
            numVisits += itemState.numberOfVisitsToItem(item, atWeekday: weekday)
        }
        return numVisits;
    }
    
    //MARK: Convenience methods for persisting and restoring the data structure
    
    public func toDictionary() -> [String: AnyObject] {
        var itemsObj = [String: [String: AnyObject]]()
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
    
    private func fromDictionary(dict: [String: AnyObject]) {
        if let itemsObj = dict["items"]! as? [String: [String: AnyObject]] {
            items = [String: ItemState]()
            for (itemID, itemStateObj) in itemsObj {
                items[itemID] = ItemState(data: itemStateObj)
            }
        }
        
        if let predictionListObj = dict["predictionList"]! as? [[String: AnyObject]] {
            predictionList = predictionListObj.map { ScoredItem(data: $0) }
        }
        
        if let visitNumberValue = dict["visitNumber"]! as? Int {
            visitNumber = visitNumberValue
        }
        
        if let mostRecentItemIDValue = dict["mostRecentItemID"]! as? String {
            mostRecentItemID = mostRecentItemIDValue
        }
    }
    
    //MARK: Structs
    
    private struct ItemVisit {
        var id: String
        var hour: Int
        var weekday: Int
        
        init(id: String, hour: Int, weekday: Int) {
            self.id = id
            self.hour = hour
            self.weekday = weekday
        }
        
        init(data: [String: AnyObject]) {
            let idValue: AnyObject = data["id"]!
            let hourValue: AnyObject = data["hour"]!
            let weekdayValue: AnyObject = data["weekday"]!
            
            self.id = idValue as String
            self.hour = hourValue as Int
            self.weekday = weekdayValue as Int
        }
        
        func toDictionary() -> [String: AnyObject] {
            return [
                "id": id,
                "hour": hour,
                "weekday": weekday]
        }
    }
    
    private struct ItemState {
        var nextVisits = [String: [ItemVisit]]()
        var visitNumber = 0
        var numberOfVisits = 0
        var timeOfLastVisit: NSTimeInterval = 0
        var crfWeight = 0.0
        var rank = Int.max
        
        init() {}
        
        init(data: [String: AnyObject]) {
            let nextVisitsObj = data["nextVisits"]! as? [String: [[String: AnyObject]]]
            var nextVisitsValue = [String: [ItemVisit]]()
            for (itemID, itemVisitsObj) in nextVisitsObj! {
                nextVisitsValue[itemID] = itemVisitsObj.map { ItemVisit(data: $0) }
            }
            
            let visitNumberValue: AnyObject = data["visitNumber"]!
            let numberOfVisitsValue: AnyObject = data["numberOfVisits"]!
            let timeOfLastVisitValue: AnyObject = data["timeOfLastVisit"]!
            let crfWeightValue: AnyObject = data["crfWeight"]!
            let rankValue: AnyObject = data["rank"]!
            
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
            
            var nextVisitsToItem = nextVisits[item] ? nextVisits[item]! : [ItemVisit]()
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
        
        func toDictionary() -> [String: AnyObject] {
            var nextVisitsObj = [String: [[String: AnyObject]]]()
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
            var items = [String]()
            for (itemID, _) in nextVisits {
                let count = nextVisits[itemID]?.count
                items += "\(itemID) (\(String(count!)))"
            }
            return join(", ", items)
        }
    }
    
    private struct ScoredItem {
        var id: String
        var score: Double
        
        init(id: String, score: Double) {
            self.id = id
            self.score = score
        }
        
        init(data: [String: AnyObject]) {
            let idValue: AnyObject = data["id"]!
            let scoreValue: AnyObject = data["score"]!
            
            self.id = idValue as String
            self.score = scoreValue as Double
        }
        
        func toDictionary() -> [String: AnyObject] {
            return [
                "id": id,
                "score": score]
        }
    }
    
    // Debugging
    
    public func markovDescription() -> String {
        var str = ""
        for (item, itemState) in items {
            str += "\(item) > \(itemState.markovDescription())\n"
        }
        return str
    }
    
    public func scoreDescription() -> String {
        var str = ""
        for (_, scoredItem) in enumerate(predictionList) {
            str += "\(scoredItem.id): score: \(scoredItem.score), markov: \(markovWeightForItem(scoredItem.id)), crf: \(crfWeightForItem(scoredItem.id)), time: \(timeWeightForItem(scoredItem.id))\n"
        }
        return str
    }
    
    public func predictionListDescription() -> String {
        var str = ""
        for scoredItem in predictionList {
            str += "\(scoredItem.id): \(scoredItem.score)\n"
        }
        return str
    }
    
}