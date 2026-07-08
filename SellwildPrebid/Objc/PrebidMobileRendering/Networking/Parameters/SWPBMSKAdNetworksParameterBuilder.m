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

#import "SWPBMMacros.h"
#import "SWPBMORTB.h"

#import "SWPBMSKAdNetworksParameterBuilder.h"
#import "SWLog+Extensions.h"

#import "SWSwiftImport.h"

#pragma mark - Internal Extension
@interface SWPBMSKAdNetworksParameterBuilder()

//Keys into Bundle info Dict
@property (nonatomic, class, readonly) NSString *SKAdNetworkItemsKey;
@property (nonatomic, class, readonly) NSString *SKAdNetworkIdentifierKey;

@property (nonatomic, strong, readonly) id<SWPBMBundleProtocol> bundle;
@property (nonatomic, strong, readonly) Targeting *targeting;
@property (nonatomic, strong, readwrite) SWPBMAdConfiguration *adConfiguration;

@end

#pragma mark - Implementation

@implementation SWPBMSKAdNetworksParameterBuilder

#pragma mark - Properties

//Keys into Bundle info Dict
+ (NSString *)SKAdNetworkItemsKey {
    return @"SKAdNetworkItems";
}

+ (NSString *)SKAdNetworkIdentifierKey {
    return @"SKAdNetworkIdentifier";
}

#pragma mark - Initialization

- (nonnull instancetype)initWithBundle:(id<SWPBMBundleProtocol>)bundle
                             targeting:(Targeting *)targeting
                       adConfiguration:(SWPBMAdConfiguration *)adConfiguration {
    if (!(self = [super init])) {
        return nil;
    }
    SWPBMAssert(bundle && targeting);
    _bundle = bundle;
    _targeting = targeting;
    _adConfiguration = adConfiguration;
    
    return self;
}

#pragma mark - SWPBMParameterBuilder

- (void)buildBidRequest:(SWPBMORTBBidRequest *)bidRequest {   
    if (!(self.bundle && bidRequest)) {
        SWPBMLogError(@"Invalid properties");
        return;
    }
    
    NSArray<NSString *> *skadnetids = [self SKAdNetworkIds];
    if (!skadnetids) {
        return;
    }
    
    NSString *sourceapp = self.targeting.sourceapp;
    if (!sourceapp) {
        SWPBMLogError(@"Info.plist contains SKAdNetwork but sourceapp is nil!");
    }
    
    for (SWPBMORTBImp *imp in bidRequest.imp) {
        imp.extSkadn.sourceapp = [sourceapp copy];
        imp.extSkadn.skadnetids = skadnetids;

        BOOL supportSKOverlay = self.adConfiguration.supportSKOverlay;
        if (supportSKOverlay) {
            imp.extSkadn.skoverlay = @1;
        }
    }
}

/**
 Returns an array of SKAdNetwork ids or nil
 */
- (NSArray<NSString *> *)SKAdNetworkIds {
    if (@available(iOS 14.0, *)) {
        NSDictionary* infoDict = self.bundle.infoDictionary;
        NSArray* skadNetworks = infoDict[SWPBMSKAdNetworksParameterBuilder.SKAdNetworkItemsKey];
        if (skadNetworks) {
            NSMutableArray<NSString *> *networkIds = [NSMutableArray<NSString *> arrayWithCapacity:skadNetworks.count];
            [skadNetworks enumerateObjectsUsingBlock:^(NSDictionary *itemDict, NSUInteger idx, BOOL *stop) {
                [networkIds addObject:itemDict[SWPBMSKAdNetworksParameterBuilder.SKAdNetworkIdentifierKey]];
            }];
            return [networkIds copy];
        }
    }
    return nil;
}

@end
