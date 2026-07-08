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

#import "SWPBMOpenMeasurementEventTracker.h"
#import "SWLog+Extensions.h"

#import "SWSwiftImport.h"

#import <OMSDK_Sellwild/OMIDAdSession.h>
#import <OMSDK_Sellwild/OMIDAdEvents.h>
#import <OMSDK_Sellwild/OMIDMediaEvents.h>

@interface SWPBMOpenMeasurementEventTracker()

@property (nonatomic, strong) OMIDPrebidorgAdSession *session;

@property (nonatomic, strong) OMIDPrebidorgAdEvents *adEvents;
@property (nonatomic, strong) OMIDPrebidorgMediaEvents *mediaEvents;

@end

@implementation SWPBMOpenMeasurementEventTracker

- (instancetype)initWithSession:(OMIDPrebidorgAdSession *)session {
    self = [super init];
    if (self) {
        self.session = session;
        [self initOMEventTrackers];
    }
    
    return self;
}

- (void)trackEvent:(SWPBMTrackingEvent)event {
    if (!self.session) {
        SWPBMLogError(@"Measurement Session is missed.");
        return;
    }
    
    switch (event) {
        case SWPBMTrackingEventLoaded         : [self trackAdLoaded]; break;
        case SWPBMTrackingEventImpression     : [self trackImpression]; break;
            
        case SWPBMTrackingEventClick          : [self.mediaEvents adUserInteractionWithType:OMIDInteractionTypeClick]; break;
        case SWPBMTrackingEventCompanionClick : [self.mediaEvents adUserInteractionWithType:OMIDInteractionTypeClick]; break;

        case SWPBMTrackingEventFirstQuartile  : [self.mediaEvents firstQuartile]; break;
        case SWPBMTrackingEventMidpoint       : [self.mediaEvents midpoint];break;
        case SWPBMTrackingEventThirdQuartile  : [self.mediaEvents thirdQuartile];break;
        case SWPBMTrackingEventComplete       : [self.mediaEvents complete];break;
        case SWPBMTrackingEventPause          : [self.mediaEvents pause]; break;
        case SWPBMTrackingEventResume         : [self.mediaEvents resume]; break;
        case SWPBMTrackingEventSkip           : [self.mediaEvents skipped]; break;
        
        // Are not supported in the current implementation. All video ads are shown in fullscreen mode without options.
        case SWPBMTrackingEventFullscreen     : [self.mediaEvents playerStateChangeTo:OMIDPlayerStateFullscreen]; break;
        case SWPBMTrackingEventExitFullscreen : [self.mediaEvents playerStateChangeTo:OMIDPlayerStateNormal]; break;
        case SWPBMTrackingEventNormal         : [self.mediaEvents playerStateChangeTo:OMIDPlayerStateNormal]; break;
        case SWPBMTrackingEventCollapse       : [self.mediaEvents playerStateChangeTo:OMIDPlayerStateCollapsed]; break;
        case SWPBMTrackingEventExpand         : [self.mediaEvents playerStateChangeTo:OMIDPlayerStateExpanded]; break;
            
        default:
            break;
    }
}

- (void)trackAdLoaded {
    NSError *error = nil;
    [self.adEvents loadedWithError:&error];
    if (error != nil) {
        SWPBMLogError(@"%@", [error localizedDescription]);
    }
}

- (void)trackVideoAdLoaded:(SWPBMVideoVerificationParameters *)parameters {
    NSError *error = nil;
    [self.adEvents loadedWithVastProperties:[[OMIDPrebidorgVASTProperties alloc] initWithAutoPlay:parameters.autoPlay position:OMIDPositionStandalone] error:&error];
    if (error != nil) {
        SWPBMLogError(@"%@", [error localizedDescription]);
    }
}

- (void)trackStartVideoWithDuration:(CGFloat)duration volume:(CGFloat)volume {
    [self.mediaEvents startWithDuration:duration mediaPlayerVolume:volume];
}

- (void)trackVolumeChanged:(CGFloat)volume deviceVolume:(CGFloat)deviceVolume {
    [self.mediaEvents volumeChangeTo:volume];
}

#pragma mark - Internal Methods

- (void)initOMEventTrackers {
    
    NSError *adEventsError;
    self.adEvents = [[OMIDPrebidorgAdEvents alloc] initWithAdSession:self.session error:&adEventsError];
    if (adEventsError) {
        SWPBMLogError(@"Open Measurement can't create ad events with error: %@", [adEventsError localizedDescription]);
    }
    
    if (self.session.configuration.mediaEventsOwner == OMIDNativeOwner) {
        NSError *videoEventsError;
        self.mediaEvents = [[OMIDPrebidorgMediaEvents alloc] initWithAdSession:self.session error:&videoEventsError];
        if (videoEventsError) {
            SWPBMLogError(@"Open Measurement can't create video events with error: %@", [videoEventsError localizedDescription]);
        }
    }
}

#pragma mark - Tracking Methods

- (void)trackImpression {
    NSError *impError;
    [self.adEvents impressionOccurredWithError:&impError];
    if (impError) {
        SWPBMLogError(@"Open Measurement can't track impression with error: %@", [impError localizedDescription]);
    }
}

@end
