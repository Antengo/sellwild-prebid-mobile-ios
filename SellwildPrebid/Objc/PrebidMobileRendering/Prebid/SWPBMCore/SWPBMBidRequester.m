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

#import "SWPBMBidResponseTransformer.h"

#import "SWPBMPrebidParameterBuilder.h"
#import "SWPBMParameterBuilderService.h"
#import "SWLog+Extensions.h"
#import <UIKit/UIKit.h>
#import "SWSwiftImport.h"

#import "SWPBMMacros.h"

@interface SWPBMBidRequester_Objc: NSObject <SWPBMBidRequester>

@property (nonatomic, strong, nonnull, readonly) id<SWPBPrebidServerConnectionProtocol> connection;
@property (nonatomic, strong, nonnull, readonly) SellwildPrebid *sdkConfiguration;
@property (nonatomic, strong, nonnull, readonly) SWPBTargeting *targeting;
@property (nonatomic, strong, nonnull, readonly) SWPBAdUnitConfig *adUnitConfiguration;

@property (nonatomic, copy, nullable) void (^completion)(SWPBBidResponse *, NSError *);

@end

@implementation SWPBMBidRequester_Objc

- (instancetype)initWithConnection:(id<SWPBPrebidServerConnectionProtocol>)connection
                  sdkConfiguration:(SellwildPrebid *)sdkConfiguration
                         targeting:(SWPBTargeting *)targeting
               adUnitConfiguration:(SWPBAdUnitConfig *)adUnitConfiguration {
    if (!(self = [super init])) {
        return nil;
    }
    _connection = connection;
    _sdkConfiguration = sdkConfiguration;
    _targeting = targeting;
    _adUnitConfiguration = adUnitConfiguration;
    return self;
}

- (void)requestBidsWithCompletion:(void (^)(SWPBBidResponse *, NSError *))completion {
    @weakify(self);
    [SWPBMUserAgentService.shared fetchUserAgentWithCompletion:^(NSString * _Nonnull userAgent) {
        @strongify(self);
        [self makeRequestWithCompletion:completion];
    }];
}

- (void)makeRequestWithCompletion:(void (^)(SWPBBidResponse *, NSError *))completion {
    NSError * const setupError = [self findErrorInSettings];
    if (setupError) {
        completion(nil, setupError);
        return;
    }
    
    if (self.completion) {
        completion(nil, [SWPBMError requestInProgress]);
        return;
    }
    
    self.completion = completion ?: ^(SWPBBidResponse *r, NSError *e) {};
    
    NSString * const requestString = [self getRTBRequest];
    
    NSError * hostURLError = nil;
    NSString * const requestServerURL = [SWPBHost.shared getHostURLAndReturnError:&hostURLError];
    
    if (hostURLError) {
        completion(nil, hostURLError);
        return;
    }
    
    const NSInteger rawTimeoutMS_onRead     = self.sdkConfiguration.timeoutMillis;
    NSNumber * const dynamicTimeout_onRead  = self.sdkConfiguration.timeoutMillisDynamic;
    
    const NSTimeInterval postTimeout = (dynamicTimeout_onRead ? dynamicTimeout_onRead.doubleValue : (rawTimeoutMS_onRead / 1000.0));
    
    NSData *rtbRequestData = [requestString dataUsingEncoding:NSUTF8StringEncoding];
    
    @weakify(self);
    NSDate * const requestDate = [NSDate date];
    [self.connection post:requestServerURL
                     data:rtbRequestData
                  timeout:postTimeout
                 callback:^(SWPBPrebidServerResponse * _Nonnull serverResponse) {
        @strongify(self);
        if (!self) { return; }

        // Fix for GitHub Issue #1195: Thread-safe completion handling
        // Protect against duplicate callback invocations (redirects, retries, network bugs)
        void (^ _Nullable completion)(SWPBBidResponse *, NSError *) = nil;
        @synchronized(self) {
            completion = self.completion;
            if (!completion) {
                // Completion already called or nil - this is a duplicate callback
                SWPBMLogInfo(@"WARNING: Network callback invoked multiple times. Ignoring duplicate callback. Thread: %@", [NSThread currentThread]);
                return;
            }
            // Clear completion to prevent duplicate invocations
            self.completion = nil;
        }

        if (serverResponse.statusCode == 204) {
            completion(nil, SWPBMError.blankResponse);
            return;
        }

        if (serverResponse.error) {
            SWPBMLogInfo(@"SWPBBid Request Error: %@", [serverResponse.error localizedDescription]);
            completion(nil, serverResponse.error);
            return;
        }

        SWPBMLogInfo(@"SWPBBid Response: %@", [[NSString alloc] initWithData:serverResponse.rawData encoding:NSUTF8StringEncoding]);

        NSError *trasformationError = nil;
        SWPBBidResponse * const _Nullable bidResponse = [SWPBMBidResponseTransformer transformResponse:serverResponse error:&trasformationError];
        
        if (bidResponse && !trasformationError) {
            if (self.sdkConfiguration.requireServerSideBidCache) {
                NSInteger bidCount = bidResponse.allBids.count;
                NSInteger removedBids = [bidResponse removeBidsWithoutSuccessfulCache];
                if (removedBids > 0) {
                    SWPBMLogWarn(@"Ignored %ld bids without successful Prebid Cache entries.", (long)removedBids);
                }
                if (!bidResponse.winningBid) {
                    NSError *error = bidCount > 0 && bidCount == removedBids ? SWPBMError.noCachedBids : SWPBMError.noWinningBid;
                    completion(nil, error);
                    [SellwildPrebid.shared callEventDelegateAsync_prebidBidRequestDidFinishWithRequestData:rtbRequestData
                                                                                       responseData:serverResponse.rawData];
                    return;
                }
            }
            
            NSNumber * const tmaxrequest = bidResponse.tmaxrequest;
            if (tmaxrequest) {
                NSDate * const responseDate = [NSDate date];
                
                const NSTimeInterval bidResponseTimeout = tmaxrequest.doubleValue / 1000.0;
                const NSTimeInterval remoteTimeout = ([responseDate timeIntervalSinceDate:requestDate]
                                                      + bidResponseTimeout
                                                      + 0.2);
                NSString * const currentServerURL = [SWPBHost.shared getHostURLAndReturnError:nil];
                if (self.sdkConfiguration.timeoutMillisDynamic == nil && [currentServerURL isEqualToString:requestServerURL]) {
                    const NSInteger rawTimeoutMS_onWrite = self.sdkConfiguration.timeoutMillis;
                    const NSTimeInterval appTimeout = rawTimeoutMS_onWrite / 1000.0;
                    const NSTimeInterval updatedTimeout = MIN(remoteTimeout, appTimeout);
                    self.sdkConfiguration.timeoutMillisDynamic = @(updatedTimeout);
                    self.sdkConfiguration.timeoutUpdated = true;
                };
            }
            
            SWPBMORTBSDKConfiguration *pbsSDKConfig = [bidResponse.ext.extPrebid.passthrough filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SWPBORTBExtPrebidPassthrough *_Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                return [evaluatedObject.type isEqual: @"prebidmobilesdk"];
            }]].firstObject.sdkConfiguration;
            
            if(pbsSDKConfig) {
                if(pbsSDKConfig.cftBanner) {
                    SellwildPrebid.shared.creativeFactoryTimeout = pbsSDKConfig.cftBanner.doubleValue;
                }
                
                if(pbsSDKConfig.cftPreRender) {
                    SellwildPrebid.shared.creativeFactoryTimeoutPreRenderContent = pbsSDKConfig.cftPreRender.doubleValue;
                }
            }
        }
        
        completion(bidResponse, trasformationError);
        [SellwildPrebid.shared callEventDelegateAsync_prebidBidRequestDidFinishWithRequestData:rtbRequestData 
                                                                     responseData:serverResponse.rawData];
    }];
}

- (NSString *)getRTBRequest {
    
    SWPBMPrebidParameterBuilder * const
    prebidParamsBuilder = [[SWPBMPrebidParameterBuilder alloc] initWithAdConfiguration:self.adUnitConfiguration
                                                                    sdkConfiguration:self.sdkConfiguration
                                                                           targeting:self.targeting
                                                                    userAgentService:self.connection.userAgentService];
    
    NSDictionary<NSString *, NSString *> * const
    params = [SWPBMParameterBuilderService buildParamsDictWithAdConfiguration:self.adUnitConfiguration.adConfiguration
                                                     extraParameterBuilders:@[prebidParamsBuilder]];
        
    return params[@"openrtb"];
}

- (NSError *)findErrorInSettings {
    if (!CGSizeEqualToSize(self.adUnitConfiguration.adSize, CGSizeZero)) {
        
        if ([self isInvalidSize:[NSValue valueWithCGSize:self.adUnitConfiguration.adSize]]) {
            return [SWPBMError prebidInvalidSize];
        }
    }
    if (self.adUnitConfiguration.additionalSizes) {
        for (NSValue *nextSize in self.adUnitConfiguration.additionalSizes) {
            if ([self isInvalidSize:nextSize]) {
                return [SWPBMError prebidInvalidSize];
            }
        }
    }
    if ([self isInvalidID:self.adUnitConfiguration.configId]) {
        return [SWPBMError prebidInvalidConfigId];
    }
    if ([self isInvalidID:self.sdkConfiguration.prebidServerAccountId]) {
        return [SWPBMError prebidInvalidAccountId];
    }
    return nil;
}

- (BOOL)isInvalidSize:(NSValue *)sizeObj {
    CGSize const size = sizeObj.CGSizeValue;
    return (size.width < 0 || size.height < 0);
}

- (BOOL)isInvalidID:(NSString *)idString {
    return (!idString || [idString isEqualToString:@""] || [[idString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] length] == 0);
}

@end
