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

#import "SWPBMORTBImp.h"
#import "SWPBMORTBAbstract+Protected.h"

#import "SWPBMORTBBanner.h"
#import "SWPBMORTBImpExtPrebid.h"
#import "SWPBMORTBImpExtSkadn.h"
#import "SWPBMORTBPmp.h"
#import "SWPBMORTBVideo.h"

#import "SWSwiftImport.h"

@implementation SWPBMORTBImp

- (nonnull instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    //_impID = nil;
    _pmp = [SWPBMORTBPmp new];
    _instl = @0;
    _clickbrowser = @1; // native
    _secure = @0;
    _extPrebid = [[SWPBMORTBImpExtPrebid alloc] init];
    _extSkadn = [SWPBMORTBImpExtSkadn new];
    _extData = [NSMutableDictionary<NSString *, id> new];
    
    return self;
}

- (nonnull SWPBMJsonDictionary *)toJsonDictionary {
    SWPBMMutableJsonDictionary *ret = [SWPBMMutableJsonDictionary new];
    
    ret[@"id"] = self.impID;
    ret[@"banner"] = [[self.banner toJsonDictionary] nullIfEmpty];
    ret[@"video"] = [[self.video toJsonDictionary] nullIfEmpty];
    ret[@"native"] = [[self.native toJsonDictionary] nullIfEmpty];
    ret[@"pmp"] = [[self.pmp toJsonDictionary] nullIfEmpty];
    ret[@"displaymanager"] = self.displaymanager;
    ret[@"displaymanagerver"] = self.displaymanagerver;
    ret[@"instl"] = self.instl;
    ret[@"tagid"] = self.tagid;
    ret[@"clickbrowser"] = self.clickbrowser;
    ret[@"secure"] = self.secure;
    ret[@"rwdd"] = self.rewarded;
    
    ret[@"ext"] = [[self extDictionary] nullIfEmpty];
    
    ret = [ret swpbmCopyWithoutEmptyVals];
    
    return ret;
}

- (instancetype)initWithJsonDictionary:(nonnull SWPBMJsonDictionary *)jsonDictionary {
    if (!(self = [self init])) {
        return nil;
    }
    _impID = jsonDictionary[@"id"];
    
    id bannerData = jsonDictionary[@"banner"];
    if (bannerData && [bannerData isKindOfClass:[NSDictionary class]]) {
        self.banner = [[SWPBMORTBBanner alloc] initWithJsonDictionary:bannerData];
    }
    
    id videoData = jsonDictionary[@"video"];
    if (videoData && [videoData isKindOfClass:[NSDictionary class]]) {
        self.video = [[SWPBMORTBVideo alloc] initWithJsonDictionary:videoData];
    }
    id nativeData = jsonDictionary[@"native"];
    if (nativeData && [nativeData isKindOfClass:[NSDictionary class]]) {
        self.native = [[SWPBMORTBNative alloc] initWithJsonDictionary:nativeData];
    }
    
    _pmp = [[SWPBMORTBPmp alloc] initWithJsonDictionary:jsonDictionary[@"pmp"]];
    
    _displaymanager = jsonDictionary[@"displaymanager"];
    _displaymanagerver = jsonDictionary[@"displaymanagerver"];
    _instl = jsonDictionary[@"instl"];
    _tagid = jsonDictionary[@"tagid"];
    _clickbrowser = jsonDictionary[@"clickbrowser"];
    _secure = jsonDictionary[@"secure"];
    _rewarded = jsonDictionary[@"rwdd"];
    
    _extPrebid = [[SWPBMORTBImpExtPrebid alloc] initWithJsonDictionary:jsonDictionary[@"ext"][@"prebid"]];
    _extSkadn = [[SWPBMORTBImpExtSkadn alloc] initWithJsonDictionary:jsonDictionary[@"ext"][@"skadn"]];
    
    _extData = jsonDictionary[@"ext"][@"data"];
    _extKeywords = jsonDictionary[@"ext"][@"keywords"];
    _extGPID = jsonDictionary[@"ext"][@"gpid"];
    
    return self;
}

- (nonnull SWPBMJsonDictionary *)extDictionary {
    SWPBMMutableJsonDictionary *ret = [SWPBMMutableJsonDictionary new];
    
    // FIXME: (PB-X) Check the necessity of branching the logic with server devs
    id extPrebidObj = [[self.extPrebid toJsonDictionary] nullIfEmpty];
    if (extPrebidObj != [NSNull null]) {
        ret[@"prebid"] = extPrebidObj;
    } else {
        ret[@"dlp"] = @(1);
    }
    
    id extSkadnObj = [[self.extSkadn toJsonDictionary] nullIfEmpty];
    if (extSkadnObj != [NSNull null]) {
        ret[@"skadn"] = extSkadnObj;
    }
    
    if (self.extData && self.extData.count > 0) {
        ret[@"data"] = self.extData;
    }
    
    if (self.extKeywords && self.extKeywords.length > 0) {
        ret[@"keywords"] = self.extKeywords;
    }
    
    if (self.extGPID) {
        ret[@"gpid"] = self.extGPID;
    }
    
    return [ret swpbmCopyWithoutEmptyVals];
}

@end
