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

#import "SWPBMORTBUser.h"
#import "SWPBMORTBAbstract+Protected.h"

#import "SWPBMORTBGeo.h"

#import "SWSwiftImport.h"

@implementation SWPBMORTBUser

- (instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    _geo = [[SWPBMORTBGeo alloc] init];
    _ext = [[NSMutableDictionary<NSString *, NSObject *> alloc] init];
    
    return self;
}

- (nonnull SWPBMJsonDictionary *)toJsonDictionary {
    SWPBMMutableJsonDictionary *ret = [[SWPBMMutableJsonDictionary alloc] init];
    
    ret[@"keywords"] = self.keywords;
    ret[@"customdata"] = self.customdata;
    ret[@"id"] = self.userid;
    
    if (self.geo.lat && self.geo.lon) {
        ret[@"geo"] = [self.geo toJsonDictionary];
    }
    
    if(self.data) {
        NSMutableArray<SWPBMJsonDictionary *> *dataArray = [NSMutableArray<SWPBMJsonDictionary *> new];
        for (SWPBMORTBContentData *dataObject in self.data) {
            [dataArray addObject:[dataObject toJsonDictionary]];
        }
        
        ret[@"data"] = dataArray;
    }

    if (self.ext && self.ext.count) {
        ret[@"ext"] = self.ext;
    }
    
    ret = [ret swpbmCopyWithoutEmptyVals];
    
    return ret;
}

- (instancetype)initWithJsonDictionary:(nonnull SWPBMJsonDictionary *)jsonDictionary {
    if (!(self = [self init])) {
        return nil;
    }
    
    _keywords    = jsonDictionary[@"keywords"];
    _customdata  = jsonDictionary[@"customdata"];
    _ext         = jsonDictionary[@"ext"];
    _userid      = jsonDictionary[@"id"];
        
    _geo = [[SWPBMORTBGeo alloc] initWithJsonDictionary:jsonDictionary[@"geo"]];
    
    NSMutableArray<SWPBMORTBContentData *> *dataArray = [NSMutableArray<SWPBMORTBContentData *> new];
    NSMutableArray<SWPBMJsonDictionary *> *dataDicts = jsonDictionary[@"data"];
    if (dataDicts.count > 0) {
        for (SWPBMJsonDictionary *dataDict in dataDicts) {
            if (dataDict && [dataDict isKindOfClass:[NSDictionary class]])
                [dataArray addObject:[[SWPBMORTBContentData alloc] initWithJsonDictionary:dataDict]];
        }
        
        _data = dataArray;
    }
    
    return self;
}

- (void)appendEids:(NSArray<NSDictionary<NSString *, id> *> *)eids {
    
    if (!self.ext[@"eids"]) {
        self.ext[@"eids"] = eids;
    } else {
        NSArray *currentEids = (NSArray<NSDictionary<NSString *, id> *> *)self.ext[@"eids"];
        
        self.ext[@"eids"] = [currentEids arrayByAddingObjectsFromArray:eids];
    }
}


@end
