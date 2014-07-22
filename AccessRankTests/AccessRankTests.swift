import XCTest
import AccessRank

class AccessRankTests: XCTestCase, AccessRankDelegate {
    
    let accessRank: AccessRank = AccessRank(listStability: AccessRank.ListStability.Medium)
    var delegateExpectation: XCTestExpectation?
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testLowListStability() {
        let accessRankLow = AccessRank(listStability: AccessRank.ListStability.Low)
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
        let accessRankHigh = AccessRank(listStability: AccessRank.ListStability.High)
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
        
        XCTAssertFalse(contains(accessRank.predictions, accessRank.initialItem))
    }
 
    func testPredictionsShouldNotContainMostRecentItem() {
        accessRank.visitItem("A")
        accessRank.visitItem("B")
        accessRank.visitItem("C")
        
        XCTAssertFalse(contains(accessRank.predictions, accessRank.mostRecentItem!))
    }
    
    func testRemoveItems() {
        accessRank.visitItem("A")
        accessRank.visitItem("B")
        accessRank.visitItem("C")
        accessRank.visitItem("A")
        
        accessRank.removeItems(["C", "A"])
        
        XCTAssertFalse(contains(accessRank.predictions, "A"))
        XCTAssertFalse(contains(accessRank.predictions, "C"))
        XCTAssertNil(accessRank.mostRecentItem)
    }
    
    func testPersistence() {
        accessRank.visitItem("A")
        accessRank.visitItem("B")
        accessRank.visitItem("C")
        
        let dataToPersist = accessRank.toDictionary()
        
        let restoredAccessRank = AccessRank(
            listStability: AccessRank.ListStability.Medium,
            data: dataToPersist)
        
        XCTAssertTrue(restoredAccessRank.mostRecentItem == accessRank.mostRecentItem)
        XCTAssertTrue(restoredAccessRank.predictions == accessRank.predictions)
    }
    
    func testDelegate() {
        accessRank.visitItem("A")
        
        delegateExpectation = expectationWithDescription("update predictions")
        
        accessRank.delegate = self
        accessRank.visitItem("B")
        
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func accessRankDidUpdatePredictions(accessRank: AccessRank) {
        XCTAssertEqual(accessRank.predictions.count, 1)
        delegateExpectation?.fulfill()
    }
    
}