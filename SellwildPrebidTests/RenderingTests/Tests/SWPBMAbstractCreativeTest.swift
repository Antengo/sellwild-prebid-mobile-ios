/*   Copyright 2018-2021 Prebid.org, Inc.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import XCTest

@testable @_spi(SWPBMInternal) import SellwildPrebid

class SWPBMAbstractCreativeTest: XCTestCase, CreativeResolutionDelegate {
    
    var expectation:XCTestExpectation?
    var swpbmAbstractCreative: SWPBMAbstractCreative_Objc!
    let msgAbstractFunctionCalled = "Abstract function called"
    
    private var logToFile: LogToFileLock?
    
    override func setUp() {
        super.setUp()
        self.swpbmAbstractCreative = SWPBMAbstractCreative_Objc(creativeModel:CreativeModel(), transaction:UtilitiesForTesting.createEmptyTransaction())
        self.swpbmAbstractCreative.creativeResolutionDelegate = self
    }
    
    override func tearDown() {
        logToFile = nil
        self.swpbmAbstractCreative = nil;
        
        super.tearDown()
    }
    
    func testIsOpened() {
        XCTAssertFalse(self.swpbmAbstractCreative.isOpened)
    }
    
    func testSetupViewBackground() {
        logToFile = .init()
        
        self.swpbmAbstractCreative.setupView(withThread: MockNSThread(mockIsMainThread: false))
        
        UtilitiesForTesting.checkLogContains("Attempting to set up view on background thread")
    }
    
    func testModalManagerDidFinishPop() {
        logToFile = .init()
        let state = Factory.createModalState(view: SWPBMWebView(),
                                             adConfiguration:AdConfiguration(),
                                             displayProperties:InterstitialDisplayProperties())
        self.swpbmAbstractCreative.modalManagerDidFinishPop(state)
        let log = Log.getLogFileAsString() ?? ""
        XCTAssertTrue(log.contains(msgAbstractFunctionCalled))
    }

    func testModalManagerDidLeaveApp() {
        logToFile = .init()
        let state = Factory.createModalState(view: SWPBMWebView(),
                                             adConfiguration:AdConfiguration(),
                                             displayProperties:InterstitialDisplayProperties())
        swpbmAbstractCreative.modalManagerDidLeaveApp(state)
        let log = Log.getLogFileAsString() ?? ""
        XCTAssertTrue(log.contains(msgAbstractFunctionCalled))
    }
    
    func testOnResolutionCompleted() {
        expectation = self.expectation(description: "Expected downloadCompleted to be called")
        swpbmAbstractCreative.isDownloaded = false
        swpbmAbstractCreative.onResolutionCompleted()
        waitForExpectations(timeout: 4, handler: { _ in
            XCTAssertTrue(self.swpbmAbstractCreative.isDownloaded)
        })
    }
    
    func testOnResolutionFailed() {
        self.expectation = self.expectation(description: "Expected downloadFailed to be called")
        swpbmAbstractCreative.isDownloaded = false
        swpbmAbstractCreative.onResolutionFailed(NSError(domain: "OpenXSDK", code: 123, userInfo: [:]))
        waitForExpectations(timeout: 4, handler: { _ in
            XCTAssertTrue(self.swpbmAbstractCreative.isDownloaded)
        })
    }
    
    //MARK - SWPBMCreativeResolutionDelegate
    
    func creativeReady(_ creative: AbstractCreative) {
        expectation?.fulfill()
        XCTAssertTrue(creative.isDownloaded)
    }
    
    func creativeFailed(_ error: Error) {
        expectation?.fulfill()
        XCTAssertTrue(self.swpbmAbstractCreative.isDownloaded)
    }
    
    //MARK - Open Measurement

    func testOpenMeasurement() {
        logToFile = .init()
        self.swpbmAbstractCreative.createOpenMeasurementSession()
        UtilitiesForTesting.checkLogContains("Abstract function called")
    }
}
