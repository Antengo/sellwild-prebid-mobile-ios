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

#import "SWPBMORTBImpExtSkadn.h"
#import "SWPBMORTBAbstract+Protected.h"

#import "SWPBMFunctions.h"

@implementation SWPBMORTBImpExtSkadn

- (instancetype )init {
    if (self = [super init]) {
        _skadnetids = @[];
    }
    return self;
}

- (nonnull SWPBMJsonDictionary *)toJsonDictionary {
    SWPBMMutableJsonDictionary * const ret = [SWPBMMutableJsonDictionary new];
    
    if (self.sourceapp && self.skadnetids.count > 0) {
        ret[@"versions"] = SWPBMFunctions.supportedSKAdNetworkVersions;
        ret[@"sourceapp"] = self.sourceapp;
        ret[@"skadnetids"] = self.skadnetids;
        ret[@"skoverlay"] = self.skoverlay;
    }
    
    [ret swpbmRemoveEmptyVals];
    return ret;
}

- (instancetype)initWithJsonDictionary:(nonnull SWPBMJsonDictionary *)jsonDictionary {
    if (self = [self init]) {
        _sourceapp = jsonDictionary[@"sourceapp"];
        _skadnetids = jsonDictionary[@"skadnetids"];
        _skoverlay = jsonDictionary[@"skoverlay"];
    }

    return self;
}
@end
