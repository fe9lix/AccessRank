//
//  AccessRank.swift
//  AccessRank
//
//  Created by fe9lix on 20.06.14.
//
//  AccessRank Algorithm by Fitchett and Cockburn:
//  http://www.cosc.canterbury.ac.nz/andrew.cockburn/papers/AccessRank-camera.pdf

import Foundation

public protocol AccessRankDelegate: class {
    func accessRankDidUpdatePredictions(_ accessRank: AccessRank)
}

public class AccessRank {
    public enum ListStability {
        case low, medium, high
    }

    public weak var delegate: AccessRankDelegate?
    public var listStability: ListStability
    public var useTimeWeighting = true
    public var initialItem = "<access_rank_nil>"
    public var mostRecentItem: String? {
        return mostRecentItemID == initialItem ? nil : mostRecentItemID
    }
    public var predictions: [String] {
        return predictionList.map { $0.id }.filter { item in
            item != mostRecentItemID
        }
    }
    
    private var listStabilityValue: (l: Double, d: Double) {
        switch listStability {
        case .low:
            return (l: 1.65, d: 0.0)
        case .medium:
            return (l: 1.65, d: 0.2)
        case .high:
            return (l: 2.50, d: 0.5)
        }
    }
    private var items = [String: ItemState]()
    private var visitNumber = 0
    private var mostRecentItemID: String
    private var predictionList = [ScoredItem]()

    public init(listStability: ListStability = .medium, snapshot: [String: Any]? = nil) {
        self.listStability = listStability
        self.mostRecentItemID = initialItem
        
        if let snapshot = snapshot {
            fromDictionary(snapshot)
        }
    }
    
    // MARK: - Item updates
    
    public func visitItem(_ item: String?) {
        guard let item = item else {
            mostRecentItemID = initialItem
            return
        }
            
        visitNumber += 1
            
        let previousItem = mostRecentItemID
        mostRecentItemID = item
            
        var previousItemState = stateForItem(previousItem)
        previousItemState.addVisitToItem(mostRecentItemID)
        items[previousItem] = previousItemState
        
        var newItemState = stateForItem(mostRecentItemID)
        newItemState.updateVisits(visitNumber)
        items[mostRecentItemID] = newItemState
                    
        updatePredictionList()
    }
    
    private func stateForItem(_ item: String) -> ItemState {
        return items[item] ?? ItemState()
    }
    
    public func removeItems(_ itemsToRemove: [String]) {
        for item in itemsToRemove {
            removeItem(item)
        }
        
        if itemsToRemove.contains(mostRecentItemID) {
            visitItem(nil)
        }
        
        updatePredictionList()
    }
    
    private func removeItem(_ item: String) {
        for (itemID, var itemState) in items {
            if itemID == item {
                items.removeValue(forKey: itemID)
            } else {
                itemState.removeVisitsToItem(item)
                items[itemID] = itemState
            }
        }
        
        if let index = predictionList.index(where: { $0.id == item }) {
            predictionList.remove(at: index)
        }
    }
    
    // MARK: - Prediction list
    
    private func updatePredictionList()  {
        updateScoredItems()
        sortPredictionList()
        updateItemRanks()
        addItemsToPredictionList()
        
        delegate?.accessRankDidUpdatePredictions(self)
    }
    
    private func updateScoredItems() {
        for (index, scoredItem) in predictionList.enumerated() {
            predictionList[index] = ScoredItem(
                id: scoredItem.id,
                score: scoreForItem(scoredItem.id)
            )
        }
    }
    
    private func sortPredictionList() {
        predictionList.sort { A, B in
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
        for (index, scoredItem) in predictionList.enumerated() {
            var item = items[scoredItem.id]!
            item.updateRank(index)
            items[scoredItem.id] = item
        }
    }
    
    private func addItemsToPredictionList() {
        let item = items[mostRecentItemID]!
        if mostRecentItemID != initialItem && item.numberOfVisits == 1 {
            predictionList.append(ScoredItem(id: mostRecentItemID, score: 0.0))
        }
    }
    
    // MARK: - Combined score
    
    private func scoreForItem(_ item: String) -> Double {
        let l = listStabilityValue.l
        let wm = markovWeightForItem(item)
        let wcrf = crfWeightForItem(item)
        let wt = useTimeWeighting ? timeWeightForItem(item) : 1.0
        
        return pow(wm, l) * pow(wcrf, 1 / l) * wt
    }
    
    // MARK: - Markov weight
    
    private func markovWeightForItem(_ item: String) -> Double {
        let xn = Double(numberOfVisitsForMostRecentItem())
        let x = Double(numberOfTransitionsFromMostRecentItemToItem(item))
        
        return (x + 1) / (xn + 1)
    }
    
    private func numberOfVisitsForMostRecentItem() -> Int {
        return items[mostRecentItemID]?.numberOfVisits ?? 0
    }
    
    private func numberOfTransitionsFromMostRecentItemToItem(_ item: String) -> Int {
        return items[mostRecentItemID]?.numberOfTransitionsToItem(item) ?? 0
    }
    
    // MARK: - CRF weight
    
    private func crfWeightForItem(_ item: String) -> Double {
        return items[item]!.crfWeight
    }
    
    // MARK: - Time weight

    private func timeWeightForItem(_ item: String) -> Double {
        let rh = hourOfDayRatioForItem(item)
        let rd = dayOfWeekRatioForItem(item)
        
        return pow(max(0.8, min(1.25, rh * rd)), 0.25)
    }
    
    // MARK: - Time weight (Ratio for time of day)
    
    private func hourOfDayRatioForItem(_ item: String) -> Double {
        if numberOfCurrentHourItemVisits() < 10 {
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
    
    private func numberOfCurrentHourVisitsToItem(_ item: String) -> Int {
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        return numberOfVisitsToItem(item, inTimeSlotAtHour: currentHour)
    }
    
    private func averageNumberOfCurrentHourVisitsToItem(_ item: String) -> Double {
        var totalVisits = 0
        var hourOfDay = 1
        
        while hourOfDay < 24 {
            totalVisits += numberOfVisitsToItem(item, inTimeSlotAtHour: hourOfDay)
            hourOfDay += 3
        }
        return Double(totalVisits) / 8
    }
    
    private func numberOfVisitsToItem(_ item: String, inTimeSlotAtHour hourOfDay: Int) -> Int {
        var numVisits = 0
        for (_, itemState) in items {
            numVisits += itemState.numberOfVisitsToItem(item, inTimeSlotAtHour: hourOfDay)
        }
        return numVisits;
    }
    
    // MARK: - Time weight (Ratio for day of week)
    
    private func dayOfWeekRatioForItem(_ item: String) -> Double {
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
    
    private func numberOfCurrentWeekdayVisitsToItem(_ item: String) -> Int {
        let currentWeekday = Calendar.current.component(.weekday, from: Date())
        
        return numberOfVisitsToItem(item, atWeekday: currentWeekday)
    }
    
    private func averageNumberOfWeekdayVisitsToItem(_ item: String) -> Double {
        var totalVisits = 0
        for weekday in 1...7 {
            totalVisits += numberOfVisitsToItem(item, atWeekday: weekday)
        }
        return Double(totalVisits) / 7
    }
    
    private func numberOfVisitsToItem(_ item: String, atWeekday weekday: Int) -> Int {
        var numVisits = 0
        for (_, itemState) in items {
            numVisits += itemState.numberOfVisitsToItem(item, atWeekday: weekday)
        }
        return numVisits;
    }
    
    // MARK: - Persistence
    
    public func toDictionary() -> [String: Any] {
        var itemsObj = [String: [String: Any]]()
        for (itemID, itemState) in items {
            itemsObj[itemID] = itemState.toDictionary()
        }
        
        let predictionsListObj = predictionList.map { $0.toDictionary() }
        
        return [
            "items": itemsObj,
            "predictionList": predictionsListObj,
            "visitNumber": visitNumber,
            "mostRecentItemID": mostRecentItemID
        ]
    }
    
    private func fromDictionary(_ dict: [String: Any]) {
        let itemsObj = dict["items"] as! [String: [String: Any]]
        items = [String: ItemState]()
        for (itemID, itemStateObj) in itemsObj {
            items[itemID] = ItemState(data: itemStateObj)
        }
        
        let predictionListObj = dict["predictionList"] as! [[String: Any]]
        predictionList = predictionListObj.map { ScoredItem(data: $0) }
        visitNumber = dict["visitNumber"] as! Int
        mostRecentItemID = dict["mostRecentItemID"] as! String
    }
    
    // MARK: - Structs
    
    private struct ItemVisit {
        var id: String
        var hour: Int
        var weekday: Int
        
        init(id: String, hour: Int, weekday: Int) {
            self.id = id
            self.hour = hour
            self.weekday = weekday
        }
        
        init(data: [String: Any]) {
            self.id = data["id"] as! String
            self.hour = data["hour"] as! Int
            self.weekday = data["weekday"] as! Int
        }
        
        func toDictionary() -> [String: Any] {
            return [
                "id": id,
                "hour": hour,
                "weekday": weekday
            ]
        }
    }
    
    private struct ItemState {
        var nextVisits = [String: [ItemVisit]]()
        var visitNumber = 0
        var numberOfVisits = 0
        var timeOfLastVisit: TimeInterval = 0
        var crfWeight = 0.0
        var rank = Int.max
        
        init() {}
        
        init(data: [String: Any]) {
            let nextVisitsObj = data["nextVisits"]! as? [String: [[String: Any]]]
            var nextVisitsValue = [String: [ItemVisit]]()
            for (itemID, itemVisitsObj) in nextVisitsObj! {
                nextVisitsValue[itemID] = itemVisitsObj.map { ItemVisit(data: $0) }
            }
            
            nextVisits = nextVisitsValue
            visitNumber = data["visitNumber"] as! Int
            numberOfVisits = data["numberOfVisits"] as! Int
            timeOfLastVisit = data["timeOfLastVisit"] as! TimeInterval
            crfWeight = data["crfWeight"] as! Double
            rank = data["rank"] as! Int
        }
        
        mutating func addVisitToItem(_ item: String) {
            let calendarComponents = Calendar.current.dateComponents([.hour, .weekday], from: Date())
            
            var nextVisitsToItem = nextVisits[item] ?? [ItemVisit]()
            nextVisitsToItem.append(ItemVisit(
                id: item,
                hour: calendarComponents.hour!,
                weekday: calendarComponents.weekday!
            ))
            
            nextVisits[item] = nextVisitsToItem
        }
        
        mutating func removeVisitsToItem(_ item: String) {
            nextVisits.removeValue(forKey: item)
        }
        
        mutating func updateVisits(_ visitNumber: Int) {
            numberOfVisits += 1
            timeOfLastVisit = Date().timeIntervalSince1970
            
            crfWeight = pow(2.0, -0.1 * Double(visitNumber - self.visitNumber)) * crfWeight
            crfWeight += 1.0
            self.visitNumber = visitNumber
        }
        
        mutating func updateRank(_ rank: Int) {
            self.rank = rank
        }
        
        func numberOfTransitionsToItem(_ item: String) -> Int {
            return nextVisits[item]?.count ?? 0
        }
        
        func numberOfVisitsToItemsInCurrentHourSlot() -> Int {
            let currentHour = Calendar.current.component(.hour, from: Date())
            var numVisits = 0
            
            for (itemID, _) in nextVisits {
                numVisits += numberOfVisitsToItem(itemID, inTimeSlotAtHour: currentHour)
            }
            return numVisits
        }
        
        func numberOfVisitsToItem(_ item: String, inTimeSlotAtHour hourOfDay: Int) -> Int {
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
            let currentWeekday = Calendar.current.component(.weekday, from: Date())
            var numVisits = 0
            
            for (itemID, _) in nextVisits {
                numVisits += numberOfVisitsToItem(itemID, atWeekday: currentWeekday)
            }
            return numVisits
        }
        
        func numberOfVisitsToItem(_ item: String, atWeekday weekday: Int) -> Int {
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
        
        func toDictionary() -> [String: Any] {
            var nextVisitsObj = [String: [[String: Any]]]()
            for (itemID, itemVisits) in nextVisits {
                nextVisitsObj[itemID] = itemVisits.map { $0.toDictionary() }
            }
            
            return [
                "nextVisits": nextVisitsObj,
                "visitNumber": visitNumber,
                "numberOfVisits": numberOfVisits,
                "timeOfLastVisit": timeOfLastVisit,
                "crfWeight": crfWeight,
                "rank": rank
            ]
        }
        
        func markovDescription() -> String {
            var items = [String]()
            for (itemID, _) in nextVisits {
                let count = nextVisits[itemID]?.count
                items.append("\(itemID) (\(String(count!)))")
            }
            return items.joined(separator: ", ")
        }
    }
    
    private struct ScoredItem {
        var id: String
        var score: Double
        
        init(id: String, score: Double) {
            self.id = id
            self.score = score
        }
        
        init(data: [String: Any]) {
            self.id = data["id"] as! String
            self.score = data["score"] as! Double
        }
        
        func toDictionary() -> [String: Any] {
            return [
                "id": id,
                "score": score
            ]
        }
    }
    
    // MARK: - Debugging
    
    public func markovDescription() -> String {
        var str = ""
        for (item, itemState) in items {
            str += "\(item) > \(itemState.markovDescription())\n"
        }
        return str
    }
    
    public func scoreDescription() -> String {
        var str = ""
        for (_, scoredItem) in predictionList.enumerated() {
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
