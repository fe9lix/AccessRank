import Foundation

struct Items {

    static let all: [[String: String]] = {
        var items = [[String: String]]()
        for index in 65...90 {
            let letter = String(UnicodeScalar(index))
            items += [
                "name": NSString(format: "Item %@", letter),
                "id": letter]
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