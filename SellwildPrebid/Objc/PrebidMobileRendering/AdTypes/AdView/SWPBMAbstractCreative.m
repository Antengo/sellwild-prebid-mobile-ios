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

#import <StoreKit/SKStoreProductViewController.h>
#import <WebKit/WebKit.h>

#import "SWPBMAbstractCreative+Protected.h"
#import "SWPBMAbstractCreative.h"
#import "SWPBMSafariVCOpener.h"
#import "SWPBMDeepLinkPlusHelper.h"
#import "SWPBMFunctions+Private.h"
#import "SWPBMFunctions.h"
#import "SWPBMMacros.h"
#import "SWPBMModalState.h"
#import "SWPBMOpenMeasurementSession.h"
#import "SWPBMOpenMeasurementWrapper.h"
#import "SWPBMWindowLocker.h"

#import "SWLog+Extensions.h"

#import "SWSwiftImport.h"

@interface SWPBMAbstractCreative_Objc () <SKStoreProductViewControllerDelegate>

@property (nonatomic, weak, readwrite) id<SWPBMTransaction> transaction;
@property (nonatomic, strong, readwrite) SWPBMEventManager *eventManager;
@property (nonatomic, copy, nullable, readwrite) SWPBMVoidBlock dismissInterstitialModalState;

@property (nonatomic, assign) BOOL adWasShown;

@property (nonatomic, strong, nullable) SWPBMSafariVCOpener * safariOpener;

@end

@implementation SWPBMAbstractCreative_Objc
@synthesize creativeModel = _creativeModel;
@synthesize creativeResolutionDelegate = _creativeResolutionDelegate;
@synthesize creativeViewDelegate = _creativeViewDelegate;
@synthesize clickthroughVisible = _clickthroughVisible;
@synthesize dispatchQueue = _dispatchQueue;
@synthesize isDownloaded = _isDownloaded;
@synthesize modalManager = _modalManager;
@synthesize skOverlayManager = _skOverlayManager;
@synthesize view = _view;
@synthesize viewControllerForPresentingModals = _viewControllerForPresentingModals;
@synthesize viewabilityTracker = _viewabilityTracker;

#pragma mark - Init

- (instancetype)initWithCreativeModel:(SWPBMCreativeModel *)creativeModel
                          transaction:(id<SWPBMTransaction>)transaction {
    self = [super init];
    if (self) {
        SWPBMAssert(creativeModel);
        
        _clickthroughVisible = NO;
        _isDownloaded = NO;
        _creativeModel = creativeModel;
        _transaction = transaction;
        _dispatchQueue = dispatch_queue_create("SWPBMAbstractCreative", NULL);
        _eventManager = [SWPBMEventManager new];
        
        if (creativeModel.eventTracker) {
            [self.eventManager registerTracker: (id<SWPBMEventTrackerProtocol>)creativeModel.eventTracker];
        } else {
            SWPBMLogError(@"Creative model must be provided with event tracker");
        }
        
        if(@available(iOS 14.5, *)) {
            if (self.transaction.bid.skadn) {
                SKAdImpression *imp = [SWPBMSkadnParametersManager getSkadnImpressionFor:self.transaction.bid.skadn];
                if (imp) {
                    SWPBMSkadnEventTracker *skadnTracker = [[SWPBMSkadnEventTracker alloc] initWith:imp];
                    [self.eventManager registerTracker:(id<SWPBMEventTrackerProtocol>) skadnTracker];
                }
            }
        }
        
        PrebidServerEventTracker *internalEventTracker = [[PrebidServerEventTracker alloc] initWithServerEvents:@[]];
        
        NSString *impURL = self.transaction.bid.events.imp;
        
        if (impURL) {
            SWPBMServerEvent *impEvent = [[SWPBMServerEvent alloc] initWithUrl:impURL expectedEventType:SWPBMTrackingEventImpression];
            [internalEventTracker addServerEvents:@[impEvent]];
        }
        
        NSString *winURL = self.transaction.bid.events.win;
        
        if (winURL) {
            SWPBMServerEvent *winEvent = [[SWPBMServerEvent alloc] initWithUrl:winURL expectedEventType:SWPBMTrackingEventPrebidWin];
            [internalEventTracker addServerEvents:@[winEvent]];
        }
        
        NSString * burl = self.transaction.bid.burl;
        
        if (burl) {
            SWPBMServerEvent *billingEvent = [[SWPBMServerEvent alloc] initWithUrl:burl expectedEventType:SWPBMTrackingEventImpression];
            [internalEventTracker addServerEvents:@[billingEvent]];
        }
        
        if (internalEventTracker.serverEvents.count > 0) {
            [self.eventManager registerTracker:(id<SWPBMEventTrackerProtocol>) internalEventTracker];
        }
        
        // Track win event immediately
        [self.eventManager trackEvent:SWPBMTrackingEventPrebidWin];
    }

    return self;
}

- (void)dealloc {
    [self.viewabilityTracker stop];
    
    if (self.skOverlayManager) {
        [self.skOverlayManager dismissSKOverlay];
        self.skOverlayManager = nil;
    }
    
    self.viewabilityTracker = NULL;
    SWPBMLogWhereAmI();
}

#pragma mark - Properties

- (BOOL)isOpened {
    return NO;
}

- (NSNumber *)displayInterval {
    return nil;
}

#pragma mark - Public

- (void)setupView {
    [self setupViewWithThread:NSThread.currentThread];
}

- (void)setupViewWithThread:(id<SWPBMThreadProtocol>)thread {
    if (!thread.isMainThread) {
        SWPBMLogError(@"Attempting to set up view on background thread");
    }
}

- (void)displayWithRootViewController:(UIViewController*)viewController {
    if (viewController == nil) {
        SWPBMLogError(@"viewController is nil");
        return;
    }
    
    self.viewControllerForPresentingModals = viewController;
    if (self.creativeModel.adConfiguration.isInterstitialAd) { // raw value access intended
        self.adWasShown = NO;
    }
    
    if (!self.adWasShown) {
        self.viewabilityTracker = [SWPBMFactory createCreativeViewabilityTrackerWithCreative:self];
    }
    
    SWPBMORTBBidExtSkadn * skadnInfo = self.transaction.bid.skadn;
    
    BOOL showSKOverlay = !self.creativeModel.hasCompanionAd &&
                         self.creativeModel.adConfiguration.isInterstitialAd &&
                         ((self.creativeModel.isCompanionAd && skadnInfo.skoverlay.endcarddelay != nil) ||
                         (!self.creativeModel.isCompanionAd && skadnInfo.skoverlay.delay != nil));
    
    if (showSKOverlay) {
        self.skOverlayManager = [[SWPBMSKOverlayManager alloc] initWithViewControllerForPresentation:self.viewControllerForPresentingModals];
        [self.skOverlayManager presentSKOverlayWith:skadnInfo isCompanionAd:self.creativeModel.isCompanionAd];
    }
}

- (void)showAsInterstitialFromRootViewController:(UIViewController*)uiViewController displayProperties:(SWPBMInterstitialDisplayProperties*)displayProperties {
    //This containerView will be stretched to fit the available screen.
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectZero];
    [containerView addSubview:self.view];
    
    displayProperties.closeDelayLeft = displayProperties.closeDelay;
    
    //Create ModalState and push

    @weakify(self);
    id<SWPBMModalState> state = [SWPBMFactory createModalStateWithView:containerView
                                                   adConfiguration:self.creativeModel.adConfiguration
                                                 displayProperties:displayProperties
                                                onStatePopFinished:^(id<SWPBMModalState> _Nonnull poppedState) {
        @strongify(self);
        if (!self) { return; }
        
        [self modalManagerDidFinishPop:poppedState];
    } onStateHasLeftApp:^(id<SWPBMModalState> _Nonnull leavingState) {
        @strongify(self);
        if (!self) { return; }
        
        [self modalManagerDidLeaveApp:leavingState];
    } nextOnStatePopFinished:nil nextOnStateHasLeftApp:nil onModalPushedBlock:nil];
    
    self.dismissInterstitialModalState = [self.modalManager pushModal:state fromRootViewController:uiViewController animated:YES shouldReplace:NO completionHandler:^{
        [self displayWithRootViewController:uiViewController];
        [self.modalManager.modalViewController addFriendlyObstructionsToMeasurementSession:self.transaction.measurementSession];
    }];
}

- (void)handleClickthrough:(NSURL*)url {
    // Call overridden method with empty non-null closures
    [self handleClickthrough:url
            sdkConfiguration:SellwildPrebid.shared
           completionHandler:^(BOOL success){}
                      onExit:^{}];
}

- (void)handleClickthrough:(NSURL*)url
          sdkConfiguration:(SellwildPrebid *)sdkConfiguration {
    [self handleClickthrough:url
            sdkConfiguration:sdkConfiguration
           completionHandler:^(BOOL success){}
                      onExit:^{}];
}

- (void)handleClickthrough:(NSURL*)url
         completionHandler:(void (^)(BOOL success))completion
                    onExit:(SWPBMVoidBlock)onClickthroughExitBlock {
    [self handleClickthrough:url
            sdkConfiguration:SellwildPrebid.shared
           completionHandler:completion
                      onExit:onClickthroughExitBlock];
}

- (void)handleClickthrough:(NSURL*)url
          sdkConfiguration:(SellwildPrebid *)sdkConfiguration
         completionHandler:(void (^)(BOOL success))completion
                    onExit:(SWPBMVoidBlock)onClickthroughExitBlock {
    
    if (self.creativeModel.adConfiguration.clickHandlerOverride != nil) {
        completion(YES);
        self.creativeModel.adConfiguration.clickHandlerOverride(onClickthroughExitBlock);
        return;
    }
    BOOL clickthroughOpened = NO;
    SWPBMJsonDictionary * skadnetProductParameters;
    
    if (self.transaction.bid.skadn) {
        skadnetProductParameters = [SWPBMSkadnParametersManager
                                    getSkadnProductParametersFor:self.transaction.bid.skadn];
    }
    
    if (skadnetProductParameters) {
            clickthroughOpened = [self handleProductClickthrough:url
                                                   productParams:skadnetProductParameters
                                                          onExit:onClickthroughExitBlock];
    } else {
        
        if ([self handleDeepLinkIfNeeded:url
                        sdkConfiguration:sdkConfiguration
                       completionHandler:completion
                                  onExit:onClickthroughExitBlock]) {
            return;
        }
        
        clickthroughOpened = [self handleNormalClickthrough:url
                                           sdkConfiguration:sdkConfiguration
                                                     onExit:onClickthroughExitBlock];
    }
    
    completion(clickthroughOpened);

    if (!clickthroughOpened) {
        onClickthroughExitBlock();
    }
    return;
}

//checks the given URL and process it if it's a deep link
//return YES if the given URL is deeplink
- (BOOL)handleDeepLinkIfNeeded:(NSURL*)url
              sdkConfiguration:(SellwildPrebid *)sdkConfiguration
             completionHandler:(void (^)(BOOL success))completion
                        onExit:(SWPBMVoidBlock)onClickthroughExitBlock {
    NSURL *effectiveURL = url;
    if (self.creativeModel.targetURL != nil) {
        NSURL *overrideURL = [NSURL URLWithString:self.creativeModel.targetURL];
        if (overrideURL != nil) {
            effectiveURL = overrideURL;
        }
    }

    if (![SWPBMDeepLinkPlusHelper isDeepLinkPlusURL:effectiveURL]) {
        return NO;
    } else {
        @weakify(self);
        [SWPBMDeepLinkPlusHelper tryHandleDeepLinkPlus:effectiveURL completion:^(BOOL visited, NSURL *_Nullable fallbackURL, NSArray<NSURL *> *_Nullable trackingURLs) {
            @strongify(self);
            if (!self) { return; }
            
            if (visited) {
                completion(YES);
                onClickthroughExitBlock();
            } else if (!fallbackURL) {
                completion(NO);
                onClickthroughExitBlock();
            } else {
                BOOL clickthroughOpened = [self handleNormalClickthrough:fallbackURL
                                                        sdkConfiguration:sdkConfiguration
                                                                  onExit:onClickthroughExitBlock];

                completion(clickthroughOpened);

                if (clickthroughOpened) {
                    if (trackingURLs != nil) {
                        [SWPBMDeepLinkPlusHelper visitTrackingURLs:trackingURLs];
                    }
                } else {
                    onClickthroughExitBlock();
                }
            }
        }];
        return YES;
    }
}

//Returns true if the clickthrough is presented
- (BOOL)handleNormalClickthrough:(NSURL *)url
                sdkConfiguration:(SellwildPrebid *)sdkConfiguration
                          onExit:(nonnull SWPBMVoidBlock)onClickthroughExitBlock {
    
    @weakify(self);
    
    self.safariOpener = [[SWPBMSafariVCOpener alloc] initWithSDKConfiguration:sdkConfiguration
                                                                           modalManager:self.modalManager
                                                                 viewControllerProvider:^UIViewController * _Nullable{
        @strongify(self);
        return self.viewControllerForPresentingModals;
    } measurementSessionProvider: ^SWPBMOpenMeasurementSession * _Nullable{
        @strongify(self);
        return self.transaction.measurementSession;
    } onWillLoadURLInClickthrough:^{
        @strongify(self);
        self.clickthroughVisible = YES;
    } onWillLeaveAppBlock:^{
        @strongify(self);
        if (!self) { return; }
        
        [self.creativeViewDelegate creativeInterstitialDidLeaveApp:self];
    } onClickthroughPoppedBlock:^(id<SWPBMModalState> poppedState) {
        @strongify(self);
        if (!self) { return; }
        
        [self modalManagerDidFinishPop:poppedState];
    } onDidLeaveAppBlock:^(id<SWPBMModalState> leavingState) {
        @strongify(self);
        if (!self) { return; }
        
        [self modalManagerDidLeaveApp:leavingState];
    }];
    
    return [self.safariOpener openURL:url onClickthroughExitBlock:onClickthroughExitBlock];
}

- (BOOL)handleProductClickthrough:(NSURL*)url
                    productParams:(NSDictionary<NSString *, id> *)productParams
                           onExit:(nonnull SWPBMVoidBlock)onClickthroughExitBlock {
    SWPBMHiddenWebViewManager *webViewManager = [[SWPBMHiddenWebViewManager alloc] initWithFrame:self.view.frame
                                                                           landingPageString:url];
    [webViewManager openHiddenWebView];
    
    if (!self.viewControllerForPresentingModals) {
        SWPBMLogError(@"self.viewControllerForPresentingModals is nil");
        return NO;
    }
    
    if (@available(iOS 14, *)) {
        
        if (self.viewControllerForPresentingModals.presentedViewController) {
            [self.viewControllerForPresentingModals.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            SKStoreProductViewController *skadnController = [SKStoreProductViewController new];
            skadnController.delegate = self;
            [self.viewControllerForPresentingModals presentViewController:skadnController animated:YES completion:nil];
            [skadnController loadProductWithParameters:productParams completionBlock:^(BOOL result, NSError *error) {
                if (error) {
                    SWPBMLogError(@"Error presenting a product: %@", error.localizedDescription);
                }
            }];
        });
    }

    return YES;
}

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    [self.creativeViewDelegate creativeClickthroughDidClose:self];
}

// Helper methods for resolution success & failure
- (void)onResolutionCompleted {
    @weakify(self);
    dispatch_async(_dispatchQueue, ^{
        @strongify(self);
        if (!self) { return; }
        
        if (self.isDownloaded) {
            return;
        }

        self.isDownloaded = YES;
        
        [self.creativeResolutionDelegate creativeReady:self];
    });
}

- (void)onResolutionFailed:(nonnull NSError *)error {
    @weakify(self);
    dispatch_async(_dispatchQueue, ^{
        @strongify(self);
        if (!self) { return; }
        
        if (self.isDownloaded) {
            return;
        }
        
        self.isDownloaded = YES;
        [self.creativeResolutionDelegate creativeFailed:error];
    });
}

- (void)onViewabilityChanged:(BOOL)viewable viewExposure:(id<SWPBMViewExposure>)viewExposure {
    if (viewable && !self.adWasShown) {
        [self onAdDisplayed];
        self.adWasShown = YES;
    }
}

- (void)pause {
    // Implement in particular creatives
}

- (void)resume {
    // Implement in particular creatives
}

- (void)mute {
    // Implement in particular creatives
}

- (void)unmute {
    // Implement in particular creatives
}

- (BOOL)isMuted {
    return FALSE;
}

- (void)onWillTrackImpression {
    // Implement in particular creatives
}

#pragma mark - SWPBMModalManagerDelegate

- (void)modalManagerDidFinishPop:(id<SWPBMModalState>)state {
    SWPBMLogError(@"Abstract function called");
}

- (void)modalManagerDidLeaveApp:(id<SWPBMModalState>)state {
    SWPBMLogError(@"Abstract function called");
}

#pragma mark - Open Measurement

- (void)createOpenMeasurementSession {
    SWPBMLogError(@"Abstract function called");
}

- (void)onAdDisplayed {
    if (self.transaction.measurementSession.eventTracker) {
        [self.eventManager registerTracker:self.transaction.measurementSession.eventTracker];
    }
    [self.creativeViewDelegate creativeDidDisplay:self];
    [self onWillTrackImpression];
    [self.eventManager trackEvent:SWPBMTrackingEventImpression];
}

@end
