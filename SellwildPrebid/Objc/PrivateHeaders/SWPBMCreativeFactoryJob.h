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

#import "SWSwiftImport.h"

@class SWPBMCreativeFactoryJob;

typedef enum SWPBMCreativeFactoryJobState : NSUInteger {
    SWPBMCreativeFactoryJobStateInitialized,
    SWPBMCreativeFactoryJobStateRunning,
    SWPBMCreativeFactoryJobStateSuccess,
    SWPBMCreativeFactoryJobStateError
} SWPBMCreativeFactoryJobState;

typedef void(^SWPBMCreativeFactoryJobFinishedCallback)(SWPBMCreativeFactoryJob * _Nonnull, NSError * _Nullable);

@interface SWPBMCreativeFactoryJob : NSObject <SWPBMCreativeResolutionDelegate>

@property (nonatomic, strong, nonnull)  id<SWPBMAbstractCreative> creative;
@property (nonatomic, assign) SWPBMCreativeFactoryJobState state;

- (nonnull instancetype)init NS_UNAVAILABLE;
- (nonnull instancetype)initFromCreativeModel:(nonnull SWPBMCreativeModel *)creativeModel
                                  transaction:(nonnull id<SWPBMTransaction>)transaction
                                  serverConnection:(nonnull id<SWPBPrebidServerConnectionProtocol>)serverConnection
                              finishedCallback:(nonnull SWPBMCreativeFactoryJobFinishedCallback)finishedCallback
                              NS_DESIGNATED_INITIALIZER;

- (void)startJob;

@end
