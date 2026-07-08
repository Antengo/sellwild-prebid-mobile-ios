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

#import "SWPBMConstants.h"
#import "SWPBMMacros.h"
#import "SWPBMORTB.h"

#import "SWInternalUserConsentDataManager.h"

#import "SWPBMBasicParameterBuilder.h"
#import "SWLog+Extensions.h"

#import "SWSwiftImport.h"

#pragma mark - Internal Extension

@interface SWPBMBasicParameterBuilder ()

// Note: properties below are marked with 'readwrite' for UnitTests to be able to write 'nil' into them.
// TODO: Prove that 'init' arguments are never nil; convert to 'readonly'; remove redundant checks and tests.

@property (nonatomic, strong, readwrite) SWPBMAdConfiguration *adConfiguration;
@property (nonatomic, strong, readwrite) SellwildPrebid *sdkConfiguration;
@property (nonatomic, strong, readwrite) SWPBTargeting *targeting;
@property (nonatomic, copy, readwrite) NSString *sdkVersion;

@end

#pragma mark - Implementation

@implementation SWPBMBasicParameterBuilder

#pragma mark - Properties

+ (NSString *)platformKey {
    return @"sp";
}

+ (NSString *)platformValue {
    return @"iOS";
}

+ (NSString *)allowRedirectsKey {
    return @"dr";
}

+ (NSString *)allowRedirectsVal {
    return @"true";
}

+ (NSString *)sdkVersionKey {
    return @"sv";
}

+ (NSString *)urlKey {
    return SWPBPrebidConstants.APP_STORE_URL_SCHEME;
}

+ (NSString*)rewardedVideoKey {
    return @"vrw";
}

+ (NSString*)rewardedVideoValue {
    return @"1";
}

#pragma mark - Initialization

- (instancetype)initWithAdConfiguration:(SWPBMAdConfiguration *)adConfiguration
                       sdkConfiguration:(SellwildPrebid *)sdkConfiguration
                             sdkVersion:(NSString *)sdkVersion
                              targeting:(SWPBTargeting *)targeting
{
    if (!(self = [super init])) {
        return nil;
    }
    SWPBMAssert(adConfiguration && sdkConfiguration && sdkVersion && targeting);
    
    _adConfiguration = adConfiguration;
    _sdkConfiguration = sdkConfiguration;
    _sdkVersion = sdkVersion;
    _targeting = targeting;
    
    return self;
}

#pragma mark - Methods

- (void)buildBidRequest:(SWPBMORTBBidRequest *)bidRequest {
    if (!(self.adConfiguration && self.sdkConfiguration && self.sdkVersion)) {
        SWPBMLogError(@"Invalid properties");
        return;
    }

    //Add an impression if none exist
    if ([bidRequest.imp count] == 0) {
        bidRequest.imp = @[[[SWPBMORTBImp alloc] init]];
    }
    
    for (SWPBMORTBImp *rtbImp in bidRequest.imp) {
        rtbImp.displaymanager = self.adConfiguration.isOriginalAPI ? nil : @"prebid-mobile";
        rtbImp.displaymanagerver = self.adConfiguration.isOriginalAPI ? nil : self.sdkVersion;
        
        rtbImp.instl = @(self.adConfiguration.presentAsInterstitial ? 1 : 0);
        
        //set secure=1 for https or secure=0 for http
        rtbImp.secure = @1;
    }
    
    bidRequest.regs.coppa = self.targeting.coppa;
    bidRequest.regs.ext[@"gdpr"] = [self.targeting getSubjectToGDPR];
    bidRequest.regs.gpp = SWInternalUserConsentDataManager.gppHDRString;
    
    if (SWInternalUserConsentDataManager.gppSID.count > 0) {
        bidRequest.regs.gppSID = SWInternalUserConsentDataManager.gppSID;
    }
    
    [self appendFormatSpecificParametersForRequest:bidRequest];
}

- (void)appendFormatSpecificParametersForRequest:(SWPBMORTBBidRequest *)bidRequest {
    if ([self.adConfiguration.adFormats containsObject:SWPBAdFormat.banner]) {
        [self appendDisplayParametersForRequest:bidRequest];
    }
    
    if ([self.adConfiguration.adFormats containsObject:SWPBAdFormat.video]) {
        [self appendVideoParametersForRequest:bidRequest];
    }
    
    if ([self.adConfiguration.adFormats containsObject:SWPBAdFormat.native]) {
        [self appendNativeParametersForRequest:bidRequest];
    }
}

- (void)appendDisplayParametersForRequest:(SWPBMORTBBidRequest *)bidRequest {
    //Ensure there's at least 1 banner
    BOOL hasBanner = NO;
    for (SWPBMORTBImp *imp in bidRequest.imp) {
        if (imp.banner) {
            hasBanner = YES;
            break;
        }
    }
    
    if (!hasBanner) {
        [bidRequest.imp firstObject].banner = [[SWPBMORTBBanner alloc] init];
    }
}

- (void)appendVideoParametersForRequest:(SWPBMORTBBidRequest *)bidRequest {
    [bidRequest.imp firstObject].video = [[SWPBMORTBVideo alloc] init];
}

- (void)appendNativeParametersForRequest:(SWPBMORTBBidRequest *)bidRequest {
    [bidRequest.imp firstObject].native = [[SWPBMORTBNative alloc] init];
}

@end
