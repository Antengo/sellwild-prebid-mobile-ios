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

#import "SWPBMCreativeFactory.h"
#import "SWPBMOpenMeasurementSession.h"
#import "SWPBMOpenMeasurementWrapper.h"

#import "SWPBMMacros.h"

#import "SWSwiftImport.h"

@interface SWPBMTransaction_Objc: NSObject <SWPBMTransaction>

@property (nonatomic, strong) id<PrebidServerConnectionProtocol> serverConnection;
@property (nonatomic, strong) SWPBMAdConfiguration *adConfiguration;
@property (nonatomic, strong) SWPBMCreativeFactory *creativeFactory;

@end

@implementation SWPBMTransaction_Objc
@synthesize bid = _bid;
@synthesize creativeModels = _creativeModels;
@synthesize creatives = _creatives;
@synthesize delegate = _delegate;
@synthesize measurementSession = _measurementSession;
@synthesize measurementWrapper = _measurementWrapper;

- (instancetype)initWithServerConnection:(id<PrebidServerConnectionProtocol>)connection
                         adConfiguration:(SWPBMAdConfiguration*)adConfiguration
                                  models:(NSArray<SWPBMCreativeModel *> *)creativeModels {
    self = [super init];
    if (self) {
        self.serverConnection = connection;
        self.adConfiguration = adConfiguration;
        self.creativeModels = creativeModels;
        self.measurementWrapper = SWPBMOpenMeasurementWrapper.shared;
        self.creatives = [NSMutableArray array];
    }
    
    return self;
}

- (void)startCreativeFactory {
    @weakify(self);
    SWPBMCreativeFactoryFinishedCallback finishedCallback = ^(NSArray<id<SWPBMAbstractCreative>> *creatives, NSError *error) {
        @strongify(self);
        self.creativeFactory = NULL;
        if (error) {
            [self.delegate transactionFailedToLoad:self error:error];
        } else if (creatives) {
            self.creatives = [creatives mutableCopy];
            [self createOpenMeasurementSessionForFirstCreative];
            [self updateAdConfiguration];
            [self.delegate transactionReadyForDisplay:self];
        }
    };
    
    self.creativeFactory = [[SWPBMCreativeFactory alloc] initWithServerConnection:self.serverConnection transaction:self finishedCallback:finishedCallback];

    [self.creativeFactory startFactory];
}

- (nullable SWPBMAdDetails *)getAdDetails {
     id<SWPBMAbstractCreative> creative = [self getFirstCreative];
    
    return (creative && creative.creativeModel) ? creative.creativeModel.adDetails : nil;
}

// Return the first item in the list.  If list is empty return nil.
- (id<SWPBMAbstractCreative>)getFirstCreative {
    if ((self.creatives == nil) || (self.creatives.count == 0)) {
        return nil;
    }
    return self.creatives[0];
}

// returns the creative after the current creative.
// retuns nil if the creative is not found or is the last one on the list.
- (id<SWPBMAbstractCreative>)getCreativeAfter:(id<SWPBMAbstractCreative>)creative {
    
    if (!creative) {
        return [self getFirstCreative];
    }
    
    if (creative == [self.creatives lastObject]) {
        return nil;
    }
    
    NSUInteger index = [self.creatives indexOfObject:creative];

    if (index == NSNotFound) {
        return [self getFirstCreative];
    }
    
    // return the next creative
    return self.creatives[index + 1];
}

- (void)createOpenMeasurementSessionForFirstCreative {
     id<SWPBMAbstractCreative> creative = [self getFirstCreative];
    @weakify(self);
    dispatch_async(dispatch_get_main_queue(), ^ {
        @strongify(self);
        if (!self) { return; }
        
        if (creative && !self.measurementSession) {
            [creative createOpenMeasurementSession];
        }
    });
}

- (NSString *)revenueForCreativeAfter:(id<SWPBMAbstractCreative>)creative {
     id<SWPBMAbstractCreative> targetCreative = [self getCreativeAfter:creative];
    if (!targetCreative) {
        targetCreative = creative;
    }
    
    return (targetCreative && targetCreative.creativeModel) ?
        targetCreative.creativeModel.revenue :
        nil;
}

- (void)resetAdConfiguration:(SWPBMAdConfiguration *)adConfiguration {
    self.adConfiguration = adConfiguration;
    for (SWPBMCreativeModel *creativeModel in self.creativeModels) {
        creativeModel.adConfiguration = adConfiguration;
    }
}

- (void)updateAdConfiguration {
    //Update ad size in configuration from first creative model
    SWPBMCreativeModel *firstCreativeModel = [self.creativeModels firstObject];
    if (firstCreativeModel) {
        self.adConfiguration.size = CGSizeMake(firstCreativeModel.width, firstCreativeModel.height);
    }
}

@end
