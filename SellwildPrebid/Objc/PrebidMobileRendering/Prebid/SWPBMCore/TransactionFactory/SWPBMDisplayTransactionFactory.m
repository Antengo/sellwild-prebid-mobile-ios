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

#import "SWPBMDisplayTransactionFactory.h"

#import "SWPBMMacros.h"

#import "SWSwiftImport.h"

@interface SWPBMDisplayTransactionFactory() <SWPBMTransactionDelegate>

@property (nonatomic, strong, readonly, nonnull) SWPBBid *bid;
@property (nonatomic, strong, readonly, nonnull) SWPBAdUnitConfig *adConfiguration;
@property (nonatomic, strong, readonly, nonnull) id<SWPBPrebidServerConnectionProtocol> connection;

// NOTE: need to call the completion callback only in the main thread
// use onFinishedWithTransaction
@property (nonatomic, copy, readonly, nonnull) SWPBMTransactionFactoryCallback callback;

@property (nonatomic, strong, nullable) id<SWPBMTransaction> transaction;
@property (nonatomic, readonly) BOOL isLoading;

@end



@implementation SWPBMDisplayTransactionFactory

// MARK: - Public API

- (instancetype)initWithBid:(SWPBBid *)bid
            adConfiguration:(SWPBAdUnitConfig *)adConfiguration
                 connection:(id<SWPBPrebidServerConnectionProtocol>)connection
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
    
    [self loadHTMLTransaction:adMarkup];
    
    return YES;
}

// MARK: - SWPBMTransactionDelegate protocol

- (void)transactionReadyForDisplay:(id<SWPBMTransaction>)transaction {
    self.transaction = nil;
    [self onFinishedWithTransaction:transaction error:nil];
}

- (void)transactionFailedToLoad:(id<SWPBMTransaction>)transaction error:(NSError *)error {
    self.transaction = nil;
    [self onFinishedWithTransaction:nil error:error];
}

// MARK: - Private Helpers

- (BOOL)isLoading {
    return (self.transaction != nil);
}

- (void)loadHTMLTransaction:(NSString *)adMarkup {
    NSMutableArray<SWPBMCreativeModel *> * const creativeModels = [[NSMutableArray alloc] init];
    
    [creativeModels addObject:[self htmlCreativeModelFromBid:self.bid
                                                    adMarkup:adMarkup
                                             adConfiguration:self.adConfiguration]];
    
    self.transaction = [SWPBMFactory createTransactionWithServerConnection:self.connection
                                                         adConfiguration:self.adConfiguration.adConfiguration
                                                                  models:creativeModels];
    
    self.transaction.bid = self.bid;
    
    self.transaction.delegate = self;
    [self.transaction startCreativeFactory];
}

- (SWPBMCreativeModel *)htmlCreativeModelFromBid:(SWPBBid *)bid
                                      adMarkup:(NSString *)adMarkup
                               adConfiguration:(SWPBAdUnitConfig *)adConfiguration {
    SWPBMCreativeModel * const model = [[SWPBMCreativeModel alloc] initWithAdConfiguration:adConfiguration.adConfiguration];
    
    model.html = adMarkup;
    model.width = bid.size.width;
    model.height = bid.size.height;
    return model;
}

- (void)onFinishedWithTransaction:(id<SWPBMTransaction>)transaction error:(NSError *)error {
    @weakify(self);
    dispatch_async(dispatch_get_main_queue(), ^{
        @strongify(self);
        if (!self) { return; }
        self.callback(transaction, error);
    });
}

@end
