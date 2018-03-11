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

public final class AccessRank: Codable {
    public enum ListStability: String, Codable {
        case low, medium, high
        
        var value: (l: Double, d: Double) {
            switch self {
            case .low: return (l: 1.65, d: 0.0)
            case .medium: return (l: 1.65, d: 0.2)
            case .high: return (l: 2.50, d: 0.5)
            }
        }
    }
    
    public weak var delegate: AccessRankDelegate?
    
    public var listStability: ListStability = .medium
    public var useTimeWeighting = true
    public var initialItem = "<access_rank_nil>"
    public var mostRecentItem: String? {
        return mostRecentItemID == initialItem ? nil : mostRecentItemID
    }
    public var predictions: [String] {
        return predictionList
            .map { $0.id }
            .filter { $0 != mostRecentItemID }
    }
    public var maxVisits: Int = 1000
    
    private var items = [String: ItemState]()
    private var visitNumber = 0
    private var mostRecentItemID: String
    private var predictionList = [ScoredItem]()
    
    public init(listStability: ListStability = .medium, maxVisits: Int = 1000) {
        self.listStability = listStability
        self.mostRecentItemID = initialItem
        self.maxVisits = maxVisits
    }
    
    // MARK: - Item updates
    
    public func visitItem(_ item: String?) {
        guard let item = item else {
            mostRecentItemID = initialItem
            return
        }
        
        visitNumber += 1
        visitNumber = min(visitNumber, maxVisits)
        
        let previousItem = mostRecentItemID
        mostRecentItemID = item
        
        var previousItemState = stateForItem(previousItem)
        previousItemState.addVisitToItem(mostRecentItemID, maxVisits: maxVisits)
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
        predictionList = predictionList.map { scoredItem in
            return ScoredItem(
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
                scoreA += self.listStability.value.d
            } else if (itemA.rank > itemB.rank) && (scoreB < scoreA) {
                scoreB += self.listStability.value.d
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
            predictionList = Array(predictionList.suffix(maxVisits))
        }
    }
    
    // MARK: - Combined score
    
    private func scoreForItem(_ item: String) -> Double {
        let l = listStability.value.l
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
        return items.reduce(into: 0) { (total, item) in
            total += item.value.numberOfVisitsToItemsInCurrentHourSlot()
        }
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
    
    private func numberOfVisitsToItem(_ itemId: String, inTimeSlotAtHour hourOfDay: Int) -> Int {
        return items.reduce(into: 0) { (total, item) in
            total += item.value.numberOfVisitsToItem(itemId, inTimeSlotAtHour: hourOfDay)
        }
    }
    
    // MARK: - Time weight (Ratio for day of week)
    
    private func dayOfWeekRatioForItem(_ item: String) -> Double {
        if (numberOfCurrentWeekdayItemVisits() < 10) {
            return 1.0
        }
        return Double(numberOfCurrentWeekdayVisitsToItem(item)) / averageNumberOfWeekdayVisitsToItem(item)
    }
    
    private func numberOfCurrentWeekdayItemVisits() -> Int {
        return items.reduce(into: 0) { (total, item) in
            total += item.value.numberOfVisitsToItemsAtCurrentWeekday()
        }
    }
    
    private func numberOfCurrentWeekdayVisitsToItem(_ item: String) -> Int {
        let currentWeekday = Calendar.current.component(.weekday, from: Date())
        
        return numberOfVisitsToItem(item, atWeekday: currentWeekday)
    }
    
    private func averageNumberOfWeekdayVisitsToItem(_ item: String) -> Double {
        let totalVisits = (1...7).reduce(0) { (total, weekday) in
            return total + numberOfVisitsToItem(item, atWeekday: weekday)
        }
        return Double(totalVisits) / 7
    }
    
    private func numberOfVisitsToItem(_ itemId: String, atWeekday weekday: Int) -> Int {
        return items.reduce(into: 0) { (total, item) in
            total += item.value.numberOfVisitsToItem(itemId, atWeekday: weekday)
        }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case listStability
        case useTimeWeighting
        case initialItem
        case items
        case visitNumber
        case mostRecentItemID
        case predictionList
        case maxVisits
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        listStability = try values.decode(ListStability.self, forKey: .listStability)
        useTimeWeighting = try values.decode(Bool.self, forKey: .useTimeWeighting)
        initialItem = try values.decode(String.self, forKey: .initialItem)
        items = try values.decode(Dictionary<String, ItemState>.self, forKey: .items)
        visitNumber = try values.decode(Int.self, forKey: .visitNumber)
        mostRecentItemID = try values.decode(String.self, forKey: .mostRecentItemID)
        predictionList = try values.decode(Array<ScoredItem>.self, forKey: .predictionList)
        maxVisits = try values.decode(Int.self, forKey: .maxVisits)
    }
    
    // MARK: - Structs
    
    private struct ItemVisit: Codable {
        let id: String
        let hour: Int
        let weekday: Int
    }
    
    private struct ItemState: Codable {
        var nextVisits = [String: [ItemVisit]]()
        var visitNumber = 0
        var numberOfVisits = 0
        var timeOfLastVisit: TimeInterval = 0
        var crfWeight = 0.0
        var rank = Int.max
        
        mutating func addVisitToItem(_ item: String, maxVisits: Int) {
            let calendarComponents = Calendar.current.dateComponents([.hour, .weekday], from: Date())
            
            var nextVisitsToItem = nextVisits[item] ?? [ItemVisit]()
            nextVisitsToItem.append(ItemVisit(
                id: item,
                hour: calendarComponents.hour!,
                weekday: calendarComponents.weekday!
            ))
            nextVisitsToItem = Array(nextVisitsToItem.suffix(maxVisits))
            
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
            return nextVisits.reduce(into: 0) { (total, visit) in
                total += numberOfVisitsToItem(visit.key, inTimeSlotAtHour: currentHour)
            }
        }
        
        func numberOfVisitsToItem(_ item: String, inTimeSlotAtHour hourOfDay: Int) -> Int {
            guard let itemVisits = nextVisits[item] else { return 0 }
            return itemVisits.reduce(into: 0) { (total, itemVisit) in
                if (itemVisit.hour >= (hourOfDay - 1)) && (itemVisit.hour <= (hourOfDay + 1)) {
                    total += 1
                }
            }
        }
        
        func numberOfVisitsToItemsAtCurrentWeekday() -> Int {
            let currentWeekday = Calendar.current.component(.weekday, from: Date())
            return nextVisits.reduce(into: 0) { (total, item) in
                total += numberOfVisitsToItem(item.key, atWeekday: currentWeekday)
            }
        }
        
        func numberOfVisitsToItem(_ item: String, atWeekday weekday: Int) -> Int {
            guard let itemVisits = nextVisits[item] else { return 0 }
            return itemVisits.reduce(into: 0) { (total, itemVisit) in
                if itemVisit.weekday == weekday {
                    total += 1
                }
            }
        }
        
        func markovDescription() -> String {
            return nextVisits.reduce(into: [String]()) { (items, itemVisit) in
                let count = nextVisits[itemVisit.key]?.count
                items.append("\(itemVisit.key) (\(String(count!)))")
                }.joined(separator: ", ")
        }
    }
    
    private struct ScoredItem: Codable {
        let id: String
        let score: Double
    }
    
    // MARK: - Debugging
    
    public func markovDescription() -> String {
        return items.reduce(into: "") { (str, item) in
            str += "\(item.key) > \(item.value.markovDescription())\n"
        }
    }
    
    public func scoreDescription() -> String {
        return predictionList.reduce(into: "") { (str, scoredItem) in
            str += "\(scoredItem.id): score: \(scoredItem.score), markov: \(markovWeightForItem(scoredItem.id)), crf: \(crfWeightForItem(scoredItem.id)), time: \(timeWeightForItem(scoredItem.id))\n"
        }
    }
    
    public func predictionListDescription() -> String {
        return predictionList.reduce(into: "") { (str, scoredItem) in
            str += "\(scoredItem.id): \(scoredItem.score)\n"
        }
    }
}

