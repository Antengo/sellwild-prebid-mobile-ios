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
#import <UIKit/UIKit.h>

#import "SWPBMFunctions.h"
#import "SWPBMConstants.h"
#import "SWPBMUIApplicationProtocol.h"

@interface SWPBMFunctions ()

#pragma mark - URLs

+ (void) attemptToOpen:(nonnull NSURL*)url;
+ (void) attemptToOpen:(nonnull NSURL*)url swpbmUIApplication:(nonnull id<SWPBMUIApplicationProtocol>)swpbmUIApplication;

#pragma mark - Time

+ (NSTimeInterval)clamp:(NSTimeInterval)value
             lowerBound:(NSTimeInterval)lowerBound
             upperBound:(NSTimeInterval)upperBound;

// Used only in tests
+ (NSInteger)clampInt:(NSInteger)value
             lowerBound:(NSInteger)lowerBound
             upperBound:(NSInteger)upperBound;

+ (NSTimeInterval)clampAutoRefresh:(NSTimeInterval)val;
+ (dispatch_time_t)dispatchTimeAfterTimeInterval:(NSTimeInterval)timeInterval;
+ (dispatch_time_t)dispatchTimeAfterTimeInterval:(NSTimeInterval)timeInterval startTime:(dispatch_time_t)startTime; // Currently is used in tests only to check the algorithm for porting from Swift to Objective-C

#pragma mark - JSON

+ (nullable SWPBMJsonDictionary *)dictionaryFromJSONString:(nonnull NSString *)jsonString error:(NSError* _Nullable __autoreleasing * _Nullable)error
    NS_SWIFT_NAME(dictionaryFromJSONString(_:));

+ (nullable SWPBMJsonDictionary *)dictionaryFromData:(nonnull NSData *)jsonData error:(NSError* _Nullable __autoreleasing * _Nullable)error
    NS_SWIFT_NAME(dictionaryFromData(_:));

+ (nullable NSString *)toStringJsonDictionary:(nonnull SWPBMJsonDictionary *)jsonDictionary error:(NSError* _Nullable __autoreleasing * _Nullable)error;

#pragma mark - SDK Info

+ (nonnull NSBundle *)bundleForSDK;

+ (nullable NSString *)infoPlistValueFor:(nonnull NSString *)key
    NS_SWIFT_NAME(infoPlistValue(_:));

#pragma mark - UI

+ (CGFloat)statusBarHeight;
+ (CGFloat)statusBarHeightForApplication:(nonnull id<SWPBMUIApplicationProtocol>)application
    NS_SWIFT_NAME(statusBarHeight(application:));

#pragma mark - Device Info

// from the SWPBMDeviceManager
//TODO: move these to SWPBMDeviceManager
+ (CGSize)deviceScreenSize;
+ (CGSize)deviceMaxSize;
+ (UIEdgeInsets)safeAreaInsets;
+ (BOOL)isSimulator;

@end
