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

import UIKit
@testable @_spi(SWPBMInternal) import SellwildPrebid

class SWPBMMRAIDCommandTest : XCTestCase {
    
    func testInit() {
        
        //Cover the three cases that would result in an error
        var expectedErrorMessage = "URL does not contain MRAID scheme"
        do {
            _ = try SWPBMMRAIDCommand(url: "mraid_bad_scheme:expand")
            XCTFail("Should have caught \(expectedErrorMessage) error")
        } catch let error as NSError {
            XCTAssert(error.localizedDescription.SWPBMdoesMatch(expectedErrorMessage), "Expected \(expectedErrorMessage), got \(error.localizedDescription)")
        } catch {
            XCTFail("Should have caught \(expectedErrorMessage)")
        }
        
        expectedErrorMessage = "Command not found"
        do {
            _ = try SWPBMMRAIDCommand(url: "mraid:")
            XCTFail("Should have caught \(expectedErrorMessage) error")
        } catch let error as NSError {
            XCTAssert(error.localizedDescription.SWPBMdoesMatch(expectedErrorMessage), "Expected \(expectedErrorMessage), got \(error.localizedDescription)")
        } catch {
            XCTFail("Should have caught \(expectedErrorMessage)")
        }
        
        expectedErrorMessage = "Unrecognized MRAID command"
        do {
            _ = try SWPBMMRAIDCommand(url: "mraid:bad_command")
            XCTFail("Should have caught \(expectedErrorMessage) error")
        } catch let error as NSError {
            XCTAssert(error.localizedDescription.SWPBMdoesMatch(expectedErrorMessage), "Expected \(expectedErrorMessage), got \(error.localizedDescription)")
        } catch {
            XCTFail("Should have caught \(expectedErrorMessage)")
        }
        
        
        var swpbmMRAIDCommand:SWPBMMRAIDCommand
        
        do {
            
            //Test all commands
            swpbmMRAIDCommand = try SWPBMMRAIDCommand(url: "mraid:open")
            XCTAssertEqual(swpbmMRAIDCommand.command, .open)
            XCTAssert(swpbmMRAIDCommand.arguments == [])
            
            swpbmMRAIDCommand = try SWPBMMRAIDCommand(url: "mraid:expand")
            XCTAssertEqual(swpbmMRAIDCommand.command, .expand)
            XCTAssert(swpbmMRAIDCommand.arguments == [])
            
            swpbmMRAIDCommand = try SWPBMMRAIDCommand(url: "mraid:resize")
            XCTAssertEqual(swpbmMRAIDCommand.command, .resize)
            XCTAssert(swpbmMRAIDCommand.arguments == [])
            
            swpbmMRAIDCommand = try SWPBMMRAIDCommand(url: "mraid:close")
            XCTAssertEqual(swpbmMRAIDCommand.command, .close)
            XCTAssert(swpbmMRAIDCommand.arguments == [])
            
            swpbmMRAIDCommand = try SWPBMMRAIDCommand(url: "mraid:playVideo")
            XCTAssertEqual(swpbmMRAIDCommand.command, .playVideo)
            XCTAssert(swpbmMRAIDCommand.arguments == [])
            
            swpbmMRAIDCommand = try SWPBMMRAIDCommand(url: "mraid:log")
            XCTAssertEqual(swpbmMRAIDCommand.command, .log)
            XCTAssert(swpbmMRAIDCommand.arguments == [])
            
            swpbmMRAIDCommand = try SWPBMMRAIDCommand(url: "mraid:onOrientationPropertiesChanged")
            XCTAssertEqual(swpbmMRAIDCommand.command, .onOrientationPropertiesChanged)
            XCTAssert(swpbmMRAIDCommand.arguments == [])
            
            //Case sensitivity
            swpbmMRAIDCommand = try SWPBMMRAIDCommand(url: "mraid:ONORIENTATIONPROPERTIESCHANGED")
            XCTAssertEqual(swpbmMRAIDCommand.command, .onOrientationPropertiesChanged)
            XCTAssert(swpbmMRAIDCommand.arguments == [])
            
            swpbmMRAIDCommand = try SWPBMMRAIDCommand(url: "mraid:eXpAnD")
            XCTAssertEqual(swpbmMRAIDCommand.command, .expand)
            XCTAssert(swpbmMRAIDCommand.arguments == [])
            
            //mixed
            swpbmMRAIDCommand = try SWPBMMRAIDCommand(url: "mraid:OPEN")
            XCTAssertEqual(swpbmMRAIDCommand.command, .open)
            XCTAssert(swpbmMRAIDCommand.arguments == [])
            
            //Arguments
            swpbmMRAIDCommand = try SWPBMMRAIDCommand(url: "mraid:expand/foo.com")
            XCTAssertEqual(swpbmMRAIDCommand.command, .expand)
            XCTAssert(swpbmMRAIDCommand.arguments == ["foo.com"])
            
            //%-substitution
            swpbmMRAIDCommand = try SWPBMMRAIDCommand(url: "mraid:expand/foo.com%20bar")
            XCTAssertEqual(swpbmMRAIDCommand.command, .expand)
            XCTAssert(swpbmMRAIDCommand.arguments == ["foo.com bar"])
            
            //Lots of arguments
            swpbmMRAIDCommand = try SWPBMMRAIDCommand(url: "mraid:expand/foo/bar/baz")
            XCTAssertEqual(swpbmMRAIDCommand.command, .expand)
            XCTAssert(swpbmMRAIDCommand.arguments == ["foo", "bar", "baz"])
            
        } catch let error as SWPBMError {
            XCTFail(error.description)
        } catch {
            XCTFail()
        }
    }
}
