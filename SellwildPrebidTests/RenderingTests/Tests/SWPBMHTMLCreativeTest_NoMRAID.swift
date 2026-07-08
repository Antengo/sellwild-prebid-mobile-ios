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

import Foundation
import XCTest
@testable import SellwildPrebid

class SWPBMHTMLCreativeTest_NoMRAID : SWPBMHTMLCreativeTest_Base {
    
    private var logToFile: LogToFileLock?
    
    override func tearDown() {
        logToFile = nil
        super.tearDown()
    }
    
    func testNoMRAID() {
        logToFile = .init()
        
        let sdkConfiguration = SellwildPrebid.mock
        
        
        let serverConnection = PrebidServerConnection(userAgentService: MockUserAgentService())
        serverConnection.protocolClasses.append(MockServerURLProtocol.self)
        
        let mockWebView = MockSWPBMWebView()
        let swpbmHTMLCreative = SWPBMHTMLCreative(
            creativeModel: MockSWPBMCreativeModel(),
            transaction:UtilitiesForTesting.createEmptyTransaction(),
            webView: mockWebView,
            sdkConfiguration:sdkConfiguration
        )
        let mockMRAIDController = SWPBMMRAIDController(creative:swpbmHTMLCreative,
                                                     viewControllerForPresenting:UIViewController(),
                                                     webView:mockWebView,
                                                     creativeViewDelegate:self,
                                                     downloadBlock:createLoader(connection: serverConnection),
                                                     deviceAccessManagerClass: DeviceAccessManager.self,
                                                     sdkConfiguration: sdkConfiguration)
        swpbmHTMLCreative.mraidController = mockMRAIDController
        swpbmHTMLCreative.view = mockWebView
        
        //non-mraid command
        swpbmHTMLCreative.webView(mockWebView, receivedMRAIDLink:URL(string: "mraid:non_cmd")!)
        let log = Log.getLogFileAsString() ?? ""
        XCTAssert(log.contains("Unrecognized MRAID command non_cmd"))
    }
}
