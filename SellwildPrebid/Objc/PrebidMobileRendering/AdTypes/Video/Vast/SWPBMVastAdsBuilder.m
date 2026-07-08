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

#import "SWPBMVastAdsBuilder.h"

#import "SWPBMConstants.h"
#import "SWPBMVastParser.h"
#import "SWPBMVastInlineAd.h"
#import "SWPBMVastResponse.h"
#import "SWPBMVastRequester.h"
#import "SWPBMVastWrapperAd.h"
#import "SWPBMURLComponents.h"
#import "NSException+SWPBMExtensions.h"
#import "SWPBMVastCreativeLinear.h"
#import "SWPBMMacros.h"
#import "SWLog+Extensions.h"

#import "SWSwiftImport.h"

typedef void(^SWPBMVastAdsBuilderWrapperCompletionBlock)(NSError *);

#pragma mark - Private Extension

@interface SWPBMVastAdsBuilder()

@property (nonatomic, strong) dispatch_queue_t dispatchQueue;
@property (nonatomic, strong) id<SWPBPrebidServerConnectionProtocol> serverConnection;
@property (nonatomic, assign) NSInteger requestsPending;
@property (nonatomic, assign) NSInteger maximumWrapperDepth;     // Per VAST 4.0 spec section 2.3.4.1
@property (nonatomic, strong, nullable) SWPBMVastResponse *rootResponse;

@end

#pragma mark - Implementation

@implementation SWPBMVastAdsBuilder

#pragma mark - Initialization

-(instancetype)initWithConnection:(id<SWPBPrebidServerConnectionProtocol>)serverConnection {
    self = [super init];
    if (self) {
        SWPBMAssert(serverConnection);
        
        self.requestsPending = 0;
        self.maximumWrapperDepth = 5;
        self.serverConnection = serverConnection;
        self.dispatchQueue = dispatch_queue_create("SWPBMVastLoaderQueue", NULL);
    }
    return self;
}

#pragma mark - Public

- (void)buildAds:(nonnull NSData *)data completion:(SWPBMVastAdsBuilderCompletionBlock)completionBlock {
    @weakify(self);
    [self buildAds:data wrapperAd:nil completion:^(NSError *error){
        @strongify(self);
        
        if (!self) {
            completionBlock(nil, [SWPBMError errorWithDescription:@"VAST error: the ads builder is failed" statusCode:SWPBMErrorCodeUndefined]);
            return;
        }
        
        if (error) {
            completionBlock(nil, error);
            return;
        }
        
        NSArray<SWPBMVastAbstractAd *> *ads = [self extractAdsWithError:&error];
        completionBlock(ads, error);
    }];
}

- (BOOL)checkHasNoAdsAndFireURIs:(SWPBMVastResponse *)vastResponse {
    
    BOOL firedNoAdsURI = false;
    
    // To check no ads responses, we find any response that had an Ad/Inline element that had zero creatives.
    // Then we walk backward from that response to any preceding wrapper responses that have an errorURI provided.
    
    if (vastResponse.vastAbstractAds.count == 0) {
        
        //If we have no ads, fire noAdsResponseURI on every wrapper up the chain.
        //First check response itself. then loop up
        
        SWPBMVastResponse *parent = vastResponse;
        while (parent) {
            
            if (parent.noAdsResponseURI) {
                [self.serverConnection fireAndForget: parent.noAdsResponseURI];
            }
            
            //Avoid infinite loop
            if (parent.parentResponse == parent) {
                break;
            }
            
            parent = parent.parentResponse;
        }
        firedNoAdsURI = true;
    }
    else {
        
        for (SWPBMVastAbstractAd *ad in vastResponse.vastAbstractAds) {
            
            //If the Ad is a wrapper
            if ([ad isKindOfClass: [SWPBMVastWrapperAd class]]) {
                SWPBMVastWrapperAd *unwrappedVASTWrapper = (SWPBMVastWrapperAd *)ad;
                
                //And it has a response
                if (unwrappedVASTWrapper.vastResponse) {
                    SWPBMVastResponse *unwrappedVastResponse = unwrappedVASTWrapper.vastResponse;
                    firedNoAdsURI = firedNoAdsURI || [self checkHasNoAdsAndFireURIs:unwrappedVastResponse];
                }
                else {
                    SWPBMLogError(@"No vastResponse on Wrapper");
                }
            }
        }
    }
    
    return firedNoAdsURI;
}

#pragma mark - Private

- (void)buildAds:(nonnull NSData *)data wrapperAd:(SWPBMVastWrapperAd *)wrapperAd completion:(SWPBMVastAdsBuilderWrapperCompletionBlock)completionBlock {
    
    if (wrapperAd && (wrapperAd.depth > self.maximumWrapperDepth)) {
        NSError *error = [SWPBMError errorWithDescription:@"Wrapper limit reached, as defined by the video player. Too many Wrapper responses have been received with no InLine response." statusCode:SWPBMErrorCodeUndefined];
        completionBlock(error);
        return;
    }
    
    SWPBMVastParser *parser = [SWPBMVastParser new];
    SWPBMVastResponse *parsedResponse = [parser parseAdsResponse:data];
    if (!parsedResponse) {
        NSString *strVast = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString *message = [NSString stringWithFormat:@"VAST Parsing failed. XML was:  %@", strVast];
        completionBlock([SWPBMError errorWithDescription:message statusCode:SWPBMErrorCodeUndefined]);
        return;
    }

    @weakify(self);
    [self handleResponse:parsedResponse forWrapperAd:wrapperAd completion:^(NSError *error) {
        @strongify(self);
        if (!self) {
            completionBlock([SWPBMError errorWithDescription:@"VAST error: the ads builder is failed" statusCode:SWPBMErrorCodeUndefined]);
            return;
        }
        
        if (error) {
            completionBlock(error);
            return;
        }
        
        if (wrapperAd) {
            dispatch_sync(self.dispatchQueue, ^{
                self.requestsPending -= 1;
            });

            completionBlock(nil);
        } else if (self.requestsPending == 0) {
            completionBlock(nil);
        }
    }];
}

- (void)requestAds:(NSString *)vastURL
      forWrapperAd:(SWPBMVastWrapperAd *)wrapperAd
        completion:(SWPBMVastAdsBuilderWrapperCompletionBlock)completion {
    
    @weakify(self);
    dispatch_sync(self.dispatchQueue, ^{
        @strongify(self);
        if (!self) {
            completion([SWPBMError errorWithDescription:@"VAST error: the ads builder is failed" statusCode:SWPBMErrorCodeUndefined]);
            return;
        }
        
        self.requestsPending += 1;
    });
    
    [self.serverConnection get:vastURL timeout:SWPBPrebidConstants.CONNECTION_TIMEOUT_DEFAULT callback:^(SWPBPrebidServerResponse * _Nonnull serverResponse) {
        if (serverResponse.error) {
            completion(serverResponse.error);
            return;
        }
        
        if (serverResponse.statusCode != 200) {
            NSString *message = [NSString stringWithFormat:@"Server responded with status code %li", (long)serverResponse.statusCode];
            completion([SWPBMError errorWithDescription:message statusCode:serverResponse.statusCode]);
            return;
        }
        
        [self buildAds:serverResponse.rawData wrapperAd:wrapperAd completion:completion];
    }];
}

- (void)handleResponse:(SWPBMVastResponse *)response
          forWrapperAd:(SWPBMVastWrapperAd *)wrapperAd
            completion:(SWPBMVastAdsBuilderWrapperCompletionBlock)completionBlock {
    
    if (wrapperAd) {
        //Assign nextResponse and parentResponse
        wrapperAd.vastResponse = response;
        response.parentResponse = wrapperAd.ownerResponse;
        
        //If multiple ads are disabled, drop everything but the first ad with a sequence of 0.
        if (!wrapperAd.allowMultipleAds) {
            for (SWPBMVastAbstractAd *ad in response.vastAbstractAds) {
                if (ad.sequence == 0) {
                    response.vastAbstractAds = [NSMutableArray arrayWithObject:ad];
                    break;
                }
            }
        }
        
        //If the parent asked us not to follow wrappers, remove any wrappers we find in the response.
        if (!wrapperAd.followAdditionalWrappers) {
            NSMutableArray *filtered = [NSMutableArray array];
            for (id obj in response.vastAbstractAds) {
                if (![obj isKindOfClass:[SWPBMVastWrapperAd class]]) {
                    [filtered addObject:obj];
                }
            }
            response.vastAbstractAds = filtered;
        }
        
        //Copy parent's allowMultipleAds setting to child wrappers
        for (id obj in response.vastAbstractAds) {
            if ([obj isKindOfClass:[SWPBMVastWrapperAd class]]) {
                SWPBMVastWrapperAd *wrapper = obj;
                wrapper.allowMultipleAds = wrapperAd.allowMultipleAds;
            }
        }
    }
    else {
        // If parentWrapper is nil, this is the root response.
        self.rootResponse = response;
    }
    
    //If we're not at the max depth then add a request for each wrapper.
    BOOL hasWrappers = NO;
    for (id obj in response.vastAbstractAds) {
        if ([obj isKindOfClass:[SWPBMVastWrapperAd class]]) {
            hasWrappers = YES;

            SWPBMVastWrapperAd *responseWrapperAd = obj;
            responseWrapperAd.depth = wrapperAd.depth + 1;
            
            [self requestAds:responseWrapperAd.vastURI forWrapperAd:responseWrapperAd completion:completionBlock];
        }
    }
    
    if (!hasWrappers) {
        completionBlock(nil);
    }
}

-(BOOL)hasValidMedia:(NSArray *)ads {
    for (SWPBMVastInlineAd *ad in ads) {
        for (SWPBMVastCreativeAbstract *creative in ad.creatives) {
            if ([creative isKindOfClass:[SWPBMVastCreativeLinear class]]) {
                SWPBMVastCreativeLinear *swpbmVastCreativeLinear = (SWPBMVastCreativeLinear*) creative;
                if ([swpbmVastCreativeLinear bestMediaFile]) {
                    return true;
                }
            }
        }
    }
    return false;
}

- (NSArray<SWPBMVastAbstractAd *> *)extractAdsWithError:(NSError *__autoreleasing  _Nullable *)error {
    if (!self.rootResponse) {
        [SWPBMError createError:error description:@"No Root Response" statusCode:SWPBMErrorCodeFileNotFound];
        return nil;
    }
    
    // check for ads & media and fire appropriate URIs
    if ([self checkHasNoAdsAndFireURIs: self.rootResponse]) {
        [SWPBMError createError:error description:@"One or more responses had no ads" statusCode:SWPBMErrorCodeGeneralLinear];
        return nil;
    }
    
    NSError *flatterError;
    NSArray *ads = [self.rootResponse flattenResponseAndReturnError:&flatterError];
    if (flatterError) {
        if(error != nil) {
            *error = [flatterError copy];
        }
        return nil;
    }
    
    if (![self hasValidMedia:ads]) {
        [SWPBMError createError:error description:@"No Valid Media" statusCode:SWPBMErrorCodeFileNotFound];
        return nil;
    }
    
    return ads;
}

@end
