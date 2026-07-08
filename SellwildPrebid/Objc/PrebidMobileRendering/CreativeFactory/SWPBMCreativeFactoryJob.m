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

#import "SWPBMCreativeFactoryJob.h"
#import "SWPBMHTMLCreative.h"
#import "SWPBMVideoCreative.h"
#import "SWPBMDownloadDataHelper.h"
#import "SWPBMMacros.h"
#import "SWLog+Extensions.h"

#import "SWSwiftImport.h"

@interface SWPBMCreativeFactoryJob ()

@property (nonatomic, strong) SWPBMCreativeModel *creativeModel;
@property (nonatomic, copy) SWPBMCreativeFactoryJobFinishedCallback finishedCallback;
@property (nonatomic, strong) id<PrebidServerConnectionProtocol> serverConnection;
@property (nonatomic, strong) id<SWPBMTransaction>transaction;

@end

@implementation SWPBMCreativeFactoryJob {
    dispatch_queue_t _dispatchQueue;
}

- (nonnull instancetype)initFromCreativeModel:(nonnull SWPBMCreativeModel *)creativeModel
                                  transaction:(id<SWPBMTransaction>)transaction
                             serverConnection:(nonnull id<PrebidServerConnectionProtocol>)serverConnection
                              finishedCallback:(SWPBMCreativeFactoryJobFinishedCallback)finishedCallback {
    self = [super init];
    if (self) {
        self.creativeModel = creativeModel;
        self.serverConnection = serverConnection;
        self.state = SWPBMCreativeFactoryJobStateInitialized;
        self.finishedCallback = finishedCallback;
        self.transaction = transaction;
        NSString *uuid = [[NSUUID UUID] UUIDString];
        const char *queueName = [[NSString stringWithFormat:@"SWPBMCreativeFactoryJob_%@", uuid] UTF8String];
        _dispatchQueue = dispatch_queue_create(queueName, NULL);
    }
    
    return self;
}

- (void)successWithCreative:(id<SWPBMAbstractCreative>)creative {
    self.creative = creative;
    @weakify(self);
    dispatch_async(_dispatchQueue, ^{
        @strongify(self);
        if (!self) { return; }
        
        if (self.state == SWPBMCreativeFactoryJobStateRunning) {
            self.state = SWPBMCreativeFactoryJobStateSuccess;
            if (self.finishedCallback) {
                self.finishedCallback(self, NULL);
            }
        }
    });
}

- (void)failWithError:(NSError *)error {
    @weakify(self);
    dispatch_async(_dispatchQueue, ^{
        @strongify(self);
        if (!self) { return; }
        
        if (self.state == SWPBMCreativeFactoryJobStateRunning) {
            self.state = SWPBMCreativeFactoryJobStateError;
            if (self.finishedCallback) {
                self.finishedCallback(self, error);
            }
        }
    });
}

- (void)startJob {
    [self startJobWithTimeInterval:[self getTimeInterval]];
}

/*
 For internal use only
 */
- (void)startJobWithTimeInterval:(NSTimeInterval)timeInterval {
    SWPBMAssert(self.creativeModel);
    if (!self.creativeModel) {
        [self failWithError:[SWPBMError errorWithMessage:@"SWPBMCreativeFactoryJob: Undefined creative model"
                                                  type:SWPBMErrorType.internalError]];
        return;
    }
    
    [self startJobTimerWithTimeInterval:timeInterval];
    
    @weakify(self);
    dispatch_async(_dispatchQueue, ^{
        @strongify(self);
        if (!self) { return; }
        
        if (self.state != SWPBMCreativeFactoryJobStateInitialized) {
            [self failWithError:[SWPBMError errorWithMessage:@"SWPBMCreativeFactoryJob: Tried to start SWPBMCreativeFactory twice"
                                                      type:SWPBMErrorType.internalError]];
            return;
        }
        
        self.state = SWPBMCreativeFactoryJobStateRunning;
    });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!(self.creativeModel && self.creativeModel.adConfiguration)) {
            [self failWithError:[SWPBMError errorWithMessage:@"SWPBMCreativeFactoryJob: Undefined creative model"
                                                      type:SWPBMErrorType.internalError]];
            return;
        }
        
        AdFormat *adType = self.creativeModel.adConfiguration.winningBidAdFormat;
        if (adType == AdFormat.banner || self.creativeModel.isCompanionAd) {
            [self attemptAUIDCreative];
        } else if (adType == AdFormat.video) {
            [self attemptVASTCreative];
        } else if (adType == nil) {
            SWPBMLogError(@"The winning bid ad format is nil.")
        }
    });
}

- (void)startJobTimerWithTimeInterval:(NSTimeInterval)timeInterval {
    @weakify(self);
    __block void (^timer)(void) = ^{
        double delayInSeconds = timeInterval;
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        dispatch_after(time, dispatch_get_main_queue(), ^(void){
            @strongify(self);
            if (!self) { return; }
            
            [self failWithError:[SWPBMError errorWithMessage:@"SWPBMCreativeFactoryJob: Failed to complete in specified time interval"
                                                      type:SWPBMErrorType.internalError]];
        });
    };
    
    timer();
}

- (void)attemptAUIDCreative {
    if (!(self.creativeModel && self.creativeModel.adConfiguration)) {
        [self failWithError:[SWPBMError errorWithMessage:@"SWPBMCreativeFactoryJob: Undefined creative model"
                                                  type:SWPBMErrorType.internalError]];
        return;
    }
    
    self.creative = [[SWPBMHTMLCreative alloc] initWithCreativeModel:self.creativeModel
                                                       transaction:self.transaction];
    
    if ([self.creative isKindOfClass:[SWPBMHTMLCreative class]]) {
        SWPBMHTMLCreative *creative = (SWPBMHTMLCreative *)self.creative;
        creative.downloadBlock = [self createLoader];
    }
    
    self.creative.creativeResolutionDelegate = self;
    [self.creative setupView];
}

- (void)attemptVASTCreative {
    if (!self.creativeModel) {
        [self failWithError:[SWPBMError errorWithMessage:@"SWPBMCreativeFactoryJob: Undefined creative model"
                                                  type:SWPBMErrorType.internalError]];
        return;
    }
    
    NSString *strUrl = self.creativeModel.videoFileURL;
    if (!strUrl) {
        [self failWithError:[SWPBMError errorWithDescription:@"SWPBMCreativeFactoryJob: Could not initialize VideoCreative without videoFileURL"]];
        return;
    }
    
    NSURL *url = [NSURL URLWithString:strUrl];
    if (!url) {
        [self failWithError:[SWPBMError errorWithDescription:[NSString stringWithFormat:@"Could not create URL from url string: %@", strUrl]]];
        return;
    }
    
    SWPBMDownloadDataHelper *downloader = [[SWPBMDownloadDataHelper alloc] initWithServerConnection:self.serverConnection];
    [downloader downloadDataForURL:url maxSize:SWPBMVideoCreative.maxSizeForPreRenderContent completionClosure:^(NSData * _Nullable preloadedData, NSError * _Nullable error) {
        if (error) {
            [self failWithError:error];
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self initializeVideoCreative:preloadedData];
        });
    }];
}

- (void)initializeVideoCreative:(NSData *)data {
    self.creative = [[SWPBMVideoCreative alloc] initWithCreativeModel:self.creativeModel transaction:self.transaction videoData:data];
    self.creative.creativeResolutionDelegate = self;
    [self.creative setupView];
}

- (NSTimeInterval)getTimeInterval {
    SWPBMAdConfiguration *adConfig = self.creativeModel.adConfiguration;
    if (adConfig.winningBidAdFormat == AdFormat.video || adConfig.presentAsInterstitial) {
        return SellwildPrebid.shared.creativeFactoryTimeoutPreRenderContent;
    } else {
        return SellwildPrebid.shared.creativeFactoryTimeout;
    }
}

- (SWPBMDownloadDataHelper *)initializeDownloadDataHelper {
    return [[SWPBMDownloadDataHelper alloc] initWithServerConnection:self.serverConnection];
}

- (SWPBMCreativeFactoryDownloadDataCompletionClosure)createLoader {
    id<PrebidServerConnectionProtocol> const connection = self.serverConnection;
    SWPBMCreativeFactoryDownloadDataCompletionClosure result = ^(NSURL* _Nonnull  url, SWPBMDownloadDataCompletionClosure _Nonnull completionBlock) {
        SWPBMDownloadDataHelper *downloader = [[SWPBMDownloadDataHelper alloc] initWithServerConnection:connection];
        [downloader downloadDataForURL:url completionClosure:^(NSData * _Nullable data, NSError * _Nullable error) {
            completionBlock ? completionBlock(data, error) : nil;
        }];
    };
    
    return result;
}

#pragma mark - SWPBMCreativeResolutionDelegate

- (void)creativeReady:(id<SWPBMAbstractCreative>)creative {
    [self successWithCreative:creative];
}

- (void)creativeFailed:(NSError *)error {
    [self failWithError:error];
}

@end
