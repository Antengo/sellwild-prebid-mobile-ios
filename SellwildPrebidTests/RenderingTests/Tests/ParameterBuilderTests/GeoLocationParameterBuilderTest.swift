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

import UIKit
import XCTest
import CoreLocation

@testable import SellwildPrebid

class GeoLocationParameterBuilderTest : XCTestCase {
    
    override func setUp() {
        SellwildPrebid.shared.shareGeoLocation = true
    }
    
    func testBasic() {
        let mockLocationManagerSuccessful = MockLocationManagerSuccessful.sharedMock
        let builder = GeoLocationParameterBuilder(locationManager:mockLocationManagerSuccessful)
        let bidRequest = SWPBMORTBBidRequest()
        
        builder.build(bidRequest)
        
        SWPBMAssertEq(bidRequest.device.geo.type, 1)
        SWPBMAssertEq(bidRequest.device.geo.lat!.doubleValue, mockLocationManagerSuccessful.coordinates.latitude)
        SWPBMAssertEq(bidRequest.device.geo.lon!.doubleValue, mockLocationManagerSuccessful.coordinates.longitude)
    }
    
    //Show that user values do not interact with GPS values.
    func testUserAndDevice() {
        
        let mockLocationManagerSuccessful = MockLocationManagerSuccessful.sharedMock
        let builder = GeoLocationParameterBuilder(locationManager:mockLocationManagerSuccessful)
        
        
        let bidRequest = SWPBMORTBBidRequest()
        bidRequest.user.geo.type = 3
        bidRequest.user.geo.lat = 123.0
        bidRequest.user.geo.lon = 456.0
        bidRequest.user.geo.city = "UserCity"
        bidRequest.user.geo.region = "UserRegion"
        bidRequest.user.geo.zip = "UserZip"
        bidRequest.user.geo.country = "UserCountry"
        
        builder.build(bidRequest)
        
        SWPBMAssertEq(bidRequest.device.geo.type, 1)
        SWPBMAssertEq(bidRequest.device.geo.lat!.doubleValue, mockLocationManagerSuccessful.coordinates.latitude)
        SWPBMAssertEq(bidRequest.device.geo.lon!.doubleValue, mockLocationManagerSuccessful.coordinates.longitude)
        
        SWPBMAssertEq(bidRequest.user.geo.type, 3)
        SWPBMAssertEq(bidRequest.user.geo.lat, 123.0)
        SWPBMAssertEq(bidRequest.user.geo.lon, 456.0)
        SWPBMAssertEq(bidRequest.user.geo.city, "UserCity")
        SWPBMAssertEq(bidRequest.user.geo.region, "UserRegion")
        SWPBMAssertEq(bidRequest.user.geo.zip, "UserZip")
        SWPBMAssertEq(bidRequest.user.geo.country, "UserCountry")
    }
}
