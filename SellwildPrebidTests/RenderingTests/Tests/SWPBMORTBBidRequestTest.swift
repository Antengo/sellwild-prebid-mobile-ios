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

class SWPBMORTBBidRequestTest: XCTestCase {
    
    func testCombinedProperties() {
        
        // SWPBMORTBBidRequest
        checkInt(SWPBMORTBBidRequest(), property: "tmax")
        
        // SWPBMORTBBanner
        checkInt(SWPBMORTBBanner(), property: "pos")
        
        // SWPBMORTBVideo
        checkInt(SWPBMORTBVideo(), property: "minduration")
        checkInt(SWPBMORTBVideo(), property: "maxduration")
        checkInt(SWPBMORTBVideo(), property: "w")
        checkInt(SWPBMORTBVideo(), property: "h")
        checkInt(SWPBMORTBVideo(), property: "startdelay")
        checkInt(SWPBMORTBVideo(), property: "minbitrate")
        checkInt(SWPBMORTBVideo(), property: "maxbitrate")
        
        // SWPBMORTBPmp
        checkInt(SWPBMORTBPmp(), property: "private_auction")
        
        // SWPBMORTBDeal
        checkInt(SWPBMORTBDeal(), property: "at")
        
        // SWPBMORTBApp
        checkInt(SWPBMORTBApp(), property: "privacypolicy")
        checkInt(SWPBMORTBApp(), property: "paid")
        
        // SWPBMORTBDevice
        checkInt(SWPBMORTBDevice(), property: "lmt")
        checkInt(SWPBMORTBDevice(), property: "devicetype")
        checkInt(SWPBMORTBDevice(), property: "h")
        checkInt(SWPBMORTBDevice(), property: "w")
        checkInt(SWPBMORTBDevice(), property: "ppi")
        checkDouble(SWPBMORTBDevice(), property: "pxratio")
        checkInt(SWPBMORTBDevice(), property: "js")
        checkInt(SWPBMORTBDevice(), property: "geofetch")
        checkInt(SWPBMORTBDevice(), property: "connectiontype")
        
        // SWPBMORTBGeo
        checkDouble(SWPBMORTBGeo(), property: "lat")
        checkDouble(SWPBMORTBGeo(), property: "lon")
        checkInt(SWPBMORTBGeo(), property: "type")
        checkInt(SWPBMORTBGeo(), property: "accuracy")
        checkInt(SWPBMORTBGeo(), property: "lastfix")
        checkInt(SWPBMORTBGeo(), property: "utcoffset")
    }
    
    // MARK: Test Function
    
    func checkInt(_ object: NSObject, property: String, file: StaticString = #file, line: UInt = #line) {
        check(object, property: property, testValues: [1, 2], file: file, line: line)
    }
    
    func checkDouble(_ object: NSObject, property: String, file: StaticString = #file, line: UInt = #line) {
        check(object, property: property, testValues: [1.1, 2.2], file: file, line: line)
    }
    
    func check<T: Comparable>(_ object: NSObject,
                              property: String,
                              typePrefix: String? = nil,
                              testValues: [T],
                              file: StaticString = #file, line: UInt = #line) {
        
        // Prepare
        var typedProperty = property
        if let type = typePrefix {
            typedProperty = type + String(property.first!).uppercased() + property.dropFirst()
        }
        
        XCTAssertEqual(testValues.count, 2, file: file, line: line)
        XCTAssertNotEqual(testValues[0], testValues[1], file: file, line: line)
        
        // Check the property existence
        XCTAssert(object.responds(to: Selector(property)), "There is no property \(property)", file: file, line: line)
        XCTAssert(object.responds(to: Selector(typedProperty)), "There is no property \(typedProperty)", file: file, line: line)
        
        // Default should be nil
        XCTAssertNil(object.value(forKey: property), file: file, line: line)
        XCTAssertNil(object.value(forKey: typedProperty), file: file, line: line)
        
        let v1 = testValues[0]
        object.setValue(v1, forKey: property)
        XCTAssertEqual(object.value(forKey: typedProperty) as! T , v1, file: file, line: line)
        
        let v2 = testValues[1]
        object.setValue(v2, forKey: typedProperty)
        XCTAssertEqual(object.value(forKey: property) as! T, v2, file: file, line: line)
        
        object.setValue(nil, forKey: property)
        XCTAssertNil(object.value(forKey: property), file: file, line: line)
        XCTAssertNil(object.value(forKey: typedProperty), file: file, line: line)
    }
}
