/*   Copyright 2018-2019 Prebid.org, Inc.

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
#import "SWSwiftImport.h"

@interface PrebidObjcTests : XCTestCase

@end

@implementation PrebidObjcTests


- (void)testAccountId {
    //given
    NSString *serverAccountId = @"123";
    
    //when
    SellwildPrebid.shared.prebidServerAccountId = serverAccountId;
    
    //then
    XCTAssertEqualObjects(serverAccountId, SellwildPrebid.shared.prebidServerAccountId);
}

- (void)testStoredAuctionResponse {
    //given
    NSString *storedAuctionResponse = @"111122223333";
    
    //when
    SellwildPrebid.shared.storedAuctionResponse = storedAuctionResponse;
    
    //then
    XCTAssertEqualObjects(storedAuctionResponse, SellwildPrebid.shared.storedAuctionResponse);
}

- (void)testAddStoredBidResponse {
    [SellwildPrebid.shared addStoredBidResponseWithBidder:@"rubicon" responseId:@"221155"];
}

- (void)testClearStoredBidResponses {
    [SellwildPrebid.shared clearStoredBidResponses];
}

- (void)testShareGeoLocation {
    //given
    BOOL case1 = YES;
    BOOL case2 = NO;
    
    //when
    SellwildPrebid.shared.shareGeoLocation = case1;
    BOOL result1 = SellwildPrebid.shared.shareGeoLocation;
    
    SellwildPrebid.shared.shareGeoLocation = case2;
    BOOL result2 = SellwildPrebid.shared.shareGeoLocation;
    
    //rhen
    XCTAssertEqual(case1, result1);
    XCTAssertEqual(case2, result2);
}

- (void)testTimeoutMillis {
    //given
    int timeoutMillis =  3000;
    
    //when
    SellwildPrebid.shared.timeoutMillis = timeoutMillis;
    
    //then
    XCTAssertEqual(timeoutMillis, SellwildPrebid.shared.timeoutMillis);
}

- (void)testLogLevel {
    [SellwildPrebid.shared setLogLevel:SWPBMLogLevel.debug];
}

- (void)testPbsDebug {
    //given
    BOOL pbsDebug = true;
    
    //when
    SellwildPrebid.shared.pbsDebug = pbsDebug;
    
    //then
    XCTAssertEqual(pbsDebug, SellwildPrebid.shared.pbsDebug);
}

@end
