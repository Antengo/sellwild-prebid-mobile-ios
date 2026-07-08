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

//MRAID spec URLs:
//https://www.iab.com/wp-content/uploads/2015/08/IAB_MRAID_v2_FINAL.pdf
//https://www.iab.com/wp-content/uploads/2017/07/MRAID_3.0_FINAL.pdf

#import "NSException+SWPBMExtensions.h"
#import "NSString+SWPBMExtensions.h"
#import "UIView+SWPBMExtensions.h"
#import "NSURL+SWPBMExtensions.h"

#import "SWPBMFunctions+Private.h"
#import "SWPBMMRAIDCommand.h"
#import "SWPBMMRAIDConstants.h"
#import "SWPBMMacros.h"
#import "SWPBMModalState.h"
#import "SWPBMOpenMeasurementSession.h"
#import "SWPBMVideoView.h"
#import "SWPBMWebView.h"
#import "SWPBMWebViewDelegate.h"
#import "SWPBMExposureChangeDelegate.h"
#import "SWLog+Extensions.h"

#import "SWPBMMRAIDController.h"

#import "SWSwiftImport.h"

@interface SWPBMMRAIDController () <SWPBMExposureChangeDelegate>

@property (nonatomic, weak)  id<SWPBMAbstractCreative> creative;
@property (nonatomic, weak, nullable) UIViewController* viewControllerForPresentingModals;
@property (nonatomic, weak, nullable) id<SWPBMCreativeViewDelegate> creativeViewDelegate;
@property (nonatomic, copy, nullable) SWPBMCreativeFactoryDownloadDataCompletionClosure downloadBlock;

@property Class deviceAccessManagerClass;

@property (nonatomic, weak) SWPBMWebView *prebidWebView;

@property (nonatomic, assign) BOOL playingMRAIDVideo;
@property (nonatomic, strong) SellwildPrebid* sdkConfiguration;

@property (nonatomic, copy, nullable) SWPBMVoidBlock dismissExpandedModalState;
@property (nonatomic, copy, nullable) SWPBMVoidBlock dismissResizedModalState;

//See the par. 3.1.4 https://www.iab.com/wp-content/uploads/2017/07/MRAID_3.0_FINAL.pdf
//A new state (via sending changeState) must be set
//only *AFTER* the exposureChange event
//we save the new state and will send it after the exposureChange event
@property (nonatomic, nonnull) SWPBMMRAIDState *delayedMraidState;

@end

@implementation SWPBMMRAIDController

+ (BOOL)isMRAIDLink:(nonnull NSString *)urlString {
    return [urlString hasPrefix:SWPBMMRAIDConstants.mraidURLScheme];
}

- (instancetype)initWithCreative:(id<SWPBMAbstractCreative>)creative
     viewControllerForPresenting:(UIViewController*)viewControllerForPresentingModals
                         webView:(SWPBMWebView*)webView
            creativeViewDelegate:(id<SWPBMCreativeViewDelegate>)creativeViewDelegate
                   downloadBlock:(SWPBMCreativeFactoryDownloadDataCompletionClosure)downloadBlock {
    
    self = [self initWithCreative:creative
      viewControllerForPresenting:viewControllerForPresentingModals
                          webView:webView
             creativeViewDelegate:creativeViewDelegate
                    downloadBlock:downloadBlock
         deviceAccessManagerClass:nil
                 sdkConfiguration:SellwildPrebid.shared];
    return self;
}

- (instancetype)initWithCreative:(id<SWPBMAbstractCreative>)creative
     viewControllerForPresenting:(UIViewController*)viewControllerForPresentingModals
                         webView:(SWPBMWebView*)webView
            creativeViewDelegate:(id<SWPBMCreativeViewDelegate>)creativeViewDelegate
                   downloadBlock:(SWPBMCreativeFactoryDownloadDataCompletionClosure)downloadBlock
        deviceAccessManagerClass:(Class)deviceAccessManagerClass
                sdkConfiguration:(SellwildPrebid *)sdkConfiguration
{
    self = [super init];
    if (self) {
        self.creative = creative;
        self.viewControllerForPresentingModals = viewControllerForPresentingModals;
        self.prebidWebView = webView;
        self.prebidWebView.exposureDelegate = self;
        self.creativeViewDelegate = creativeViewDelegate;
        self.downloadBlock = downloadBlock;
        self.deviceAccessManagerClass = (deviceAccessManagerClass) ? deviceAccessManagerClass : [SWPBMDeviceAccessManager class];
        self.sdkConfiguration = sdkConfiguration;
        
        self.mraidState = SWPBMMRAIDState.defaultState;
        self.delayedMraidState = SWPBMMRAIDState.notEnabled;
        self.playingMRAIDVideo = NO;
    }
    return self;
}

- (void)webView:(SWPBMWebView *)webView handleMRAIDURL:(NSURL*)url {
    [self.prebidWebView MRAID_nativeCallComplete];
    @try {
        [self webView:webView handleMRAIDCommand:url];
    } @catch (NSException *exception) {
        SWPBMLogWarn(@"%@", [exception reason]);
    }
}

- (void)webView:(SWPBMWebView *)webView handleMRAIDCommand:(NSURL*)url{
    
    SWPBMMRAIDCommand *swpbmMRAIDCommand = [self commandFromURL:url];
    SWPBMMRAIDAction command = swpbmMRAIDCommand.command;

    // 'unload' is the only command allowed to happen when webView is not viewable
    if ([command isEqualToString:SWPBMMRAIDActionUnload]) {
        [self handleMRAIDCommandUnload];
        return;
    }
    
    if (!webView.viewable) {
        NSString *message = [NSString stringWithFormat:@"MRAID COMMAND: %@ not usable, SWPBMWebView is not viewable)", command];
        @throw [NSException swpbmException:message];
    }
    
    if ([command isEqualToString:SWPBMMRAIDActionOpen]) {
        [self handleMRAIDCommandOpen:swpbmMRAIDCommand];
    } else if ([command isEqualToString:SWPBMMRAIDActionExpand]) {
        [self handleMRAIDCommandExpand:swpbmMRAIDCommand originURL:url];
    } else if ([command isEqualToString:SWPBMMRAIDActionResize]) {
        [self handleMRAIDCommandResize:swpbmMRAIDCommand];
    } else if ([command isEqualToString:SWPBMMRAIDActionClose]) {
        [self handleMRAIDCommandClose];
    } else if ([command isEqualToString:SWPBMMRAIDActionStorePicture]) {
        NSString *message = [NSString stringWithFormat:@"MRAID COMMAND: %@ is not supported", swpbmMRAIDCommand.command];
        @throw [NSException swpbmException:message];
    } else if ([command isEqualToString:SWPBMMRAIDActionCreateCalendarEvent]) {
        NSString *message = [NSString stringWithFormat:@"MRAID COMMAND: %@ is not supported", swpbmMRAIDCommand.command];
        @throw [NSException swpbmException:message];
    } else if ([command isEqualToString:SWPBMMRAIDActionPlayVideo]) {
        [self handleMRAIDCommandPlayVideo:swpbmMRAIDCommand];
    } else if ([command isEqualToString:SWPBMMRAIDActionOnOrientationPropertiesChanged]) {
        [self handleMRAIDCommandOnOrientationPropertiesChanged:swpbmMRAIDCommand];
    } else {
        NSString *message = [NSString stringWithFormat:@"MRAID COMMAND: %@ is not supported", swpbmMRAIDCommand.command];
        @throw [NSException swpbmException:message];
    }
}

- (void)modalManagerDidFinishPop:(id<SWPBMModalState>)state {
    
    //MRAID Video
    if (self.playingMRAIDVideo) {
        // When closing a MRAID video interstitial, only need to set the MRAID state to hidden.
        self.playingMRAIDVideo = NO;
        if (self.mraidState == SWPBMMRAIDState.expanded) {
            [self.prebidWebView changeToMRAIDState:SWPBMMRAIDState.expanded];
        } else {
            [self.prebidWebView changeToMRAIDState:SWPBMMRAIDState.hidden];
        }
        return;
    }
    
    // Just call the host creative
    [self.creative modalManagerDidFinishPop:state];
}

- (void)updateForClose:(BOOL)isInterstitial {
    @weakify(self);
    dispatch_async(dispatch_get_main_queue(), ^{
        @strongify(self);
        
        if (!self) { return; }

        SWPBMMRAIDState *prevState = self.prebidWebView.mraidState;
        [self.prebidWebView updateMRAIDLayoutInfoWithForceNotification:NO];
        if ([prevState isEqual:SWPBMMRAIDState.expanded] || [prevState isEqual:SWPBMMRAIDState.resized]) {
            self.delayedMraidState = SWPBMMRAIDState.defaultState;
        } else {
            [self.prebidWebView changeToMRAIDState:(isInterstitial ? SWPBMMRAIDState.hidden : SWPBMMRAIDState.defaultState)];
        }

        
        // Notify Mraid Collapsed *after* the state has changed and Only if we were Expanded.
        if ([prevState isEqual:SWPBMMRAIDState.expanded]) {
            self.mraidState = SWPBMMRAIDState.defaultState;
            [self.creativeViewDelegate creativeMraidDidCollapse:self.creative];
        }
    });
}

- (void)modalManagerDidLeaveApp:(id<SWPBMModalState>)state {
    [self.creative modalManagerDidLeaveApp:state];
}

//MARK: - SWPBMExposureChangeDelegate protocol

- (BOOL)shouldCheckExposure {
    return ![self.delayedMraidState isEqual:SWPBMMRAIDState.notEnabled];
}

- (void)webView:(SWPBMWebView *)webView exposureChange:(id<SWPBMViewExposure>)viewExposure {
    if (![self.delayedMraidState isEqual:SWPBMMRAIDState.notEnabled]) {
        [self.prebidWebView changeToMRAIDState:self.delayedMraidState];
        self.delayedMraidState = SWPBMMRAIDState.notEnabled;
    }
}

//MARK: - Private methods

- (SWPBMMRAIDCommand*)commandFromURL:(NSURL*)url {
    if (!url) {
        @throw [NSException swpbmException:@"URL is nil"];
        return nil;
    }
    
    NSError *error = nil;
    SWPBMMRAIDCommand *swpbmMRAIDCommand = [[SWPBMMRAIDCommand alloc] initWithURL:[url absoluteString] error:&error];
    if (!swpbmMRAIDCommand) {
        @throw [NSException swpbmException:error.localizedDescription];
    }
    
    return swpbmMRAIDCommand;
}

// If the modal is shown the @viewControllerForPresentingModals would be excluded from the views hierarchy -
// in this case, the system feature won't be opened with an error:
// Attempt to present <UIAlertController: 0x7fb49c013a00> on <PrebidMobileDemoRendering.BannerViewController: 0x7fb499c52f30> whose view is not in the window hierarchy!
// So we should provide different controllers depending on the particular state.
- (UIViewController *)viewControllerForSystemFeaturePresentation {
    UIViewController *controller = nil;
    
    if (self.viewControllerForPresentingModals.isViewLoaded && self.viewControllerForPresentingModals.view.window) {
        controller = self.viewControllerForPresentingModals;
    }
    else {
        controller = (UIViewController *)self.creative.modalManager.modalViewController;
    }
    
    if (!controller) {
        SWPBMLogError(@"There is no controller for presenting system feature.");
    }
    
    return controller;
}

//MARK: - MRAID commands

- (void)handleMRAIDCommandOpen:(SWPBMMRAIDCommand *)command {
    NSString *strURL = command.arguments.firstObject;
    if (!strURL) {
        @throw [NSException swpbmException:@"No arguments to MRAID.open()"];
    }
    
    NSURL *url = [NSURL SWPBMURLWithoutEncodingFromString:strURL];
    if (!url) {
        @throw [NSException swpbmException:[NSString stringWithFormat:@"Could not create URL from string: %@", strURL]];
    }
    
    SWPBMLogInfo(@"Attempting to MRAID.open() url %@", strURL);
    [self.creative handleClickthrough:url];
}

- (void)handleMRAIDCommandExpand:(SWPBMMRAIDCommand *)command originURL:(NSURL *)url {
    if (self.creative.creativeModel.adConfiguration.isInterstitialAd) {
        // 'expand' should have no effect on Interstitial ads.
        // see p.29 of MRAID_3.0_FINAL_June_2018.pdf
        return;
    }
    
    if (self.viewControllerForPresentingModals == nil) {
        @throw [NSException swpbmException:[NSString stringWithFormat:@"self.viewControllerForPresentingModals is nil for expand: %@", url]];
    }
    
    SWPBMWebView *webView = (SWPBMWebView *)self.prebidWebView;
    SWPBMMRAIDState *mraidState = self.prebidWebView.mraidState;
    
    NSArray *allowableStatesForResize = @[SWPBMMRAIDState.defaultState, SWPBMMRAIDState.resized];
    if (![allowableStatesForResize containsObject:mraidState]) {
        @throw [NSException swpbmException:[NSString stringWithFormat:@"MRAID cannot expand from state: %@", mraidState]];
    }
    
    SWPBMInterstitialDisplayProperties *displayProperties = [SWPBMInterstitialDisplayProperties new];
    
    @weakify(self);
    [webView MRAID_getExpandProperties:^(SWPBMMRAIDExpandProperties * _Nullable expandProperties) {
        @strongify(self);
        if (!self) { return; }
        
        if (!expandProperties) {
            [webView MRAID_error:@"Unable to get Expand Properties" action:SWPBMMRAIDActionExpand];
            return;
        }
        
        BOOL const shouldReplace = (self.dismissResizedModalState != nil);
        
        //Check whether we are expanding existing content or expanding to a specific URL.
        NSString *strExpandURL = [[command.arguments firstObject] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (strExpandURL && ![strExpandURL isEqualToString:@""]) {
            //Epanding to a URL
            NSURL *expandURL = [NSURL SWPBMURLWithoutEncodingFromString:strExpandURL];
            if (!expandURL) {
                SWPBMLogError(@"Could not create expand url to: %@", strExpandURL);
                return;
            }
            
            SWPBMWebView *newWebView = [SWPBMWebView new];
            newWebView.delegate = self.prebidWebView.delegate;
            [newWebView expand:expandURL];
            
            @weakify(self);
            
            id<SWPBMModalState> swpbmModalState = [SWPBMFactory createModalStateWithView:newWebView
                                                                   adConfiguration:self.creative.creativeModel.adConfiguration
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
            
            self.dismissExpandedModalState = [self.creative.modalManager pushModal:swpbmModalState fromRootViewController:self.viewControllerForPresentingModals animated:YES shouldReplace:shouldReplace completionHandler:^{
                @strongify(self);
                if (!self) { return; }
                
                // ALSO set the first part (banner) to Expanded per MRAID spec
                self.delayedMraidState = SWPBMMRAIDState.expanded;

                [newWebView prepareForMRAIDWithRootViewController:self.viewControllerForPresentingModals];
                [self.creative.modalManager.modalViewController addFriendlyObstructionsToMeasurementSession:self.creative.transaction.measurementSession];
            }];
        }
        else {
            //Expand existing content.
            @weakify(self);
            id<SWPBMModalState> swpbmModalState = [SWPBMFactory createModalStateWithView:webView
                                                                   adConfiguration:self.creative.creativeModel.adConfiguration
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
            
            self.dismissExpandedModalState = [self.creative.modalManager pushModal:swpbmModalState fromRootViewController:self.viewControllerForPresentingModals animated:YES shouldReplace:shouldReplace completionHandler:^{
                @strongify(self);
                if (!self) { return; }
                
                self.delayedMraidState = SWPBMMRAIDState.expanded;
                [self.creative.modalManager.modalViewController addFriendlyObstructionsToMeasurementSession:self.creative.transaction.measurementSession];
            }];
        }
        
        self.dismissResizedModalState = nil;
        
        // Notify delegates that the MRAID ad has Expanded
        [self.creativeViewDelegate creativeMraidDidExpand:self.creative];
        self.mraidState = SWPBMMRAIDState.expanded;
        [self.creative.eventManager trackEvent:SWPBMTrackingEventClick];
    }];
}

- (void)handleMRAIDCommandResize:(SWPBMMRAIDCommand *)command {
    if (self.creative.creativeModel.adConfiguration.isInterstitialAd) {
        // 'resize' should have no effect on Interstitial ads.
        // see p.29 of MRAID_3.0_FINAL_June_2018.pdf
        return;
    }
    
    if (!self.viewControllerForPresentingModals) {
        @throw [NSException swpbmException:[NSString stringWithFormat:@"self.viewControllerForPresentingModals is nil for mraid command %@", command]];
    }
    
    SWPBMWebView *webView = self.prebidWebView;
    
    SWPBMMRAIDState *mraidState = self.prebidWebView.mraidState;
    
    NSArray *allowableStatesForResize = @[SWPBMMRAIDState.defaultState, SWPBMMRAIDState.resized];
    if (![allowableStatesForResize containsObject:mraidState]) {
        NSString * const message = [NSString stringWithFormat:@"MRAID cannot resize from state: %@", mraidState];
        [webView MRAID_error:message action:SWPBMMRAIDActionResize];
        @throw [NSException swpbmException:message];
    }
    
    @weakify(self);
    [webView MRAID_getResizeProperties:^(SWPBMMRAIDResizeProperties * _Nullable resizeProperties) {
        @strongify(self);
        if (!self) { return; }
        
        if (!resizeProperties) {
            [webView MRAID_error:@"Was unable to get resizeProperties" action:SWPBMMRAIDActionResize];
            return;
        }
        
        SWPBMInterstitialDisplayProperties *displayProperties = [SWPBMInterstitialDisplayProperties new];
        //Make the close button invisible but still tappable.
        [displayProperties setButtonImageHidden];
        
        CGRect frame = [SWPBMMRAIDController CGRectForResizeProperties:resizeProperties fromView:webView];
        if (CGRectIsInfinite(frame)) {
            NSString *message = @"MRAID ad attempted to resize to an invalid size";
            SWPBMLogError(@"%@", message);
            [webView MRAID_error:message action:SWPBMMRAIDActionResize];
            return;
        }
        
        displayProperties.contentFrame = frame;
        displayProperties.contentViewColor = [UIColor clearColor];
        webView.backgroundColor = [UIColor clearColor];
        
        //If we're resizing from an already resized state, the content should replace the existing content rather than
        //push on top of the existing InterstitialState stack.
        BOOL shouldReplace = [mraidState isEqual:SWPBMMRAIDState.resized];
        
        @weakify(self);
        id<SWPBMModalState> swpbmModalState = [SWPBMFactory createModalStateWithView:webView
                                                               adConfiguration:self.creative.creativeModel.adConfiguration
                                                             displayProperties:displayProperties
                                                            onStatePopFinished:^(id<SWPBMModalState> _Nonnull poppedState) {
            @strongify(self);
            if (!self) { return; }
            
            [self modalManagerDidFinishPop:poppedState];
        } onStateHasLeftApp:^(id<SWPBMModalState> _Nonnull leavingState) {
            @strongify(self);
            if (!self) { return;  }
            
            [self modalManagerDidLeaveApp:leavingState];
        } nextOnStatePopFinished:nil nextOnStateHasLeftApp:nil onModalPushedBlock:nil];
        swpbmModalState.mraidState = SWPBMMRAIDState.resized;
        
        self.dismissResizedModalState = [self.creative.modalManager pushModal:swpbmModalState
              fromRootViewController:self.viewControllerForPresentingModals
                            animated:NO
                       shouldReplace:shouldReplace
                   completionHandler:^{
            @strongify(self);
            if (!self) { return; }
            
            self.mraidState = SWPBMMRAIDState.resized;
            self.delayedMraidState = SWPBMMRAIDState.resized;
            
            [self.creative.modalManager.modalViewController addFriendlyObstructionsToMeasurementSession:self.creative.transaction.measurementSession];
        }];
        
        [self.creative.eventManager trackEvent:SWPBMTrackingEventClick];
    }];
}

- (void)handleMRAIDCommandClose {
    SWPBMVoidBlock dismissModalStateBlock = nil;
    if (self.creative.transaction.adConfiguration.presentAsInterstitial) {
        dismissModalStateBlock = self.creative.dismissInterstitialModalState;
    } else if (self.mraidState == SWPBMMRAIDState.expanded) {
        dismissModalStateBlock = self.dismissExpandedModalState;
        self.dismissExpandedModalState = nil;
    } else if (self.mraidState == SWPBMMRAIDState.resized) {
        dismissModalStateBlock = self.dismissResizedModalState;
        self.dismissResizedModalState = nil;
    }
    if (dismissModalStateBlock) {
        dismissModalStateBlock();
    }
}

- (void)handleMRAIDCommandUnload {
    SWPBMLogWhereAmI();
    id<SWPBMAbstractCreative> const creative = self.creative;
    switch (self.prebidWebView.state) {
        case SWPBMWebViewStateLoaded: {
            if (self.creative.transaction.adConfiguration.presentAsInterstitial) {
                [self handleMRAIDCommandClose];
                break;
            }
            if (self.mraidState == SWPBMMRAIDState.expanded || self.mraidState == SWPBMMRAIDState.resized) {
                [self handleMRAIDCommandClose];
            }
            id<SWPBMCreativeViewDelegate> const delegate = creative.creativeViewDelegate;
            [delegate creativeDidComplete:creative];
            break;
        }
        case SWPBMWebViewStateLoading: {
            id<SWPBMCreativeResolutionDelegate> const delegate = creative.creativeResolutionDelegate;
            [delegate creativeFailed:[SWPBMError errorWithDescription:@"The Ad called 'mraid.unload();'"]];
            break;
        }
        default:
            break;
    }
}

- (void)handleMRAIDCommandPlayVideo:(SWPBMMRAIDCommand *)command {
    // TODO: This pattern seems flawed, `playVideo/` will pass this argument and URL check.
    NSString *strURL = [command.arguments firstObject];
    if (!strURL) {
        @throw [NSException swpbmException:@"Insufficient arguments for MRAIDAction.playVideo"];
    }
    
    NSURL *url = [NSURL SWPBMURLWithoutEncodingFromString:strURL];
    if (!url) {
        NSString *message = [NSString stringWithFormat:@"MRAID attempted to load an invalid URL: %@", strURL];
        @throw [NSException swpbmException:message];
    }
    
    if (!self.viewControllerForPresentingModals) {
        NSString *message = [NSString stringWithFormat:@"self.viewControllerForPresentingModals is nil"];
        @throw [NSException swpbmException:message];
    }
    
    self.playingMRAIDVideo = YES;
    
    //TODO: MRAID video should probably stream instead of pre-download.
    [self loadVideo:url];
}

- (void)handleMRAIDCommandOnOrientationPropertiesChanged:(SWPBMMRAIDCommand *)command {
    
    NSString *jsonString = [command.arguments firstObject];
    if (!jsonString) {
        @throw [NSException swpbmException:@"onOrientationPropertiesChanged - No JSON string"];
    }
    
    NSError *error;
    SWPBMJsonDictionary *jsonDict = [SWPBMFunctions dictionaryFromJSONString:jsonString error:&error];
    if (!jsonDict) {
        NSString *message = [NSString stringWithFormat:@"onOrientationPropertiesChanged - Unable to parse JSON string: %@", jsonString];
        @throw [NSException swpbmException:message];
    }
    
    NSString *strForceOrientation = jsonDict[@"forceOrientation"];
    if (!strForceOrientation) {
        return;
    }
    
    if ([strForceOrientation isEqualToString:SWPBMMRAIDValues.LANDSCAPE]) {
        [self.creative.modalManager forceOrientation:UIInterfaceOrientationLandscapeLeft];
    } else if ([strForceOrientation isEqualToString:SWPBMMRAIDValues.PORTRAIT]) {
        [self.creative.modalManager forceOrientation:UIInterfaceOrientationPortrait];
    }
    
    //Note: we currently ignore the allowOrientationChange property as there does not yet exist
    //an elegant way to disable rotation on the navigation controller that the publisher shows
    //the ad interstitial VC from.
}

- (void)loadVideo:(NSURL *)url {
    @weakify(self);
    self.downloadBlock(url, ^(NSData * _Nullable data, NSError * _Nullable error) {
        @strongify(self);
        if (!self) { return; }
        
        if (error) {
            SWPBMLogError(@"Unable to load MRAID video. Error: %@", error);
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // Create a container view. This will stretch to fit the available space.
            UIView* containerView = [[UIView alloc] initWithFrame:CGRectZero];
            
            SWPBMVideoView *videoView = [[SWPBMVideoView alloc] initWithEventManager:self.creative.eventManager];
            [videoView showMediaFileURL:url preloadedData:data];
            
            [containerView addSubview:videoView];
            
            [videoView SWPBMAddFillSuperviewConstraints];
            
            @weakify(self);
            __weak SWPBMVideoView * weakVideoView = videoView;
            
            id<SWPBMModalState> state = [SWPBMFactory createModalStateWithView:containerView
                                                           adConfiguration:self.creative.creativeModel.adConfiguration
                                                         displayProperties:[SWPBMInterstitialDisplayProperties new]
                                                        onStatePopFinished:^(id<SWPBMModalState> _Nonnull poppedState) {
                @strongify(self);
                if (!self) { return; }
                [self modalManagerDidFinishPop:poppedState];
            } onStateHasLeftApp:^(id<SWPBMModalState> _Nonnull leavingState) {
                @strongify(self);
                if (!self) { return; }
                
                [self modalManagerDidLeaveApp:leavingState];
            } nextOnStatePopFinished:^(id<SWPBMModalState> _Nonnull poppedState) {
                [weakVideoView modalManagerDidFinishPop:poppedState];
            } nextOnStateHasLeftApp:^(id<SWPBMModalState> _Nonnull leavingState) {
                [weakVideoView modalManagerDidLeaveApp:leavingState];
            } onModalPushedBlock:^{
                [videoView pause];
            }];
            
            [self.creative.modalManager pushModal:state
                  fromRootViewController:self.viewControllerForPresentingModals
                                animated:YES shouldReplace:NO completionHandler:^{
                @strongify(self);
                if (!self) { return; }
                
                [videoView startPlayback];
                [self.creative.modalManager.modalViewController addFriendlyObstructionsToMeasurementSession:self.creative.transaction.measurementSession];
            }];
            
            [self.creative.eventManager trackEvent:SWPBMTrackingEventClick];
        });
    });
}

+ (CGRect)CGRectForResizeProperties:(SWPBMMRAIDResizeProperties *)properties fromView:(UIView *)fromView {
    if (!properties) {
        return CGRectInfinite;
    }
    
    // check that the resize fits into the bounds of what's allowed
    if (properties.width < 50 || properties.height < 50) {
        return CGRectInfinite;
    }
    
    // get the view's absolute position
    if (!fromView.superview) {
        SWPBMLogInfo(@"Could not determine a global point");
        return CGRectInfinite;
    }
    
    CGPoint globalPoint = [fromView.superview convertPoint:fromView.frame.origin toView:nil];
    
    // calc the resized rect based on global offset and resize properties
    CGRect basicRect = CGRectMake((NSInteger)globalPoint.x + properties.offsetX, (NSInteger)globalPoint.y + properties.offsetY, properties.width, properties.height);
    SWPBMLogInfo(@"basicRect = %@", NSStringFromCGRect(basicRect));
    
    // if offscreen is allowed, return with it
    if (properties.allowOffscreen) {
        if ([SWPBMMRAIDController isValidCloseRegionPosition:basicRect]) {
            return basicRect;
        } else {
            return CGRectInfinite;
        }
    }
    
    // else, check if it can fit on screen
    CGSize screenSize = [SWPBMFunctions deviceScreenSize];
    if (basicRect.size.width > screenSize.width || basicRect.size.height > basicRect.size.height) {
        return CGRectInfinite;
    }
    
    // move it fully onscreen
    if (basicRect.origin.x < 0) {
        basicRect.origin.x = 0;
    }
    
    if (basicRect.origin.y < 0) {
        basicRect.origin.y = 0;
    }
    
    if (basicRect.origin.x + basicRect.size.width > screenSize.width) {
        basicRect.origin.x = screenSize.width - basicRect.size.width;
    }
    
    if (basicRect.origin.y + basicRect.size.height > screenSize.height) {
        basicRect.origin.y = screenSize.height - basicRect.size.height;
    }
    
    return basicRect;
}

+ (BOOL)isValidCloseRegionPosition:(CGRect)basicRect {
    //Check the position of the close region
    //https://www.iab.com/wp-content/uploads/2017/07/MRAID_3.0_FINAL.pdf p.37
    //The host must always include a 50x50 density independent pixel close event
    //region. Recommended position is the top right corner of the container provided for the ad.
    CGFloat closeRegionX = basicRect.origin.x + basicRect.size.width - SWPBMMRAIDCloseButtonSize.WIDTH;
    CGRect closeRegion = (CGRect){.origin.x = closeRegionX, .origin.y = basicRect.origin.y,
                                  .size.width = SWPBMMRAIDCloseButtonSize.WIDTH, .size.height = SWPBMMRAIDCloseButtonSize.HEIGHT};
    
    CGSize deviceMaxSize = [SWPBMFunctions deviceMaxSize];
    UIEdgeInsets saInsets = [SWPBMFunctions safeAreaInsets];
    CGRect safeArea = (CGRect){
        .origin.x = saInsets.left,
        .origin.y = saInsets.top + [SWPBMFunctions statusBarHeight],
        .size = deviceMaxSize
    };
    
    return CGRectContainsRect(safeArea, closeRegion);
}

@end
