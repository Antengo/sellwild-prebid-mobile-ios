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

#import "SWPBMORTBDeviceExtPrebid.h"
#import "SWPBMORTBAbstract+Protected.h"

#import "SWPBMORTBDeviceExtPrebidInterstitial.h"

@implementation SWPBMORTBDeviceExtPrebid

- (instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    _interstitial = [[SWPBMORTBDeviceExtPrebidInterstitial alloc] init];
    return self;
}

- (nonnull SWPBMJsonDictionary *)toJsonDictionary {
    SWPBMMutableJsonDictionary *ret = [SWPBMMutableJsonDictionary new];
    
    ret[@"interstitial"] = [[self.interstitial toJsonDictionary] nullIfEmpty];
    [ret swpbmRemoveEmptyVals];
    
    return ret;
}

- (instancetype)initWithJsonDictionary:(nonnull SWPBMJsonDictionary *)jsonDictionary {
    if (!(self = [self init])) {
        return nil;
    }
    _interstitial = [[SWPBMORTBDeviceExtPrebidInterstitial alloc] initWithJsonDictionary:jsonDictionary[@"interstitial"]];
    return self;
}

@end
