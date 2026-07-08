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

#import "SWPBMORTBPmp.h"
#import "SWPBMORTBAbstract+Protected.h"

#import "SWPBMORTBDeal.h"

@implementation SWPBMORTBPmp

- (nonnull instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    _deals = @[];
    
    return self;
}

- (void)setDeals:(NSArray<SWPBMORTBDeal *> *)deals {
    _deals = deals ? [NSArray arrayWithArray:deals] : @[];
}

- (nonnull SWPBMJsonDictionary *)toJsonDictionary {
    SWPBMMutableJsonDictionary *ret = [SWPBMMutableJsonDictionary new];
    
    ret[@"private_auction"] = self.private_auction;
    
    NSMutableArray<SWPBMJsonDictionary *> *deals = [NSMutableArray<SWPBMJsonDictionary *> new];
    for (SWPBMORTBDeal *deal in self.deals) {
        [deals addObject:[deal toJsonDictionary]];
    }
    if (deals.count > 0) {
        ret[@"deals"] = deals;
    }
    
    ret = [ret swpbmCopyWithoutEmptyVals];
    
    return ret;
}

- (instancetype)initWithJsonDictionary:(nonnull SWPBMJsonDictionary *)jsonDictionary {
    if (!(self = [self init])) {
        return nil;
    }
    _private_auction = jsonDictionary[@"private_auction"];
    
    NSMutableArray<SWPBMORTBDeal *> *deals = [NSMutableArray<SWPBMORTBDeal *> new];

    NSArray *dealsData = jsonDictionary[@"deals"];
    for (SWPBMJsonDictionary *dealData in dealsData) {
        if (dealData && [dealData isKindOfClass:[NSDictionary class]]) {
            [deals addObject:[[SWPBMORTBDeal alloc] initWithJsonDictionary:dealData]];
        }
    }
    
    _deals = deals;
    
    return self;
}

@end
