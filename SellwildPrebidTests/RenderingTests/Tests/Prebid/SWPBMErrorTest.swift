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

class SWPBMErrorTest: XCTestCase {
    func testErrorCollisions() {
        let allErrors = [
            SWPBMError.requestInProgress(),
            
            SWPBMError.prebidInvalidAccountId(),
            SWPBMError.prebidInvalidConfigId(),
            SWPBMError.prebidInvalidSize(),
            
            SWPBMError.serverError("some error reason"),
            
            SWPBMError.jsonDictNotFound(),
            SWPBMError.responseDeserializationFailed(),
            
            SWPBMError.noWinningBid(),
        ]
        
        for i in 1..<allErrors.count {
            for j in 0..<i {
                XCTAssertNotEqual(allErrors[i].code, allErrors[j].code,
                                  "\(i)('\(allErrors[i])' vs #\(j)('\(allErrors[j])'")
                XCTAssertNotEqual(allErrors[i].localizedDescription, allErrors[j].localizedDescription,
                                  "\(i)('\(allErrors[i])' vs #\(j)('\(allErrors[j])'")
            }
        }
    }
    
    func testErrorParsing() {
        let errors: [(Error?, ResultCode)] = [
            (SWPBMError.requestInProgress(), .prebidInternalSDKError),
            
            (SWPBMError.prebidInvalidAccountId(), .prebidInvalidAccountId),
            (SWPBMError.prebidInvalidConfigId(), .prebidInvalidConfigId),
            (SWPBMError.prebidInvalidSize(), .prebidInvalidSize),
            
            (SWPBMError.serverError("some error reason"), .prebidServerError),
            
            (SWPBMError.jsonDictNotFound(), .prebidInvalidResponseStructure),
            (SWPBMError.responseDeserializationFailed(), .prebidInvalidResponseStructure),
            
            (SWPBMError.noWinningBid(), .prebidDemandNoBids),
            
            
            (NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut), .prebidDemandTimedOut),
            (NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL), .prebidNetworkError),
            
            (nil, .prebidDemandFetchSuccess),
        ]
        
        for (error, code) in errors {
            XCTAssertEqual(SWPBMError.demandResult(from: error), code)
        }
    }
    
    func testInitWithMessage() {
        let error = SWPBMError(message: "MyError")
        XCTAssert(error.message == "MyError")
    }
    
    func testInitWithDescription() {
        let error = SWPBMError.error(description: "MyErrorDescription")
        
        // Verify default values
        XCTAssert(error.domain == SWPBMError.errorDomain)
        XCTAssert(error.code == 700)
        XCTAssert(error.userInfo["NSLocalizedDescription"] as! String == "MyErrorDescription")
    }
    
    func testInitWithMessageAndType() {
        let errorMessage = "ERROR MESSAGE"
        let err = SWPBMError.error(message: errorMessage, type: .internalError)
        XCTAssert(err.localizedDescription.SWPBMdoesMatch(errorMessage), "error should have \(errorMessage) in its description")
    }
    
    func testCreateErrorWithDescriptionNegative() {
        var error = SWPBMError.createError(nil, description: "")
        XCTAssertFalse(error)
        
        error = SWPBMError.createError(nil, message: "", type: .invalidRequest)
        XCTAssertFalse(error)
        
        error = SWPBMError.createError(nil, description: "", statusCode: .generalLinear)
        XCTAssertFalse(error)
    }
}
