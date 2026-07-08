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

class TestStringExtension: XCTestCase {
    
    let animalString = "catcatdogmouse"
    
    func testNumberOfMatches() {
        
        //Simple tests
        var result = animalString.SWPBMnumberOfMatches("cat")
        XCTAssert(result == 2, "Expected 2 match, got \(result)")
        
        result = animalString.SWPBMnumberOfMatches("dog")
        XCTAssert(result == 1, "Expected 1 match, got \(result)")
        
        result = animalString.SWPBMnumberOfMatches("mouse")
        XCTAssert(result == 1, "Expected 1 match, got \(result)")
        
        result = animalString.SWPBMnumberOfMatches("zebra")
        XCTAssert(result == 0, "Expected 0 matches, got \(result)")
        
        result = animalString.SWPBMnumberOfMatches("catcatdog")
        XCTAssert(result == 1, "Expected 1 match, got \(result)")
        
        result = animalString.SWPBMnumberOfMatches("catcatdogmouse")
        XCTAssert(result == 1, "Expected 1 match, got \(result)")
        
        //Regex Tests
        result = animalString.SWPBMnumberOfMatches("cat.+dog")
        XCTAssert(result == 1, "Expected 1 match, got \(result)")
        
        result = animalString.SWPBMnumberOfMatches("mouse.+cat")
        XCTAssert(result == 0, "Expected 0 match, got \(result)")
        
        result = animalString.SWPBMnumberOfMatches("^cat")
        XCTAssert(result == 1, "Expected 1 match, got \(result)")
        
        result = animalString.SWPBMnumberOfMatches("mouse$")
        XCTAssert(result == 1, "Expected 1 match, got \(result)")
        
        result = animalString.SWPBMnumberOfMatches("[0-9]")
        XCTAssert(result == 0, "Expected 0 match, got \(result)")
        
        result = animalString.SWPBMnumberOfMatches("[a-z]")
        XCTAssert(result == animalString.count, "Expected \(animalString.count), got \(result)")
        
        result = animalString.SWPBMnumberOfMatches("c.tc.td.gm.us.")
        XCTAssert(result == 1, "Expected 1, got \(result)")
        
        result = animalString.SWPBMnumberOfMatches("cat\\.")
        XCTAssert(result == 0, "Expected 0, got \(result)")
    }
    
    func testDoesMatch() {
        XCTAssert(animalString.SWPBMdoesMatch("cat"), "Unexpected doesMatch Result")
        XCTAssert(!animalString.SWPBMdoesMatch("zebra"), "Unexpected doesMatch Result")
        XCTAssert(animalString.SWPBMdoesMatch("[a-z]"), "Unexpected doesMatch Result")
        XCTAssert(animalString.SWPBMdoesMatch("c.tc.td.gm.us."), "Unexpected doesMatch Result")
        XCTAssert(!animalString.SWPBMdoesMatch("cat\\."), "Unexpected doesMatch Result")
        
        //Negative lookahead
        XCTAssert(animalString.SWPBMdoesMatch("^((?!dog).)*dog.+"), "Unexpected doesMatch Result")
    }
    
    func testSubstringFromString() {
        
        //Standard
        var actual:String? = "foobarbaz".SWPBMsubstringFromString("foo")
        var expected:String? = "barbaz"
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        //End
        actual = "foobarbaz".SWPBMsubstringFromString("baz")
        expected = ""
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        //same
        actual = "foobarbaz".SWPBMsubstringFromString("foobarbaz")
        expected = "";
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        //EmptyString
        actual = "foobarbaz".SWPBMsubstringFromString("")
        expected = nil
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        //not found
        actual = "foobarbaz".SWPBMsubstringFromString("NotFound")
        expected = nil;
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
    }
    
    func testSubstringToString() {
        
        //Standard
        var actual:String? = "foobarbaz".SWPBMsubstringToString("bar")
        var expected:String? = "foo"
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        //Start of String
        actual = "foobarbaz".SWPBMsubstringToString("foo")
        expected = ""
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        //EmptyString
        actual = "foobarbaz".SWPBMsubstringToString("")
        expected = nil
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        //not found
        actual = "foobarbaz".SWPBMsubstringToString("NotFound")
        expected = nil
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
    }
    
    
    func testSubstringFromStringToString() {
        
        //Standard
        var actual:String? = "foobarbaz".SWPBMsubstringFromString("foo", toString:"baz")
        var expected:String? = "bar"
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        //End before beginning
        actual = "foobarbaz".SWPBMsubstringFromString("baz", toString:"foo")
        expected = nil
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        //Empty String inputs
        actual = "foobarbaz".SWPBMsubstringFromString("", toString:"baz")
        expected = nil
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        actual = "foobarbaz".SWPBMsubstringFromString("foo", toString:"")
        expected = nil
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        actual = "foobarbaz".SWPBMsubstringFromString("", toString:"")
        expected = nil
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        
        actual = "<NSThread: 0x7f806ffce890>{number = 4, name = (null)}".SWPBMsubstringFromString("number = ", toString:",")
        expected = "4"
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
    }
    
    
    func testSWPBMstringByReplacingRegex() {
        
        //Simple example (doesn't really use regex)
        var actual = "foobarbaz".SWPBMstringByReplacingRegex("bar", replaceWith:"baz")
        var expected = "foobazbaz"
        XCTAssert(expected == actual, "expected \(expected), got \(actual)")
        
        //Simple .+ examples
        actual = "foobarbaz".SWPBMstringByReplacingRegex("f.+", replaceWith:"baz")
        expected = "baz"
        XCTAssert(expected == actual, "expected \(expected), got \(actual)")
        
        actual = "foo\"bar\"baz".SWPBMstringByReplacingRegex("\".+\"", replaceWith:"\"baz\"")
        expected = "foo\"baz\"baz"
        XCTAssert(expected == actual, "expected \(expected), got \(actual)")
        
        //Group, trivial example (replace with self)
        actual = "a href=\"foo.com?key1=val1&key2=val2\"".SWPBMstringByReplacingRegex("\"(.+)\"", replaceWith:"\"$1\"")
        expected = "a href=\"foo.com?key1=val1&key2=val2\""
        XCTAssert(expected == actual, "expected \(expected), got \(actual)")
        
        //Group, append stuff
        actual = "a href=\"foo.com?key1=val1&key2=val2\"".SWPBMstringByReplacingRegex("\"(.+)\"", replaceWith:"\"$1&key3=val3\"")
        expected = "a href=\"foo.com?key1=val1&key2=val2&key3=val3\""
        XCTAssert(expected == actual, "expected \(expected), got \(actual)")
        
        //Regex "Not"
        actual = "a href=\"foo.com?key1=val1&key2=val2\"".SWPBMstringByReplacingRegex("foo.com\\?[^'\"]+", replaceWith:"foo.com?bar=baz")
        expected = "a href=\"foo.com?bar=baz\""
        XCTAssert(expected == actual, "expected \(expected), got \(actual)")
        
        //Regex "Not" With Group & Append
        actual = "a href=\"foo.com\(PrebidConstants.TRACKING_PATTERN_RI)?key1=val1&key2=val2\"".SWPBMstringByReplacingRegex("\(PrebidConstants.TRACKING_PATTERN_RI)\\?([^'\"]+)", replaceWith:"\(PrebidConstants.TRACKING_PATTERN_RI)?$1&bar=baz")
        expected = "a href=\"foo.com\(PrebidConstants.TRACKING_PATTERN_RI)?key1=val1&key2=val2&bar=baz\""
        XCTAssert(expected == actual, "expected \(expected), got \(actual)")
    }
    
    func testSWPBMsubstringFromIndex() {
        
        //Basic test
        var actual:String? = "foobarbaz".SWPBMsubstringFromIndex(0, toIndex:3)
        var expected:String? = "foo"
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        //Error handling
        actual = "foobarbaz".SWPBMsubstringFromIndex(0, toIndex:-1)
        expected = nil
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        actual = "foobarbaz".SWPBMsubstringFromIndex(-1, toIndex:0)
        expected = nil
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        actual = "foobarbaz".SWPBMsubstringFromIndex(3, toIndex:0)
        expected = nil
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        //More complicated regular tests
        actual = "foobarbaz".SWPBMsubstringFromIndex(0, toIndex:0)
        expected = ""
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        actual = "foobarbaz".SWPBMsubstringFromIndex(3, toIndex:6)
        expected = "bar"
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        actual = "foobarbaz".SWPBMsubstringFromIndex(0, toIndex:1)
        expected = "f"
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        actual = "foobarbaz".SWPBMsubstringFromIndex(0, toIndex:9)
        expected = "foobarbaz"
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        actual = "foobarbaz".SWPBMsubstringFromIndex(8, toIndex:9)
        expected = "z"
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
        
        actual = "foobarbaz".SWPBMsubstringFromIndex(1, toIndex:10)
        expected = nil
        XCTAssert(expected == actual, "expected \(String(describing: expected)), got \(String(describing: actual))")
    }
    
    func testEncodeURL() {
        let str1 = "https://example.com/search?q=Prebid mobile&page=1"
        let encodedStr1 = str1.encodedURL(with: .urlQueryAllowed)?.absoluteString
        
        XCTAssertNotEqual(str1, encodedStr1)
        XCTAssertTrue(encodedStr1!.contains("%20"))
        
        let str2 = "https://example.com/search?q=Prebid%20mobile&page=1"
        let encodedStr2 = str2.encodedURL(with: .urlQueryAllowed)?.absoluteString
        
        XCTAssertEqual(str2, encodedStr2)
    }
    
    func testStringToCGSize() {
        var result = "300x250".toCGSize()
        XCTAssertNotNil(result)
        XCTAssert(result == CGSize(width: 300, height: 250))
        
        result = "300x250x1".toCGSize()
        XCTAssertNil(result)
        
        result = "ERROR".toCGSize()
        XCTAssertNil(result)
        
        result = "300x250ERROR".toCGSize()
        XCTAssertNil(result)
    }
    
    func testRegexMatches() {
        var result = "aaa aaa".matches(for: "^a")
        XCTAssert(result.count == 1)
        XCTAssert(result[0] == "a")
        
        result = "aaa aaa".matches(for: "^b")
        XCTAssert(result.count == 0)
        
        result = "^a".matches(for: "aaa aaa")
        XCTAssert(result.count == 0)
        
        result = "{ \n adManagerResponse:\"hb_size\":[\"728x90\"],\"hb_size_rubicon\":[\"1x1\"],moPubResponse:\"hb_size:300x250\" \n }".matches(for: "[0-9]+x[0-9]+")
        XCTAssert(result.count == 3)
        XCTAssert(result[0] == "728x90")
        XCTAssert(result[1] == "1x1")
        XCTAssert(result[2] == "300x250")
        
        result = "{ \n adManagerResponse:\"hb_size\":[\"728x90\"],\"hb_size_rubicon\":[\"1x1\"],moPubResponse:\"hb_size:300x250\" \n }".matches(for: "hb_size\\W+[0-9]+x[0-9]+")
        
        XCTAssert(result.count == 2)
        XCTAssert(result[0] == "hb_size\":[\"728x90")
        XCTAssert(result[1] == "hb_size:300x250")
    }
    
    func testRegexMatchAndCheck() {
        var result = "aaa aaa".matchAndCheck(regex: "^a")
        
        XCTAssertNotNil(result)
        XCTAssert(result == "a")
        
        result = "aaa aaa".matchAndCheck(regex: "^b")
        XCTAssertNil(result)
    }
}
