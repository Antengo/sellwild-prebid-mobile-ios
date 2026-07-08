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

#import "SWPBMVastCreativeLinear.h"
#import "SWPBMConstants.h"

#import "SWSwiftImport.h"

#pragma mark - Private Extension

@interface SWPBMVastCreativeLinear()

@property (nonatomic, strong, nullable) SWPBMVastMediaFile *myBestMediaFile;

@end

#pragma mark - Implementation

@implementation SWPBMVastCreativeLinear

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        self.skipOffset = nil;
        self.icons = [NSMutableArray array];
        self.mediaFiles = [NSMutableArray array];
        self.vastTrackingEvents = [[SWPBMVastTrackingEvents alloc] init];
        self.clickTrackingURIs = [NSMutableArray array];
    }
    
    return self;
}

- (SWPBMVastMediaFile *)bestMediaFile {
    SWPBMVastMediaFile *ret = nil;
    if (self.myBestMediaFile) {
        ret = self.myBestMediaFile;
    }
    else {
        NSMutableArray *eligableMediaFiles = [NSMutableArray array];
        for (SWPBMVastMediaFile *mediaFile in self.mediaFiles) {
            if ([PrebidConstants.SUPPORTED_VIDEO_MIME_TYPES containsObject:mediaFile.type]) {
                [eligableMediaFiles addObject:mediaFile];
            }
        }
        
        // choose the one with the highest resolution that is acceptable
        if (eligableMediaFiles.count) {
            ret = [eligableMediaFiles firstObject];
            for (SWPBMVastMediaFile *mediaFile in eligableMediaFiles) {
                if (mediaFile.width * mediaFile.height > ret.width * ret.height) {
                    ret = mediaFile;
                }
            }
        }
    }
    
    return ret;
}

@end
