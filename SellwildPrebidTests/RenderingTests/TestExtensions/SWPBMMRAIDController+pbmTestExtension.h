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

#import "SWPBMMRAIDController.h"

@class SWPBMWebView;

NS_ASSUME_NONNULL_BEGIN

@interface SWPBMMRAIDController ()

@property (nonatomic, strong, nullable) SWPBMWebView *prebidWebView;
@property (nonatomic, strong, nullable) UIViewController* viewControllerForPresentingModals;

+ (CGRect)CGRectForResizeProperties:(SWPBMMRAIDResizeProperties *)properties fromView:(UIView *)fromView;

- (instancetype)initWithCreative:(id<SWPBMAbstractCreative>)creative
     viewControllerForPresenting:(UIViewController*)viewControllerForPresentingModals
                         webView:(SWPBMWebView*)webView
            creativeViewDelegate:(id<SWPBMCreativeViewDelegate>)creativeViewDelegate
                   downloadBlock:(SWPBMCreativeFactoryDownloadDataCompletionClosure)downloadBlock
        deviceAccessManagerClass:(Class)deviceAccessManagerClass
                sdkConfiguration:(SellwildPrebid *)sdkConfiguration;

- (SWPBMMRAIDCommand*)commandFromURL:(nullable NSURL*)url;
@end

NS_ASSUME_NONNULL_END
