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

#import "SWPBMConstants.h"
#import "SWPBMMacros.h"
#import "SWPBMORTB.h"
#import "SWPBMORTBBidRequest.h"

#import "SWPBMAppInfoParameterBuilder.h"
#import "SWLog+Extensions.h"

#import "SWSwiftImport.h"

#pragma mark - Internal Extension

@interface SWPBMAppInfoParameterBuilder ()

@property (nonatomic, strong, readonly) id<SWPBMBundleProtocol> bundle;
@property (nonatomic, strong, readonly) SWPBTargeting *targeting;

@end

#pragma mark - Implementation

@implementation SWPBMAppInfoParameterBuilder

#pragma mark - Properties

//Keys into Bundle info Dict
+ (NSString *)bundleNameKey {
    return @"CFBundleName";
}

+ (NSString *)bundleDisplayNameKey {
    return @"CFBundleDisplayName";
}

#pragma mark - Initialization

- (nonnull instancetype)initWithBundle:(id<SWPBMBundleProtocol>)bundle targeting:(SWPBTargeting *)targeting {
    if (!(self = [super init])) {
        return nil;
    }
    SWPBMAssert(bundle && targeting);
    _bundle = bundle;
    _targeting = targeting;
    
    return self;
}

#pragma mark - SWPBMParameterBuilder

- (void)buildBidRequest:(SWPBMORTBBidRequest *)bidRequest {
    if (!(self.bundle && bidRequest)) {
        SWPBMLogError(@"Invalid properties");
        return;
    }
    
    NSString *bundleIdentifier = self.bundle.bundleIdentifier;
    if (bidRequest.app.bundle==nil && bundleIdentifier) {
        bidRequest.app.bundle = bundleIdentifier;
    }

    NSDictionary *bundleDict = self.bundle.infoDictionary;
    if (bundleDict) {
        NSString *bundleDisplayName = bundleDict[SWPBMAppInfoParameterBuilder.bundleDisplayNameKey];
        NSString *bundleName = bundleDict[SWPBMAppInfoParameterBuilder.bundleNameKey];
        NSString *appName = bundleDisplayName ? bundleDisplayName : bundleName;
        if (appName) {
            bidRequest.app.name = appName;
        }
    }
    
    NSString *publisherName = self.targeting.publisherName;
    if (!bidRequest.app.publisher.name && publisherName) {
        if (!bidRequest.app.publisher) {
            bidRequest.app.publisher = [SWPBMORTBPublisher new];
        }
        bidRequest.app.publisher.name = publisherName;
    }
}

@end
