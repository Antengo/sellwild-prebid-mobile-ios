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

#import "SWPBMOpenMeasurementFriendlyObstructionTypeBridge.h"

#import "SWSwiftImport.h"

@implementation SWPBMOpenMeasurementFriendlyObstructionTypeBridge

+ (OMIDFriendlyObstructionType)obstructionTypeOfObstructionPurpose:(SWPBMOpenMeasurementFriendlyObstructionPurpose)friendlyObstructionPurpose {
    switch (friendlyObstructionPurpose) {
        case SWPBMOpenMeasurementFriendlyObstructionPurposeModalViewControllerClose:
            return OMIDFriendlyObstructionCloseAd;
        case SWPBMOpenMeasurementFriendlyObstructionPurposeVideoViewProgressBar:
            return OMIDFriendlyObstructionMediaControls;
        default:
            return OMIDFriendlyObstructionOther;
    }
}

+ (NSString *)describeFriendlyObstructionPurpose:(SWPBMOpenMeasurementFriendlyObstructionPurpose)friendlyObstructionPurpose {
    
    // Can be nil.
    // If not nil, must be 50 characters or less and only contain characers
    // * `A-z`, `0-9`, or spaces.
    
    switch (friendlyObstructionPurpose) {
        case SWPBMOpenMeasurementFriendlyObstructionPurposeWindowLockerBackground:
            return @"Fullscreen UI locker or loading the ad";
        case SWPBMOpenMeasurementFriendlyObstructionPurposeWindowLockerActivityIndicator:
            return @"Activity Indicator for loading the ad";
        case SWPBMOpenMeasurementFriendlyObstructionPurposeModalViewControllerView:
            return @"Fullscreen modal ad view container";
        case SWPBMOpenMeasurementFriendlyObstructionPurposeModalViewControllerClose:
            return @"Close button";
        case SWPBMOpenMeasurementFriendlyObstructionPurposeVideoViewLearnMoreButton:
            return @"Learn More  button";
        case SWPBMOpenMeasurementFriendlyObstructionPurposeVideoViewProgressBar:
            return @"Video playback Progress Bar";
        default:
            return nil;
    }
}

@end
