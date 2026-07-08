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

#import "SWPBMORTBAppExtPrebid.h"
#import "SWPBMORTBAppExt.h"
#import "SWPBMORTBAbstract+Protected.h"

@implementation SWPBMORTBAppExt

- (nonnull instancetype )init {
    if (!(self = [super init])) {
        return nil;
    }

    _prebid = [[SWPBMORTBAppExtPrebid alloc] init];
    
    return self;
}

- (nonnull SWPBMJsonDictionary *)toJsonDictionary {
    SWPBMMutableJsonDictionary *ret = [SWPBMMutableJsonDictionary new];
    SWPBMJsonDictionary * const extPrebidDic = [self.prebid toJsonDictionary];
    if (extPrebidDic.count) {
        ret[@"prebid"] = extPrebidDic;
    }
    
    ret[@"data"] = self.data;
    return ret;
}

- (instancetype)initWithJsonDictionary:(nonnull SWPBMJsonDictionary *)jsonDictionary {
    if (!(self = [self init])) {
        return nil;
    }
    _data = jsonDictionary[@"data"];
    _prebid = [[SWPBMORTBAppExtPrebid alloc] initWithJsonDictionary:jsonDictionary[@"prebid"]];
    return self;
}


@end
