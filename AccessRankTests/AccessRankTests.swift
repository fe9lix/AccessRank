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
        accessRankLow.mostRecentItem = "A"
        accessRankLow.mostRecentItem = "B"
        accessRankLow.mostRecentItem = "C"
        accessRankLow.mostRecentItem = "A"
        accessRankLow.mostRecentItem = "C"
        accessRankLow.mostRecentItem = "A"
        
        XCTAssertEqual(accessRankLow.predictions[0], "C")
    }
    
    func testMediumListStability() {
        accessRank.mostRecentItem = "A"
        accessRank.mostRecentItem = "B"
        accessRank.mostRecentItem = "C"
        accessRank.mostRecentItem = "A"
        accessRank.mostRecentItem = "C"
        accessRank.mostRecentItem = "A"
        
        XCTAssertEqual(accessRank.predictions[0], "B")
    }
    
    func testHighListStability() {
        let accessRankHigh = AccessRank(listStability: AccessRank.ListStability.High)
        accessRankHigh.mostRecentItem = "A"
        accessRankHigh.mostRecentItem = "B"
        accessRankHigh.mostRecentItem = "C"
        accessRankHigh.mostRecentItem = "A"
        accessRankHigh.mostRecentItem = "C"
        accessRankHigh.mostRecentItem = "A"
        
        XCTAssertEqual(accessRankHigh.predictions[0], "B")
    }
    
    func testNumberOfPredictions() {
        accessRank.mostRecentItem = "A"
        accessRank.mostRecentItem = "B"
        accessRank.mostRecentItem = "C"
        
        XCTAssertEqual(accessRank.predictions.count, 2)
    }
    
    func testPredictionsShouldNotContainInitialItem() {
        accessRank.mostRecentItem = "A"
        accessRank.mostRecentItem = "B"
        accessRank.mostRecentItem = nil
        accessRank.mostRecentItem = "C"
        
        XCTAssertFalse(contains(accessRank.predictions, accessRank.initialItemID))
    }
 
    func testPredictionsShouldNotContainMostRecentItem() {
        accessRank.mostRecentItem = "A"
        accessRank.mostRecentItem = "B"
        accessRank.mostRecentItem = "C"
        
        XCTAssertFalse(contains(accessRank.predictions, accessRank.mostRecentItem!))
    }
    
    func testRemoveItems() {
        accessRank.mostRecentItem = "A"
        accessRank.mostRecentItem = "B"
        accessRank.mostRecentItem = "C"
        accessRank.mostRecentItem = "A"
        
        accessRank.removeItems(["C", "A"])
        
        XCTAssertFalse(contains(accessRank.predictions, "A"))
        XCTAssertFalse(contains(accessRank.predictions, "C"))
        XCTAssertNil(accessRank.mostRecentItem)
    }
    
    func testPersistence() {
        accessRank.mostRecentItem = "A"
        accessRank.mostRecentItem = "B"
        accessRank.mostRecentItem = "C"
        
        let dataToPersist = accessRank.toDictionary()
        
        let restoredAccessRank = AccessRank(
            listStability: AccessRank.ListStability.Medium,
            data: dataToPersist)
        
        XCTAssertEqualObjects(restoredAccessRank.mostRecentItem, accessRank.mostRecentItem)
        XCTAssertEqualObjects(restoredAccessRank.predictions, accessRank.predictions)
    }
    
    func testDelegate() {
        accessRank.mostRecentItem = "A"
        
        delegateExpectation = expectationWithDescription("update predictions");
        
        accessRank.delegate = self
        accessRank.mostRecentItem = "B"
        
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func accessRankDidUpdatePredictions(accessRank: AccessRank) {
        XCTAssertEqual(accessRank.predictions.count, 1)
        delegateExpectation?.fulfill()
    }
    
}