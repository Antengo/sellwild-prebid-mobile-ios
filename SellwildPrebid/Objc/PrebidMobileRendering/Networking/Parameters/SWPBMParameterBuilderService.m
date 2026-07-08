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

#import <MapKit/MapKit.h>

#import "SWPBMAppInfoParameterBuilder.h"
#import "SWPBMBasicParameterBuilder.h"
#import "SWPBMDeviceInfoParameterBuilder.h"
#import "SWPBMFunctions.h"
#import "SWPBMGeoLocationParameterBuilder.h"
#import "SWPBMNetworkParameterBuilder.h"
#import "SWPBMORTBParameterBuilder.h"
#import "SWPBMParameterBuilderProtocol.h"
#import "SWPBMSKAdNetworksParameterBuilder.h"
#import "SWPBMUserConsentParameterBuilder.h"
#import "SWPBMORTB.h"

#import "SWPBMParameterBuilderService.h"

#import "SWSwiftImport.h"

@implementation SWPBMParameterBuilderService

+ (nonnull NSDictionary<NSString* , NSString *> *)buildParamsDictWithAdConfiguration:(nonnull SWPBMAdConfiguration *)adConfiguration {
    return [self buildParamsDictWithAdConfiguration:adConfiguration extraParameterBuilders:nil];
}

+ (nonnull NSDictionary<NSString* , NSString *> *)buildParamsDictWithAdConfiguration:(nonnull SWPBMAdConfiguration *)adConfiguration extraParameterBuilders:(nullable NSArray<id<SWPBMParameterBuilder> > *)extraParameterBuilders {
    return [self buildParamsDictWithAdConfiguration:adConfiguration
                                             bundle:NSBundle.mainBundle
                                 swpbmLocationManager:SWPBMLocationManager.shared
                             swpbmDeviceAccessManager:[[SWPBMDeviceAccessManager alloc] initWithRootViewController: nil]
                             ctTelephonyNetworkInfo:[CTTelephonyNetworkInfo new]
                                       reachability:SWPBMReachability.shared
                                   sdkConfiguration:SellwildPrebid.shared
                                         sdkVersion:[SWPBMFunctions sdkVersion]
                                          targeting:Targeting.shared
                             extraParameterBuilders:extraParameterBuilders];
}

// Input parameters validation: certain parameter will be validated in particular builder.
// In such case, even if some parameter is invalid all other builders will work.
+ (nonnull NSDictionary<NSString* , NSString *> *)buildParamsDictWithAdConfiguration:(nonnull SWPBMAdConfiguration *)adConfiguration
                                                                              bundle:(nonnull id<SWPBMBundleProtocol>)bundle
                                                                  swpbmLocationManager:(nonnull SWPBMLocationManager *)swpbmLocationManager
                                                              swpbmDeviceAccessManager:(nonnull SWPBMDeviceAccessManager *)swpbmDeviceAccessManager
                                                              ctTelephonyNetworkInfo:(nonnull CTTelephonyNetworkInfo *)ctTelephonyNetworkInfo
                                                                        reachability:(nonnull SWPBMReachability *)reachability
                                                                    sdkConfiguration:(nonnull SellwildPrebid *)sdkConfiguration
                                                                          sdkVersion:(nonnull NSString *)sdkVersion
                                                                           targeting:(nonnull Targeting *)targeting
                                                              extraParameterBuilders:(nullable NSArray<id<SWPBMParameterBuilder> > *)extraParameterBuilders{
  
    SWPBMORTBBidRequest *bidRequest = [SWPBMParameterBuilderService createORTBBidRequestWithTargeting:targeting];
    NSMutableArray<id<SWPBMParameterBuilder> > * const parameterBuilders = [[NSMutableArray alloc] init];
    [parameterBuilders addObjectsFromArray:@[
        [[SWPBMBasicParameterBuilder alloc] initWithAdConfiguration:adConfiguration
                                                 sdkConfiguration:sdkConfiguration
                                                       sdkVersion:sdkVersion
                                                        targeting:targeting],
        [[SWPBMGeoLocationParameterBuilder alloc] initWithLocationManager:swpbmLocationManager],
        [[SWPBMAppInfoParameterBuilder alloc] initWithBundle:bundle targeting:targeting],
        [[SWPBMDeviceInfoParameterBuilder alloc] initWithDeviceAccessManager:swpbmDeviceAccessManager],
        [[SWPBMNetworkParameterBuilder alloc] initWithCtTelephonyNetworkInfo:ctTelephonyNetworkInfo
                                                              reachability:reachability],
        [[SWPBMUserConsentParameterBuilder alloc] init],
        [[SWPBMSKAdNetworksParameterBuilder alloc] initWithBundle:bundle
                                                      targeting:targeting
                                                adConfiguration:adConfiguration],
    ]];
    
    if (extraParameterBuilders) {
        [parameterBuilders addObjectsFromArray:extraParameterBuilders];
    }
   
    for (id<SWPBMParameterBuilder> builder in parameterBuilders) {
        [builder buildBidRequest:bidRequest];
    }
    
    NSDictionary *ortb = [bidRequest toJsonDictionary];
    
    NSDictionary * arbitratyORTB = [SWPBMArbitraryORTBService mergeWithSdkORTB:ortb
                                                                     impORTB:adConfiguration.impORTBConfig
                                                            globalAdUnitORTB:adConfiguration.globalORTBConfig
                                                                  globalORTB:[targeting getGlobalORTBConfig]];
    
    return [SWPBMORTBParameterBuilder buildOpenRTBFor:arbitratyORTB];
}

+ (nonnull SWPBMORTBBidRequest *)createORTBBidRequestWithTargeting:(nonnull Targeting *)targeting {
    SWPBMORTBBidRequest *bidRequest = [SWPBMORTBBidRequest new];
   
    if (targeting.userExt) {
        NSMutableDictionary *existingUserExt = bidRequest.user.ext ?: [NSMutableDictionary dictionary];
        [existingUserExt addEntriesFromDictionary:targeting.userExt];
        bidRequest.user.ext = existingUserExt;
    }
    
    if ([targeting getExternalUserIds]) {
        [bidRequest.user appendEids:[targeting getExternalUserIds]];
    }
    
    if (targeting.sendSharedId) {
        __auto_type sharedId = targeting.sharedId;
        if (sharedId) {
            [bidRequest.user appendEids:@[[sharedId toJSONDictionary]]];
        }
    }
    
    if ([targeting getUserKeywords].count > 0) {
        bidRequest.user.keywords = [[targeting getUserKeywords] componentsJoinedByString:@","];
    }
    
    bidRequest.app.storeurl = targeting.storeURL;
    bidRequest.app.domain = targeting.domain;
    bidRequest.app.bundle = targeting.itunesID;
    
    if ([targeting getAppKeywords].count > 0) {
        bidRequest.app.keywords = [[targeting getAppKeywords] componentsJoinedByString:@","];
    }
    
    if (targeting.publisherName) {
        if (!bidRequest.app.publisher) {
            bidRequest.app.publisher = [[SWPBMORTBPublisher alloc] init];
        }
        
        bidRequest.app.publisher.name = targeting.publisherName;
    }
        
    NSValue * const coordObj = targeting.coordinate;
    if (coordObj) {
        // Rounds with the precision defined in Targeting, or returns the original coordinates if precision is nil.
        const CLLocationCoordinate2D coord2d = [[Utils shared] roundWithCoordinates:coordObj.MKCoordinateValue precision:[[Targeting shared] locationPrecision]];;
        
        bidRequest.user.geo.lat = @(coord2d.latitude);
        bidRequest.user.geo.lon = @(coord2d.longitude);
    }
    
    return bidRequest;
}

@end
