import Foundation

struct TestItems {
    static let all: [[String: String]] = {
        return (65...90).reduce(into: [[String: String]]()) { (items, index) in
            let letter = String(describing: UnicodeScalar(index)!)
            items.append([
                "name": String(format: "Item %@", letter),
                "id": letter
                ])
        }
    }()
    
    static let byID: [String: String] = {
        return all.reduce(into: [String: String]()) { (itemsByID, item) in
            itemsByID[item["id"]!] = item["name"]
        }
    }()
}
