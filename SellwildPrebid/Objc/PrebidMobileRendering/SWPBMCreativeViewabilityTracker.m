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

#import "SWPBMViewExposureChecker.h"
#import "SWPBMMacros.h"

#import "NSTimer+SWPBMScheduledTimerFactory.h"
#import "SWPBMWeakTimerTargetBox.h"
#import "UIView+SWPBMExtensions.h"

#import "SWSwiftImport.h"

#ifdef DEBUG
    #import "SellwildPrebid+TestExtension.h"
#endif

typedef void(^SWPBMViewExposureChangeHandler)(id<SWPBMCreativeViewabilityTracker> tracker, id<SWPBMViewExposure> viewExposure);

@interface SWPBMCreativeViewabilityTracker_Objc : NSObject <SWPBMCreativeViewabilityTracker>

@property (nonatomic, assign, readonly) NSTimeInterval pollingTimeInterval;
@property (nonatomic, strong, nonnull, readonly) SWPBMViewExposureChangeHandler onExposureChange;

@property (nonatomic, strong, nonnull, readonly) SWPBMViewExposureChecker *checker;

@property (nonatomic, strong, nullable) id<SWPBMTimerInterface> timer;
@property (nonatomic, strong, nonnull) id<SWPBMViewExposure> lastExposure;

@property (nonatomic, nullable, weak, readonly) UIView *testedView;
@property (nonatomic, assign) BOOL isViewabilityMode;

@end

@implementation SWPBMCreativeViewabilityTracker_Objc

- (instancetype)initWithView:(UIView *)view
         pollingTimeInterval:(NSTimeInterval)pollingTimeInterval
            onExposureChange:(SWPBMViewExposureChangeHandler)onExposureChange {
    self = [super init];
    if (self) {
        _checker = [[SWPBMViewExposureChecker alloc] initWithView:view];
        _pollingTimeInterval = pollingTimeInterval;
        _lastExposure = [SWPBMFactory.ViewExposureType zeroExposure];
        _onExposureChange = onExposureChange;
        
        _testedView = view;
        _isViewabilityMode = NO;
    }

    return self;
}

- (instancetype)initWithCreative:(id<SWPBMAbstractCreative>)creative {
    @weakify(creative);
    if (self = [self initWithView:creative.view
          pollingTimeInterval:creative.creativeModel.adConfiguration.pollFrequency
             onExposureChange:^(id<SWPBMCreativeViewabilityTracker> tracker, id<SWPBMViewExposure> viewExposure)
    {
        @strongify(creative);
        __auto_type objcTracker = (SWPBMCreativeViewabilityTracker_Objc *)tracker;
        if (![tracker isKindOfClass:SWPBMCreativeViewabilityTracker_Objc.class]) {
            return;
        }
        
        BOOL isVisible = [objcTracker isVisibleView:objcTracker.testedView];
        [creative onViewabilityChanged:isVisible viewExposure:viewExposure];
    }]) {
        _isViewabilityMode = YES;
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

- (void)start {
    [self stop];
    SWPBMScheduledTimerFactory const timerFatory = [SWPBMWeakTimerTargetBox
                                                  scheduledTimerFactoryWithWeakifiedTarget:[NSTimer
                                                                                            swpbmScheduledTimerFactory]];
    self.timer = timerFatory(self.pollingTimeInterval, self, @selector(checkViewability), nil, YES);
}

- (void)checkViewability {
    
    //don't waste time for exposure calculation
    //when it unneeded
    if (self.isViewabilityMode) {
        self.onExposureChange(self, self.lastExposure);
        return;
    }
    
    //TODO: check visibility using viewableDuration and area in future
    [self checkExposureWithForce:NO];
}

- (void)checkExposureWithForce:(BOOL)isForce {
    id<SWPBMViewExposure> const newExposure = self.checker.exposure;
    
    if (isForce || ![newExposure isEqual:self.lastExposure]) {
        self.lastExposure = newExposure;
        self.onExposureChange(self, newExposure);
    }
}

- (BOOL)isVisibleView:(UIView *)view {
#ifdef DEBUG
    if (SellwildPrebid.shared.forcedIsViewable) {
        return YES;
    }
#endif
    if (!view) {
        return NO;
    }
    
    return [view swpbmIsVisibleInViewLegacy:view.superview] && view.window != nil;
}

- (void)stop {
    [self.timer invalidate];
}

@end
