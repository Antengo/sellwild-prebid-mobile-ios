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
#import "SWPBMVideoCreative.h"
#import "SWPBMDownloadDataHelper.h"
#import "SWPBMMacros.h"
#import "SWLog+Extensions.h"

#import "SWSwiftImport.h"

#pragma mark - Private Properties

@interface SWPBMDownloadDataHelper()

@property (nonatomic, weak) id<SWPBPrebidServerConnectionProtocol> serverConnection;

@end

#pragma mark - Implementation

@implementation SWPBMDownloadDataHelper

#pragma mark - Initialization

- (nonnull instancetype)initWithServerConnection:(nonnull id<SWPBPrebidServerConnectionProtocol>)serverConnection {
    self = [super init];
    if (self) {
        SWPBMAssert(serverConnection);
        
        self.serverConnection = serverConnection;
    }
    
    return self;
}

#pragma mark - Public Methods

- (void)downloadDataForURL:(nullable NSURL *)url
                   maxSize:(NSInteger)maxSize
         completionClosure:(nonnull SWPBMDownloadDataCompletionClosure)completionClosure{
    
    if (!completionClosure) {
        return;
    }

    [self.serverConnection head:url.absoluteString timeout:SWPBPrebidConstants.FIRE_AND_FORGET_TIMEOUT callback:^(SWPBPrebidServerResponse * _Nonnull serverResponse) {
  
        NSString *strContentLength = serverResponse ? serverResponse.responseHeaders[@"Content-Length"] : nil;
        
        // NOTE: need to be sure that value is an integer. [NSString toInt:] can't be used. Because it returns 0 for strings.
        int contentLength = 0;
        BOOL isIntegerValue = [[NSScanner scannerWithString:strContentLength] scanInt:&contentLength];
        
        NSNumber* sizeInBytes = (isIntegerValue && contentLength >= 0) ? @(contentLength) : nil;
        
        if (!sizeInBytes) {
            NSString *description = [NSString stringWithFormat:@"Unable to determine video file size: %@", url];
            completionClosure(nil, [SWPBMError errorWithDescription:description]);
            return;
        }
        
        if (sizeInBytes.integerValue > maxSize) {
            NSString *description = [NSString stringWithFormat:@"Cannot preRender video at %@. Size of %ld bytes is greater than the maximum size for preloading of %ld bytes.", url, (long)sizeInBytes.integerValue, (long)maxSize];
            completionClosure(nil, [SWPBMError errorWithDescription:description]);
            return;
        }
        
        [self downloadDataForURL:url completionClosure:completionClosure];
    }];
}

- (void)downloadDataForURL:(nullable NSURL *)url completionClosure:(nonnull SWPBMDownloadDataCompletionClosure)completionClosure {
    if (!completionClosure) {
        return;
    }
    
    [self.serverConnection download:url.absoluteString callback:^(SWPBPrebidServerResponse * _Nonnull response) {
        if (!response) {
            completionClosure(nil, [SWPBMError errorWithDescription:[NSString stringWithFormat:@"The response is empty for loading data from %@ ", url]]);
            return;
        }
        
        completionClosure(response.rawData, response.error);
    }];
}

@end
