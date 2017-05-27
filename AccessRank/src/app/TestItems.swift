import Foundation

struct TestItems {
    static let all: [[String: String]] = {
        var items = [[String: String]]()
        for index in 65...90 {
            let letter = String(describing: UnicodeScalar(index)!)
            items.append([
                "name": String(format: "Item %@", letter),
                "id": letter
                ])
        }
        return items
    }()
    
    static let byID: [String: String] = {
        var itemsByID = [String: String]()
        for item in all {
            itemsByID[item["id"]!] = item["name"]
        }
        return itemsByID
    }()
}
