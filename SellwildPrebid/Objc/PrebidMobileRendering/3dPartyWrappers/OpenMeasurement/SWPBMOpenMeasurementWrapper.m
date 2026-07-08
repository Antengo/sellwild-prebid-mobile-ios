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

#import "SWPBMFunctions.h"
#import "SWPBMFunctions+Private.h"
#import "SWPBMMacros.h"
#import "SWPBMOpenMeasurementWrapper.h"
#import "SWLog+Extensions.h"

#import "SWSwiftImport.h"

#import <OMSDK_Sellwild/OMIDAdSession.h>
#import <OMSDK_Sellwild/OMIDScriptInjector.h>
#import <OMSDK_Sellwild/OMIDPartner.h>
#import <OMSDK_Sellwild/OMIDSDK.h>

#pragma mark - Constants

static NSString * const SWPBMOpenMeasurementPartnerName   = @"Prebidorg";
static NSString * const SWPBMOpenMeasurementJSLibURL      = @"https://my.server.com/omsdk.js";
static NSString * const SWPBMOpenMeasurementCustomRefId   = @"";

#pragma mark - Private Interface

@interface SWPBMOpenMeasurementWrapper ()

@property (nonatomic, readonly) NSString *partnerName;
@property (nonatomic, readonly) NSString *jsLibURL;
@property (nonatomic, readonly) NSString *customRefId;

@property (nonatomic, strong, nonnull) OMIDPrebidorgPartner *partner;

@property (nonatomic, strong, nullable) PrebidJSLibraryManager *libraryManager;

@end

#pragma mark - Implementation

@implementation SWPBMOpenMeasurementWrapper

#pragma mark - Initialization

+ (instancetype)shared {
    static SWPBMOpenMeasurementWrapper *shared;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[SWPBMOpenMeasurementWrapper alloc] init];
    });
    
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _libraryManager = PrebidJSLibraryManager.shared;
        [self initializeOMSDK];
    }
    
    return self;
}

#pragma mark - Properties

- (NSString *)partnerName {
    return SWPBMOpenMeasurementPartnerName;
}

- (NSString *)jsLibURL {
    return SWPBMOpenMeasurementJSLibURL;
}

- (NSString *)customRefId {
    return SWPBMOpenMeasurementCustomRefId;
}

#pragma mark - SWPBMMeasurementProtocol

- (nullable NSString *)injectJSLib:(NSString *)html error:(NSError **)error {
    if (!html) {
        [SWPBMError createError:error description:@"Empty ad's html"];
        return nil;
    }
    
    NSString *jsLib = [self fetchOMSDKScript];
    
    if (!jsLib) {
        [SWPBMError createError:error description:@"The js lib for Open Measurement is not loaded."];
        return nil;
    }
    
    NSString *res = [OMIDPrebidorgScriptInjector injectScriptContent:jsLib
                                                            intoHTML:html
                                                               error:error];
    
    return res;
}

- (nullable SWPBMOpenMeasurementSession *)initializeWebViewSession:(WKWebView *)webView contentUrl:(NSString *)contentUrl {
    
    NSError *contextError;
    OMIDPrebidorgAdSessionContext *context = [[OMIDPrebidorgAdSessionContext alloc] initWithPartner:self.partner
                                                                                            webView:webView
                                                                                         contentUrl:contentUrl
                                                                          customReferenceIdentifier:self.customRefId
                                                                                              error:&contextError];
    
    if (contextError) {
        SWPBMLogError(@"Unable to create Open Measurement session context with error: %@", [contextError localizedDescription]);
        return nil;
    }
    
    NSError *configurationError;
    
    OMIDPrebidorgAdSessionConfiguration *config = [
        [OMIDPrebidorgAdSessionConfiguration alloc]
        initWithCreativeType:OMIDCreativeTypeHtmlDisplay
        impressionType:OMIDImpressionTypeOnePixel
        impressionOwner:OMIDNativeOwner
        mediaEventsOwner:OMIDNoneOwner
        isolateVerificationScripts:NO
        error:&configurationError];
    
    if (configurationError) {
        SWPBMLogError(@"Unable to create Open Measurement session configuration with error: %@", [configurationError localizedDescription]);
        return nil;
    }
    
    NSError *sessionError;
    SWPBMOpenMeasurementSession *session = [[SWPBMOpenMeasurementSession alloc] initWithContext:context configuration:config];
    if (!session) {
        SWPBMLogError(@"Unable to create Open Measurement session with error: %@", [sessionError localizedDescription]);
        return nil;
    }
    
    [session setupMainView:webView];
    
    return session;
}

- (SWPBMOpenMeasurementSession *)initializeNativeVideoSession:(UIView *)videoView
                                     verificationParameters:(SWPBMVideoVerificationParameters *)verificationParameters {
    
    NSString *jsLib = [self fetchOMSDKScript];
    
    if (!jsLib) {
        SWPBMLogError(@"Open Measurement SDK can't work without valid js script");
        return nil;
    }
    
    NSError *contextError;
    OMIDPrebidorgAdSessionContext *context = [[OMIDPrebidorgAdSessionContext alloc] initWithPartner:self.partner
                                                                                             script:jsLib
                                                                                          resources:[self getScriptResources:verificationParameters]
                                                                                         contentUrl:nil
                                                                          customReferenceIdentifier:nil
                                                                                              error:&contextError];
    if (contextError) {
        SWPBMLogError(@"Unable to create Open Measurement session context with error: %@", [contextError localizedDescription]);
        return nil;
    }
    
    NSError *configurationError;
    
    OMIDPrebidorgAdSessionConfiguration *config = [[OMIDPrebidorgAdSessionConfiguration alloc] initWithCreativeType:OMIDCreativeTypeVideo
                                                                                                     impressionType:OMIDImpressionTypeOnePixel
                                                                                                    impressionOwner:OMIDNativeOwner
                                                                                                   mediaEventsOwner:OMIDNativeOwner
                                                                                         isolateVerificationScripts:NO
                                                                                                              error:&configurationError];
    if (configurationError) {
        SWPBMLogError(@"Unable to create Open Measurement session configuration with error: %@", [configurationError localizedDescription]);
        return nil;
    }
    
    NSError *sessionError;
    SWPBMOpenMeasurementSession *session = [[SWPBMOpenMeasurementSession alloc] initWithContext:context configuration:config];
    if (!session) {
        SWPBMLogError(@"Unable to create Open Measurement session with error: %@", [sessionError localizedDescription]);
        return nil;
    }
    
    [session setupMainView:videoView];
    
    return session;
}

- (SWPBMOpenMeasurementSession *)initializeNativeDisplaySession:(UIView *)view
                                                    omidJSUrl:(NSString *)omidJSUrl
                                                    vendorKey:(NSString *)vendorKey
                                                   parameters:(NSString *)verificationParameters {
    
    NSString *jsLib = [self fetchOMSDKScript];
    
    if (!jsLib) {
        SWPBMLogError(@"Open Measurement SDK can't work without valid js script");
        return nil;
    }
    
    NSArray<OMIDPrebidorgVerificationScriptResource *> *resources = [self scriptResourcesFrom:omidJSUrl
                                                                                    vendorKey:vendorKey
                                                                                   parameters:verificationParameters];
    NSError *contextError;
    OMIDPrebidorgAdSessionContext *context = [[OMIDPrebidorgAdSessionContext alloc] initWithPartner:self.partner
                                                                                             script:jsLib
                                                                                          resources:resources
                                                                                         contentUrl:nil
                                                                          customReferenceIdentifier:nil
                                                                                              error:&contextError];
    if (contextError) {
        SWPBMLogError(@"Unable to create Open Measurement session context with error: %@",
                    [contextError localizedDescription]);
        return nil;
    }
    
    NSError *configurationError;
    
    OMIDPrebidorgAdSessionConfiguration *config = [
        [OMIDPrebidorgAdSessionConfiguration alloc]
        initWithCreativeType:OMIDCreativeTypeNativeDisplay
        impressionType:OMIDImpressionTypeOnePixel
        impressionOwner:OMIDNativeOwner
        mediaEventsOwner:OMIDNoneOwner
        isolateVerificationScripts:NO
        error:&configurationError];
    
    if (configurationError) {
        SWPBMLogError(@"Unable to create Open Measurement session configuration with error: %@",
                    [configurationError localizedDescription]);
        return nil;
    }
    
    NSError *sessionError;
    SWPBMOpenMeasurementSession *session = [[SWPBMOpenMeasurementSession alloc] initWithContext:context configuration:config];
    if (!session) {
        SWPBMLogError(@"Unable to create Open Measurement session with error: %@", [sessionError localizedDescription]);
        return nil;
    }
    
    [session setupMainView:view];
    
    return session;
}


#pragma mark - Internal Methods

- (void)initializeOMSDK {
    NSError *error;
    BOOL sdkStarted = [[OMIDPrebidorgSDK sharedInstance] activate];
    
    if (!sdkStarted) {
        SWPBMLogError(@"Prebid SDK can't initialize Open Measurement SDK with error: %@", [error localizedDescription]);
    }
    
    self.partner = [[OMIDPrebidorgPartner alloc] initWithName:self.partnerName
                                                versionString:[SWPBMFunctions sdkVersion]];
}

-(nullable NSString*)fetchOMSDKScript {
    return [self.libraryManager getOMSDKLibrary];;
}

- (nonnull NSArray<OMIDPrebidorgVerificationScriptResource *> *)getScriptResources:(SWPBMVideoVerificationParameters *)vastVerificationParamaters {
    NSMutableArray *scripts = [NSMutableArray new];
    
    for (SWPBMVideoVerificationResource *vastResource in vastVerificationParamaters.verificationResources) {
        if (!(vastResource.url && vastResource.vendorKey && vastResource.params)) {
            SWPBMLogError(@"Invalid Verification Resource. All properties should be provided. Url: %@, vendorKey: %@, params: %@", vastResource.url, vastResource.vendorKey, vastResource.params);
            continue;
        }
        
        NSURL *url = [[NSURL alloc] initWithString:vastResource.url];
        if (!url) {
            SWPBMLogError(@"The URL for OM Verification Resource is invalid. Url: %@", vastResource.url);
            continue;
        }
        
        OMIDPrebidorgVerificationScriptResource *resource = [[OMIDPrebidorgVerificationScriptResource alloc] initWithURL:url
                                                                                                               vendorKey:vastResource.vendorKey
                                                                                                              parameters:vastResource.params];
        
        if (!resource) {
            SWPBMLogError(@"Can't create OM Verification Resource. Url: %@, vendorKey: %@, params: %@", vastResource.url, vastResource.vendorKey, vastResource.params);
            continue;
        }
        
        [scripts addObject:resource];
    }
    
    return scripts;
}

- (nonnull NSArray<OMIDPrebidorgVerificationScriptResource *> *)scriptResourcesFrom:(NSString *)omidJSUrl
                                                                          vendorKey:(NSString *)vendorKey
                                                                         parameters:(NSString *)parameters {
    
    if (!omidJSUrl || !vendorKey || !parameters) {
        SWPBMLogError(@"Invalid Verification Resource. All properties should be provided. Url: %@, vendorKey: %@, params: %@",
                    omidJSUrl, vendorKey, parameters);
        return @[];
    }
    
    NSURL *url = [[NSURL alloc] initWithString:omidJSUrl];
    if (!url) {
        SWPBMLogError(@"The URL for OM Verification Resource is invalid. Url: %@", omidJSUrl);
        return @[];
    }
    
    OMIDPrebidorgVerificationScriptResource *resource = [[OMIDPrebidorgVerificationScriptResource alloc] initWithURL:url
                                                                                                           vendorKey:vendorKey
                                                                                                          parameters:parameters];
    
    if (!resource) {
        SWPBMLogError(@"Can't create OM Verification Resource. Url: %@, vendorKey: %@, params: %@",
                    omidJSUrl, vendorKey, parameters);
        return @[];
    }
    
    return  @[resource];
}

@end
