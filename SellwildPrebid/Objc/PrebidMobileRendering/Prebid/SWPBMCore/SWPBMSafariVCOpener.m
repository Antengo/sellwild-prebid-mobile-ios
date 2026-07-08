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

#import "SWPBMSafariVCOpener.h"

#import "SWPBMDeepLinkPlusHelper.h"
#import "SWPBMFunctions.h"
#import "SWPBMFunctions+Private.h"
#import "SWPBMWindowLocker.h"
#import "SWLog+Extensions.h"

#import "SWSwiftImport.h"

#import "SWPBMMacros.h"


@interface SWPBMSafariVCOpener ()

@property (nonatomic, strong, nonnull, readonly) SellwildPrebid *sdkConfiguration;
@property (nonatomic, strong, nonnull, readonly) SWPBMModalManager *modalManager;

@property (nonatomic, strong, nonnull, readonly) SWPBMViewControllerProvider viewControllerProvider;
@property (nonatomic, strong, nonnull, readonly) SWPBMOpenMeasurementSessionProvider measurementSessionProvider;

@property (nonatomic, strong, nullable, readonly) SWPBMVoidBlock onWillLoadURLInClickthrough;
@property (nonatomic, strong, nullable, readonly) SWPBMVoidBlock onWillLeaveAppBlock;
@property (nonatomic, strong, nullable, readonly) SWPBMModalStatePopHandler onClickthroughPoppedBlock;
@property (nonatomic, strong, nullable, readonly) SWPBMModalStateAppLeavingHandler onDidLeaveAppBlock;

@property (nonatomic, strong, nullable) SWPBMVoidBlock onClickthroughExitBlock;

@property (nonatomic, strong, nullable) SFSafariViewController * safariViewController;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, SWPBMWindowLocker *> *windowLockers;
@property (nonatomic, strong, nullable) NSNumber *currentWindowLockerKey;

@end


@implementation SWPBMSafariVCOpener

- (instancetype)initWithSDKConfiguration:(SellwildPrebid *)sdkConfiguration
                            modalManager:(SWPBMModalManager *)modalManager
                  viewControllerProvider:(SWPBMViewControllerProvider)viewControllerProvider
              measurementSessionProvider:(SWPBMOpenMeasurementSessionProvider)measurementSessionProvider
             onWillLoadURLInClickthrough:(nullable SWPBMVoidBlock)onWillLoadURLInClickthrough
                     onWillLeaveAppBlock:(nullable SWPBMVoidBlock)onWillLeaveAppBlock
               onClickthroughPoppedBlock:(nullable SWPBMModalStatePopHandler)onClickthroughPoppedBlock
                      onDidLeaveAppBlock:(nullable SWPBMModalStateAppLeavingHandler)onDidLeaveAppBlock
{
    if (!(self = [super init])) {
        return nil;
    }
    
    _sdkConfiguration = sdkConfiguration;
    _modalManager = modalManager;
    _viewControllerProvider = viewControllerProvider;
    _measurementSessionProvider = measurementSessionProvider;
    _onWillLoadURLInClickthrough = onWillLoadURLInClickthrough;
    _onWillLeaveAppBlock = onWillLeaveAppBlock;
    _onClickthroughPoppedBlock = onClickthroughPoppedBlock;
    _onDidLeaveAppBlock = onDidLeaveAppBlock;
    _windowLockers = [NSMutableDictionary new];
    return self;
}

- (BOOL)openURL:(NSURL *)url onClickthroughExitBlock:(nullable SWPBMVoidBlock)onClickthroughExitBlock {
    self.onClickthroughExitBlock = onClickthroughExitBlock;
    
    NSString * const strURLscheme = [self getURLScheme:url];
    if (!strURLscheme) {
        SWPBMLogError(@"Could not determine URL scheme from url: %@", url);
        return NO;
    }
    
    if (![self shouldTryOpenURLScheme:strURLscheme]) {
        SWPBMLogError(@"Attempting to open url [%@] in iOS simulator, but simulator does not support url scheme of %@",
                    url, strURLscheme);
        return NO;
    }
    
    UIViewController * const viewControllerForPresentingModals = self.viewControllerProvider();
    if (viewControllerForPresentingModals == nil) {
        SWPBMLogError(@"self.viewControllerForPresentingModals is nil");
        return NO;
    }
     
    if (!([strURLscheme isEqualToString:@"http"] || [strURLscheme isEqualToString:@"https"])) {
        SWPBMLogError(@"Attempting to open url [%@] in SFSafariViewController. SFSafariViewController only supports initial URLs with http:// or https:// schemes.", url);
        return NO;
    }
    
    //Show clickthrough browser
    
    return [self openClickthroughWithURL:url
                          viewController:viewControllerForPresentingModals];
}

// MARK: - Private

- (NSString *)getURLScheme:(NSURL *)url {
    return [url.scheme lowercaseString];
}

- (BOOL)shouldTryOpenURLScheme:(NSString *)strURLscheme {
    if ([SWPBMFunctions isSimulator] && [PrebidConstants.URL_SCHEMES_NOT_SUPPORTED_ON_SIMULATOR containsObject:strURLscheme]) {
        return NO;
    }
    
    return YES;
}

- (BOOL)shouldOpenURLSchemeExternally:(NSString *)strURLscheme {
    return NO;
}
    
- (BOOL)openClickthroughWithURL:(NSURL *)url
                 viewController:(UIViewController *)viewControllerForPresentingModals
{
    @try {
        if (self.safariViewController && self.safariViewController.presentingViewController) {
            SWPBMLogInfo(@"⚠️ Safari already being presented, ignoring");
            return NO;
        }
        
        self.safariViewController = [[SFSafariViewController alloc] initWithURL:url];
        self.safariViewController.delegate = self;
        
        UIViewController * presentingViewController = viewControllerForPresentingModals;
        
        if (self.modalManager.modalViewController) {
            presentingViewController = self.modalManager.modalViewController;
        }
        
        if (presentingViewController.presentedViewController != nil) {
            SWPBMLogInfo(@"⚠️ Presenting view controller is already presenting something");
            return NO;
        }
        
        NSNumber *key = @(viewControllerForPresentingModals.view.window.hash);
        SWPBMOpenMeasurementSession * const measurementSession = self.measurementSessionProvider();
        SWPBMWindowLocker *windowLocker = [self windowLockerForWindow:viewControllerForPresentingModals.view.window
                                                  measurementSession:measurementSession];
        [windowLocker lock];
        
        self.currentWindowLockerKey = key;
        
        if (self.onWillLoadURLInClickthrough != nil) {
            self.onWillLoadURLInClickthrough();
        }
        
        [presentingViewController presentViewController:self.safariViewController animated:YES completion:^{
            [windowLocker unlock];
        }];
    } @catch (NSException *exception) {
        SWPBMLogError(@"Error occurred during URL opening: %@", exception.reason);
        return NO;
    }
    
    return YES;
}

- (SWPBMWindowLocker *)windowLockerForWindow:(UIWindow *)window
                        measurementSession:(SWPBMOpenMeasurementSession *)measurementSession {
    NSNumber *key = @(window.hash);
    SWPBMWindowLocker *locker = self.windowLockers[key];
    
    if (!locker) {
        locker = [[SWPBMWindowLocker alloc] initWithWindow:window
                                      measurementSession:measurementSession];
        self.windowLockers[key] = locker;
    }
    return locker;
}

#pragma mark SFSafariViewControllerDelegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    if (self.currentWindowLockerKey) {
        [self.windowLockers removeObjectForKey:self.currentWindowLockerKey];
        self.currentWindowLockerKey = nil;
    }
    
    if (self.onClickthroughPoppedBlock != nil) {
        self.onClickthroughPoppedBlock(nil);
    }
    
    if (self.onClickthroughExitBlock) {
        self.onClickthroughExitBlock();
    }
}

- (void)safariViewControllerWillOpenInBrowser:(SFSafariViewController *)controller {
    if (self.onDidLeaveAppBlock) {
        self.onDidLeaveAppBlock(nil);
    }
}

@end
