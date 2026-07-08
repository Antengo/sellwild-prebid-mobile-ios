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

#import <XCTest/XCTest.h>
#import "NSString+SWPBMExtensions.h"

@interface NSString_SWPBMExtensionsObjCTest : XCTestCase

@end

@implementation NSString_SWPBMExtensionsObjCTest

- (void)testNilInput {
    NSString * const testString = @"abcd1234";
    NSString * nilString = nil;
    
    // SWPBMdoesMatch
    XCTAssertFalse([testString SWPBMdoesMatch:nilString]);
    
    // SWPBMnumberOfMatches
    XCTAssertEqual([testString SWPBMnumberOfMatches:nilString], 0);
 
    // SWPBMsubstringToString
    XCTAssertNil([testString SWPBMsubstringToString:nilString]);
    
    // SWPBMsubstringFromString
    XCTAssertNil([testString SWPBMsubstringFromString:nilString]);
    
    // SWPBMsubstringFromString:toString:
    XCTAssertNil([testString SWPBMsubstringFromString:@"abc" toString:nilString]);
    XCTAssertNil([testString SWPBMsubstringFromString:nilString toString:@"1234"]);
    XCTAssertNil([testString SWPBMsubstringFromString:nilString toString:nilString]);
    
    // SWPBMstringByReplacingRegex
    XCTAssertEqual([testString SWPBMstringByReplacingRegex:@"abc" replaceWith:nilString], testString);
    XCTAssertEqual([testString SWPBMstringByReplacingRegex:nilString replaceWith:@"xyz"], testString);
    XCTAssertEqual([testString SWPBMstringByReplacingRegex:nilString replaceWith:nilString], testString);
}

@end
