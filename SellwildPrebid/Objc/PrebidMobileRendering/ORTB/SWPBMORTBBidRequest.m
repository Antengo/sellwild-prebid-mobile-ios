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

#import "SWPBMORTBBidRequest.h"
#import "SWPBMORTBAbstract+Protected.h"

#import "SWPBMORTBApp.h"
#import "SWPBMORTBBidRequestExtPrebid.h"
#import "SWPBMORTBDevice.h"
#import "SWPBMORTBImp.h"
#import "SWPBMORTBRegs.h"
#import "SWPBMORTBSource.h"
#import "SWPBMORTBUser.h"

@implementation SWPBMORTBBidRequest

- (nonnull instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    //_requestID = nil;
    _imp = @[[SWPBMORTBImp new]];
    _app = [SWPBMORTBApp new];
    _device = [SWPBMORTBDevice new];
    _user = [SWPBMORTBUser new];
    _regs = [SWPBMORTBRegs new];
    _source = [SWPBMORTBSource new];
    _extPrebid = [SWPBMORTBBidRequestExtPrebid new];
    
    return self;
}
- (void)setImp:(NSArray<SWPBMORTBImp *> *)imp {
    _imp = imp ? [NSArray arrayWithArray:imp] : @[];
}

- (nonnull SWPBMJsonDictionary *)toJsonDictionary {
    SWPBMMutableJsonDictionary *ret = [SWPBMMutableJsonDictionary new];
    
    NSMutableArray<SWPBMJsonDictionary *> *impressions = [NSMutableArray<SWPBMJsonDictionary *> new];
    for (SWPBMORTBImp *imp in self.imp) {
        [impressions addObject:[imp toJsonDictionary]];
    }
    //set impressions and ext beforehand so they are not overridden by arbitrary params from API/JSON
    ret[@"imp"] = impressions;
    SWPBMMutableJsonDictionary * const ext = [SWPBMMutableJsonDictionary new];
    ext[@"prebid"] = [[self.extPrebid toJsonDictionary] nullIfEmpty];
    ret[@"ext"] = [[ext swpbmCopyWithoutEmptyVals] nullIfEmpty];
    
    ret[@"id"] = self.requestID;
    
    ret[@"app"] = [[self.app toJsonDictionary] nullIfEmpty];
    ret[@"device"] = [[self.device toJsonDictionary] nullIfEmpty];
    ret[@"user"] = [[self.user toJsonDictionary] nullIfEmpty];
    ret[@"test"] = self.test;
    ret[@"tmax"] = self.tmax;
    ret[@"regs"] = [[self.regs toJsonDictionary] nullIfEmpty];
    ret[@"source"] = [[self.source toJsonDictionary] nullIfEmpty];
    
    ret = [ret swpbmCopyWithoutEmptyVals];
    
    return ret;
}

- (instancetype)initWithJsonDictionary:(nonnull SWPBMJsonDictionary *)jsonDictionary {
    if (!(self = [self init])) {
        return nil;
    }
    
    _requestID = jsonDictionary[@"id"];
    
    NSMutableArray<SWPBMORTBImp *> *impressions = [NSMutableArray<SWPBMORTBImp *> new];
    NSMutableArray<SWPBMJsonDictionary *> *impressionsData = jsonDictionary[@"imp"];
    for (SWPBMJsonDictionary *impressionData in impressionsData) {
        if (impressionData && [impressionData isKindOfClass:[NSDictionary class]])
            [impressions addObject:[[SWPBMORTBImp alloc] initWithJsonDictionary:impressionData]];
    }
    
    _imp = impressions;
    
    _app = [[SWPBMORTBApp alloc] initWithJsonDictionary:jsonDictionary[@"app"]];
    _device = [[SWPBMORTBDevice alloc] initWithJsonDictionary:jsonDictionary[@"device"]];
    _user = [[SWPBMORTBUser alloc] initWithJsonDictionary:jsonDictionary[@"user"]];
    _test = jsonDictionary[@"test"];
    _tmax = jsonDictionary[@"tmax"];
    _regs = [[SWPBMORTBRegs alloc] initWithJsonDictionary:jsonDictionary[@"regs"]];
    _source = [[SWPBMORTBSource alloc] initWithJsonDictionary:jsonDictionary[@"source"]];
    _extPrebid = [[SWPBMORTBBidRequestExtPrebid alloc] initWithJsonDictionary:jsonDictionary[@"ext"][@"prebid"] ?: @{}];
    
    return self;
}

@end
