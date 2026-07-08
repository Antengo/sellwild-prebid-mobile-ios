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

#import "SWPBMModalState.h"
#import "SWPBMWebView.h"
#import "SWPBMMacros.h"

#import "SWSwiftImport.h"

@interface SWPBMModalState_Objc : NSObject <SWPBMModalState>
@end

// MARK: -

@implementation SWPBMModalState_Objc
@synthesize adConfiguration = _adConfiguration;
@synthesize displayProperties = _displayProperties;
@synthesize mraidState = _mraidState;
@synthesize nextOnStateHasLeftApp = _nextOnStateHasLeftApp;
@synthesize nextOnStatePopFinished = _nextOnStatePopFinished;
@synthesize onModalPushedBlock = _onModalPushedBlock;
@synthesize onStateHasLeftApp = _onStateHasLeftApp;
@synthesize onStatePopFinished = _onStatePopFinished;
@synthesize view = _view;

#pragma mark - Initialization

- (instancetype)initWithView:(nonnull UIView *)view
             adConfiguration:(nullable SWPBMAdConfiguration *)adConfiguration
           displayProperties:(nullable SWPBMInterstitialDisplayProperties *)displayProperties
          onStatePopFinished:(nullable SWPBMModalStatePopHandler)onStatePopFinished
           onStateHasLeftApp:(nullable SWPBMModalStateAppLeavingHandler)onStateHasLeftApp
      nextOnStatePopFinished:(nullable SWPBMModalStatePopHandler)nextOnStatePopFinished
       nextOnStateHasLeftApp:(nullable SWPBMModalStateAppLeavingHandler)nextOnStateHasLeftApp
          onModalPushedBlock:(nullable SWPBMVoidBlock)onModalPushedBlock
{
    _view = view;
    _adConfiguration = adConfiguration;
    _displayProperties = displayProperties;
    _onStatePopFinished = [onStatePopFinished copy];
    _onStateHasLeftApp = [onStateHasLeftApp copy];
    _nextOnStatePopFinished = [nextOnStatePopFinished copy];
    _nextOnStateHasLeftApp = [nextOnStateHasLeftApp copy];
    _onModalPushedBlock = [onModalPushedBlock copy];
    _mraidState = SWPBMMRAIDState.notEnabled;
    
    return self;
}

- (BOOL)isRotationEnabled {
    BOOL enabled = YES;
    UIView *lastView = [self.view.subviews lastObject];
    if ([lastView isKindOfClass:[SWPBMWebView class]]) {
        SWPBMWebView *webView = (SWPBMWebView *)lastView;
        enabled = webView.rotationEnabled;
    }
    
    return enabled;
}

@end
