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

#import <Foundation/Foundation.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

#import "SWSwiftImport.h"

@protocol SWPBMBundleProtocol;
@protocol SWPBMParameterBuilder;

@class SWPBTargeting;
@class SWPBMAdConfiguration;
@class SWPBMDeviceAccessManager;
@class SWPBMLocationManager;
@class SellwildPrebid;
@class SWPBMArbitraryORTBParameterBuilder;
@class SWPBMLocationManager;

@interface SWPBMParameterBuilderService : NSObject

//API Version
+ (nonnull NSDictionary<NSString* , NSString *> *)buildParamsDictWithAdConfiguration:(nonnull SWPBMAdConfiguration *)adConfiguration;

+ (nonnull NSDictionary<NSString* , NSString *> *)buildParamsDictWithAdConfiguration:(nonnull SWPBMAdConfiguration *)adConfiguration
                                                              extraParameterBuilders:(nullable NSArray<id<SWPBMParameterBuilder> > *)extraParameterBuilders;

//DI Version
+ (nonnull NSDictionary<NSString* , NSString *> *)buildParamsDictWithAdConfiguration:(nonnull SWPBMAdConfiguration *)adConfiguration
                                                                              bundle:(nonnull id<SWPBMBundleProtocol>)bundle
                                                                  swpbmLocationManager:(nonnull SWPBMLocationManager *)swpbmLocationManager
                                                              swpbmDeviceAccessManager:(nonnull SWPBMDeviceAccessManager *)swpbmDeviceAccessManager
                                                              ctTelephonyNetworkInfo:(nonnull CTTelephonyNetworkInfo *)ctTelephonyNetworkInfo
                                                                        reachability:(nonnull SWPBMReachability *)reachability
                                                                    sdkConfiguration:(nonnull SellwildPrebid *)sdkConfiguration
                                                                          sdkVersion:(nonnull NSString *)sdkVersion
                                                                           targeting:(nonnull SWPBTargeting *)targeting
                                                              extraParameterBuilders:(nullable NSArray<id<SWPBMParameterBuilder> > *)extraParameterBuilders;
@end
