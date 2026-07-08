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

#import "SWPBMVastTransactionFactory.h"
#import "SWPBMAdLoadManagerVAST.h"
#import "SWPBMMacros.h"

@interface SWPBMVastTransactionFactory() <SWPBMAdLoadManagerDelegate>

@property (nonatomic, strong, readonly, nonnull) id<SWPBPrebidServerConnectionProtocol> connection;
@property (nonatomic, strong, readonly, nonnull) SWPBMAdConfiguration *adConfiguration;
@property (nonatomic, strong, readonly, nonnull) SWPBBid *bid;

// NOTE: need to call the completion callback only in the main thread
// use onFinishedWithTransaction
@property (nonatomic, copy, readonly, nonnull) SWPBMTransactionFactoryCallback callback;

@property (nonatomic, strong, nullable) SWPBMAdLoadManagerVAST *vastLoadManager;
@property (nonatomic, readonly) BOOL isLoading;

@end


@implementation SWPBMVastTransactionFactory

// MARK: - Public API

- (instancetype)initWithBid:(SWPBBid *)bid
                 connection:(id<SWPBPrebidServerConnectionProtocol>)connection
            adConfiguration:(SWPBMAdConfiguration *)adConfiguration
                   callback:(SWPBMTransactionFactoryCallback)callback
{
    if (!(self = [super init])) {
        return nil;
    }

    _bid = bid;
    _adConfiguration = adConfiguration;
    _connection = connection;
    _callback = [callback copy];
    return self;
}

- (BOOL)loadWithAdMarkup:(NSString *)adMarkup {
    if (self.isLoading) {
        return NO;
    }
    
    return [self loadVASTTransaction:adMarkup];
}

// MARK: - SWPBMAdLoadManagerDelegate protocol

- (void)loadManager:(id<SWPBMAdLoadManagerProtocol>)loadManager didLoadTransaction:(id<SWPBMTransaction>)transaction {
    [self onFinishedWithTransaction:transaction error:nil];
}

- (void)loadManager:(id<SWPBMAdLoadManagerProtocol>)loadManager failedToLoadTransaction:(id<SWPBMTransaction>)transaction
              error:(NSError *)error
{
    [self onFinishedWithTransaction:nil error:error];
}

// MARK: - Private Helpers

- (BOOL)isLoading {
    return (self.vastLoadManager != nil);
}

- (BOOL)loadVASTTransaction:(NSString *)adMarkup {
    self.vastLoadManager = [[SWPBMAdLoadManagerVAST alloc] initWithBid:self.bid
                                                          connection:self.connection
                                                     adConfiguration:self.adConfiguration];
    self.vastLoadManager.adLoadManagerDelegate = self;
    [self.vastLoadManager loadFromString:adMarkup];
    return YES;
}

- (void)onFinishedWithTransaction:(id<SWPBMTransaction>)transaction error:(NSError *)error {
    self.vastLoadManager = nil;
    @weakify(self);
    dispatch_async(dispatch_get_main_queue(), ^{
        @strongify(self);
        if (!self) { return; }
        self.callback(transaction, error);
    });
}

@end
