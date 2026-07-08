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
@testable import SellwildPrebid

class SWPBMConstantsTests: XCTestCase {
    
    func testSWPBMAutoRefresh() {
        XCTAssertEqual(PrebidConstants.AUTO_REFRESH_DELAY_DEFAULT    , 60)
        XCTAssertEqual(PrebidConstants.AUTO_REFRESH_DELAY_MIN        , 15)
        XCTAssertEqual(PrebidConstants.AUTO_REFRESH_DELAY_MAX        , 125)
    }
    
    func testSWPBMTimeInterval() {
        XCTAssertEqual(PrebidConstants.VAST_LOADER_TIMEOUT          , 3)
        XCTAssertEqual(PrebidConstants.AD_CLICKED_ALLOWED_INTERVAL  , 5)
        XCTAssertEqual(PrebidConstants.CONNECTION_TIMEOUT_DEFAULT   , 3)
        XCTAssertEqual(PrebidConstants.CLOSE_DELAY_MIN              , 2)
        XCTAssertEqual(PrebidConstants.CLOSE_DELAY_MAX              , 30)
        XCTAssertEqual(PrebidConstants.FIRE_AND_FORGET_TIMEOUT      , 3)
    }
    
    func testSWPBMTimeScale() {
        XCTAssertEqual(PrebidConstants.VIDEO_TIMESCALE, 1000)
    }
    
    func testSWPBMGeoLocationConstants() {
        XCTAssertEqual(PrebidConstants.DISTANCE_FILTER, 50.0)
    }
    
    func testButtonAreaConstant() {
        XCTAssertEqual(PrebidConstants.BUTTON_AREA_DEFAULT, 0.1)
    }
    
    func testSkipDelayConstant() {
        XCTAssertEqual(PrebidConstants.SKIP_DELAY_DEFAULT, 10)
    }
    
    func testSWPBMSupportedVideoMimeTypes() {
        
        let types = PrebidConstants.SUPPORTED_VIDEO_MIME_TYPES
        let expected = ["video/mp4",
                        "video/quicktime",
                        "video/x-m4v",
                        "video/3gpp",
                        "video/3gpp2",
        ]
        
        XCTAssertEqual(types, expected)
    }
}
