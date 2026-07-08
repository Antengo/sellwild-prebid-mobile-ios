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

#import "SWPBMORTBBanner.h"
#import "SWPBMORTBAbstract+Protected.h"

#import "SWPBMORTBFormat.h"

@implementation SWPBMORTBBanner

- (nonnull instancetype)init {
    if(!(self = [super init])) {
        return nil;
    }
    _format = @[];
    return self;
}

- (void)setFormat:(NSArray<SWPBMORTBFormat *> *)format {
    _format = format ? [NSArray arrayWithArray:format] : @[];
}

- (void)setApi:(NSArray<NSNumber *> *)api {
    _api = api ? [NSArray arrayWithArray:api] : nil;
}

- (nonnull SWPBMJsonDictionary *)toJsonDictionary {
    SWPBMMutableJsonDictionary *ret = [SWPBMMutableJsonDictionary new];
    
    ret[@"pos"] = self.pos;
    
    if (self.api.count > 0) {
        ret[@"api"] = self.api;
    }
    
    if (self.format.count > 0) {
        NSMutableArray<SWPBMJsonDictionary *> * const formatsArr = [[NSMutableArray alloc] initWithCapacity:self.format.count];
        for(SWPBMORTBFormat *nextFormat in self.format) {
            [formatsArr addObject:[nextFormat toJsonDictionary]];
        }
        ret[@"format"] = formatsArr;
    }
    
    ret = [ret swpbmCopyWithoutEmptyVals];
    
    return ret;
}

- (instancetype)initWithJsonDictionary:(nonnull SWPBMJsonDictionary *)jsonDictionary {
    if(!(self = [super init])) {
        return nil;
    }
    _pos = jsonDictionary[@"pos"];
    _api = jsonDictionary[@"api"];
    
    NSArray<SWPBMJsonDictionary *> * const formatsArr = jsonDictionary[@"format"];
    if (formatsArr) {
        NSMutableArray<SWPBMORTBFormat *> * const newFormat = [[NSMutableArray alloc] initWithCapacity:formatsArr.count];
        for(SWPBMJsonDictionary *nextFormatDic in jsonDictionary[@"format"]) {
            [newFormat addObject:[[SWPBMORTBFormat alloc] initWithJsonDictionary:nextFormatDic]];
        }
        _format = newFormat;
    } else {
        _format = @[];
    }
    
    return self;
}

@end
