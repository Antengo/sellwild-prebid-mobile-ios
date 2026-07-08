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

#import <Foundation/Foundation.h>

@class SWPBAdUnitConfig;
@class SWPBBidResponse;
@class SellwildPrebid;
@class SWPBTargeting;
@protocol SWPBPrebidServerConnectionProtocol;
@protocol SWPBMBidRequesterProtocol;

NS_ASSUME_NONNULL_BEGIN

@interface SWPBMBidRequester : NSObject <SWPBMBidRequesterProtocol>

- (instancetype)initWithConnection:(id<SWPBPrebidServerConnectionProtocol>)connection
                  sdkConfiguration:(SellwildPrebid *)sdkConfiguration
                         targeting:(SWPBTargeting *)targeting
               adUnitConfiguration:(SWPBAdUnitConfig *)adUnitConfiguration;

- (void)requestBidsWithCompletion:(void (^)(SWPBBidResponse * _Nullable, NSError * _Nullable))completion;

@end

NS_ASSUME_NONNULL_END
