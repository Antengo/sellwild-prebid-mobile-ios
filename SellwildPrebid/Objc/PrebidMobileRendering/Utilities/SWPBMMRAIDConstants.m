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

#import "SWPBMMRAIDConstants.h"

//MARK: MRAID Actions
// Debug
SWPBMMRAIDAction const SWPBMMRAIDActionLog = @"log";
// MRAID 1
SWPBMMRAIDAction const SWPBMMRAIDActionOpen = @"open";
SWPBMMRAIDAction const SWPBMMRAIDActionClose = @"close";
SWPBMMRAIDAction const SWPBMMRAIDActionExpand = @"expand";
// MRAID 2
SWPBMMRAIDAction const SWPBMMRAIDActionResize = @"resize";
SWPBMMRAIDAction const SWPBMMRAIDActionStorePicture = @"storepicture";
SWPBMMRAIDAction const SWPBMMRAIDActionCreateCalendarEvent = @"createCalendarevent";
SWPBMMRAIDAction const SWPBMMRAIDActionPlayVideo = @"playVideo";
SWPBMMRAIDAction const SWPBMMRAIDActionOnOrientationPropertiesChanged = @"onOrientationPropertiesChanged";
// MRAID 3
SWPBMMRAIDAction const SWPBMMRAIDActionUnload = @"unload";
// ---- end MRAID Actions

// mraid enums and structs
SWPBMMRAIDPlacementType const SWPBMMRAIDPlacementTypeInline = @"inline";
SWPBMMRAIDPlacementType const SWPBMMRAIDPlacementTypeInterstitial = @"interstitial";

SWPBMMRAIDFeature const SWPBMMRAIDFeatureSMS           = @"sms";
SWPBMMRAIDFeature const SWPBMMRAIDFeaturePhone         = @"tel";
SWPBMMRAIDFeature const SWPBMMRAIDFeatureCalendar      = @"calendar";
SWPBMMRAIDFeature const SWPBMMRAIDFeatureSavePicture   = @"storePicture";
SWPBMMRAIDFeature const SWPBMMRAIDFeatureInlineVideo   = @"inlineVideo";
SWPBMMRAIDFeature const SWPBMMRAIDFeatureLocation      = @"location";
SWPBMMRAIDFeature const SWPBMMRAIDFeatureVPAID         = @"vpaid";

#pragma mark - SWPBMMRAIDParseKeys

@implementation SWPBMMRAIDParseKeys

+(NSString *)X {
    return @"x";
}

+(NSString *)Y {
    return @"y";
}

+(NSString *)WIDTH {
    return @"width";
}

+(NSString *)HEIGHT {
    return @"height";
}

+(NSString *)X_OFFSET {
    return @"offsetX";
}

+(NSString *)Y_OFFSET {
    return @"offsetY";
}

+(NSString *)ALLOW_OFFSCREEN {
    return @"allowOffscreen";
}

+(NSString *)FORCE_ORIENTATION {
    return @"forceOrientation";
}

@end


#pragma mark - SWPBMMRAIDValues

@implementation SWPBMMRAIDValues

+(NSString *)LANDSCAPE {
    return @"landscape";
}

+(NSString *)PORTRAIT {
    return @"portrait";
}

@end


#pragma mark - SWPBMMRAIDCloseButtonPosition

@implementation SWPBMMRAIDCloseButtonPosition

+(NSString *)BOTTOM_CENTER {
    return @"bottom-center";
}

+(NSString *)BOTTOM_LEFT {
    return @"bottom-left";
}

+(NSString *)BOTTOM_RIGHT {
    return @"bottom-right";
}

+(NSString *)CENTER {
    return @"center";
}

+(NSString *)TOP_CENTER {
    return @"top-center";
}

+(NSString *)TOP_LEFT {
    return @"top-left";
}

+(NSString *)TOP_RIGHT {
    return @"top-right";
}

@end


#pragma mark - SWPBMMRAIDCloseButtonSize

@implementation SWPBMMRAIDCloseButtonSize

+(float)WIDTH {
    return 50;
}

+(float)HEIGHT {
    return 50;
}

@end

#pragma mark - SWPBMMRAIDExpandProperties


@implementation SWPBMMRAIDExpandProperties

- (nonnull instancetype)initWithWidth:(NSInteger)width height:(NSInteger)height {
    self = [super init];
    if (self) {
        self.width = width;
        self.height = height;
    }
    
    return self;
}

@end

#pragma mark SWPBMMRAIDResizeProperties

@implementation SWPBMMRAIDResizeProperties

- (nonnull instancetype)initWithWidth:(NSInteger)width
                               height:(NSInteger)height
                              offsetX:(NSInteger)offsetX
                              offsetY:(NSInteger)offsetY
                       allowOffscreen:(BOOL)allowOffscreen; {
    self = [super init];
    if (self) {
        self.width = width;
        self.height = height;
        self.offsetX = offsetX;
        self.offsetY = offsetY;
        self.allowOffscreen = allowOffscreen;
    }
    
    return self;
}

@end

#pragma mark - SWPBMMRAIDConstants

@implementation SWPBMMRAIDConstants

+(NSString *)mraidURLScheme {
    return @"mraid:";
}

+(NSArray<NSString *> *)allCases {
    static NSArray *_allCases;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _allCases = @[SWPBMMRAIDActionOpen,
                      SWPBMMRAIDActionExpand,
                      SWPBMMRAIDActionResize,
                      SWPBMMRAIDActionClose,
                      SWPBMMRAIDActionPlayVideo,
                      SWPBMMRAIDActionLog,
                      SWPBMMRAIDActionOnOrientationPropertiesChanged,
                      SWPBMMRAIDActionUnload,
        ];
    });
    return _allCases;
}

@end
