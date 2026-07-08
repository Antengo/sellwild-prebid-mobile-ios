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

#import "SWPBMAbstractCreative.h"
#import "SWPBMSafariVCOpener.h"

@protocol SWPBMThreadProtocol;

NS_ASSUME_NONNULL_BEGIN

@interface SWPBMAbstractCreative_Objc (SWPBMTestExpose)

@property (nonatomic, strong, nullable) SWPBMSafariVCOpener * safariOpener;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCreativeModel:(SWPBMCreativeModel *)creativeModel
                          transaction:(id<SWPBMTransaction>)transaction;

- (void)setupViewWithThread:(id<SWPBMThreadProtocol>)thread;

- (BOOL)handleNormalClickthrough:(NSURL *)url
                sdkConfiguration:(SellwildPrebid *)sdkConfiguration
                          onExit:(SWPBMVoidBlock)onClickthroughExitBlock;

- (void)modalManagerDidFinishPop:(id<SWPBMModalState>)state;
- (void)modalManagerDidLeaveApp:(id<SWPBMModalState>)state;

- (void)pause;
- (void)resume;

@end

NS_ASSUME_NONNULL_END
