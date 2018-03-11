import XCTest
@testable import AccessRank

class AccessRankTests: XCTestCase, AccessRankDelegate {
    private let accessRank: AccessRank = AccessRank(listStability: .medium)
    private var delegateExpectation: XCTestExpectation?
    
    // MARK: - Lifecycle
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testLowListStability() {
        let accessRankLow = AccessRank(listStability: .low)
        accessRankLow.visitItem("A")
        accessRankLow.visitItem("B")
        accessRankLow.visitItem("C")
        accessRankLow.visitItem("A")
        accessRankLow.visitItem("B")
        
        XCTAssertEqual(accessRankLow.predictions[0], "C")
    }
    
    func testMediumListStability() {
        accessRank.visitItem("A")
        accessRank.visitItem("B")
        accessRank.visitItem("C")
        accessRank.visitItem("A")
        accessRank.visitItem("B")
        
        XCTAssertEqual(accessRank.predictions[0], "C")
    }
    
    func testHighListStability() {
        let accessRankHigh = AccessRank(listStability: .high)
        accessRankHigh.visitItem("A")
        accessRankHigh.visitItem("B")
        accessRankHigh.visitItem("C")
        accessRankHigh.visitItem("A")
        accessRankHigh.visitItem("B")
        
        XCTAssertEqual(accessRankHigh.predictions[0], "A")
    }
    
    func testNumberOfPredictions() {
        accessRank.visitItem("A")
        accessRank.visitItem("B")
        accessRank.visitItem("C")
        
        XCTAssertEqual(accessRank.predictions.count, 2)
    }
    
    func testMostRecentItem() {
        accessRank.visitItem("A")
        accessRank.visitItem("B")
        accessRank.visitItem("C")
        
        XCTAssertEqual(accessRank.mostRecentItem!, "C")
    }
    
    func testPredictionsShouldNotContainInitialItem() {
        accessRank.visitItem("A")
        accessRank.visitItem("B")
        accessRank.visitItem(nil)
        accessRank.visitItem("C")
        
        XCTAssertFalse(accessRank.predictions.contains(accessRank.initialItem))
    }
 
    func testPredictionsShouldNotContainMostRecentItem() {
        accessRank.visitItem("A")
        accessRank.visitItem("B")
        accessRank.visitItem("C")
        
        XCTAssertFalse(accessRank.predictions.contains(accessRank.mostRecentItem!))
    }
    
    func testRemoveItems() {
        accessRank.visitItem("A")
        accessRank.visitItem("B")
        accessRank.visitItem("C")
        accessRank.visitItem("A")
        
        accessRank.removeItems(["C", "A"])
        
        XCTAssertFalse(accessRank.predictions.contains("A"))
        XCTAssertFalse(accessRank.predictions.contains("C"))
        XCTAssertNil(accessRank.mostRecentItem)
    }
    
    func testPersistence() {
        accessRank.visitItem("A")
        accessRank.visitItem("B")
        accessRank.visitItem("C")
        
        let encodedAccessRank = try! JSONEncoder().encode(accessRank)
        let decodedAccessRank = try! JSONDecoder().decode(AccessRank.self, from: encodedAccessRank)
        
        XCTAssertTrue(decodedAccessRank.mostRecentItem == accessRank.mostRecentItem)
        XCTAssertTrue(decodedAccessRank.predictions == accessRank.predictions)
    }
    
    func testDelegate() {
        accessRank.visitItem("A")
        
        delegateExpectation = expectation(description: "update predictions")
        
        accessRank.delegate = self
        accessRank.visitItem("B")
        
        waitForExpectations(timeout: 5.0, handler: nil)
    }
    
    func accessRankDidUpdatePredictions(_ accessRank: AccessRank) {
        XCTAssertEqual(accessRank.predictions.count, 1)
        delegateExpectation?.fulfill()
    }
}
