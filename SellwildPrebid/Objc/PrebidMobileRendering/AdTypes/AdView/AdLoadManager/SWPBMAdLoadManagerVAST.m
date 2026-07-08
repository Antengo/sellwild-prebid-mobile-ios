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

#import "SWPBMAdLoadManagerVAST.h"
#import "SWPBMAdRequesterVAST.h"
#import "SWPBMCreativeModelCollectionMakerVAST.h"
#import "SWPBMMacros.h"
#import "SWLog+Extensions.h"

#import "SWSwiftImport.h"

#pragma mark - Internal Interface

@interface SWPBMAdLoadManagerVAST ()

@property (nonatomic, strong) SWPBMCreativeModelCollectionMakerVAST* creativeModelCollectionMaker;
@property (nonatomic, strong) SWPBMAdRequesterVAST *adRequester;

@end

#pragma mark - Implementation

@implementation SWPBMAdLoadManagerVAST

- (void)loadFromString:(NSString *)vastString {
    @weakify(self);
    dispatch_async(self.dispatchQueue, ^{
        @strongify(self);
        if (!self) {
            SWPBMLogError(@"SWPBMAdLoadManagerVast is nil!");
            return;
        }
        
        if ([self prepareForLoading]) {
            [self.adRequester buildVastAdsArray:[vastString dataUsingEncoding:NSUTF8StringEncoding]];
        }
    });
}

- (BOOL)prepareForLoading {
    if (self.adRequester) {
        SWPBMLogError(@"Previous load is in progress. Load() ignored.");
        return NO;
    }
    self.adRequester = [[SWPBMAdRequesterVAST alloc] initWithServerConnection:self.connection adConfiguration:self.adConfiguration];
    self.adRequester.adLoadManager = self;
    
    self.creativeModelCollectionMaker = [[SWPBMCreativeModelCollectionMakerVAST alloc] initWithServerConnection:self.connection adConfiguration:self.adConfiguration];
    return YES;
}

- (void)requestCompletedSuccess:(SWPBMAdRequestResponseVAST *)adRequestResponse {
    SWPBMLogWhereAmI();
    
    @weakify(self);
    [self.creativeModelCollectionMaker makeModels:adRequestResponse
                                  successCallback: ^(NSArray *creativeModels) {
                                      @strongify(self);
                                      if (!self) {
                                          SWPBMLogError(@"SWPBMAdLoadManagerVAST is nil!");
                                          return;
                                      }
                                      
                                      [self makeCreativesWithCreativeModels:creativeModels];
                                  }
                                  failureCallback: ^(NSError *error) {
                                      @strongify(self);
                                      if (!self) {
                                          SWPBMLogError(@"SWPBMAdLoadManagerVAST is nil!");
                                          return;
                                      }
                                      
                                      [self.adLoadManagerDelegate loadManager:self failedToLoadTransaction:nil error:error];
                                  }];
}

@end
