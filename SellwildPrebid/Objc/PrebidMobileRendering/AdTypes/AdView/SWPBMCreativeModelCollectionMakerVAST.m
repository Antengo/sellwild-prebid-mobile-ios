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

#import "SWPBMCreativeModelCollectionMakerVAST.h"
#import "SWPBMVastCreativeCompanionAdsCompanion.h"
#import "SWPBMVastCreativeLinear.h"
#import "SWPBMVastInlineAd.h"
#import "SWPBMVastParser.h"
#import "SWPBMVastResponse.h"
#import "SWPBMAdRequestResponseVAST.h"
#import "SWPBMVastCreativeCompanionAds.h"
#import "SWPBMFunctions+Private.h"

#import "SWSwiftImport.h"


@implementation SWPBMCreativeModelCollectionMakerVAST

- (instancetype)initWithServerConnection:(id<PrebidServerConnectionProtocol>)serverConnection
                            adConfiguration:(SWPBMAdConfiguration *)adConfiguration {
    self = [super init];
    if (self) {
        self.adConfiguration = adConfiguration;
        self.serverConnection = serverConnection;
    }
    
    return self;
}

- (void)makeModels:(SWPBMAdRequestResponseVAST *) adRequestResponse
   successCallback:(SWPBMCreativeModelMakerSuccessCallback) successCallback
   failureCallback:(SWPBMCreativeModelMakerFailureCallback)failureCallback {
    
    SWPBMAdRequestResponseVAST *vastResponse = (SWPBMAdRequestResponseVAST*) adRequestResponse;
    
    NSError* error = nil;
    NSArray<SWPBMCreativeModel *> *models = [self createCreativeModelsFromResponse:vastResponse.ads error:&error];

    if (error) {
        failureCallback(error);
        return;
    }
    
    successCallback(models);
}

#pragma mark - Internal Methods


- (NSArray<SWPBMCreativeModel *> *)createCreativeModelsFromResponse:(NSArray<SWPBMVastAbstractAd *> *)ads
                                                            error:(NSError **)error {
    NSString *errorMessage = @"No creative";
    NSMutableArray <SWPBMCreativeModel *> *creatives = [NSMutableArray <SWPBMCreativeModel *> new];
    SWPBMVastInlineAd *vastAd = (SWPBMVastInlineAd *)ads.firstObject;
    
    if (vastAd.creatives == nil || vastAd.creatives.count == 0) {
        [SWPBMError createError:error description:errorMessage statusCode:SWPBMErrorCodeGeneralLinear];
        return nil;
    }
    
    // Create the Linear Creative Model
    SWPBMVastCreativeLinear *creative = (SWPBMVastCreativeLinear*)vastAd.creatives.firstObject;
    if (creative == nil) {
        [SWPBMError createError:error description:errorMessage statusCode:SWPBMErrorCodeGeneralLinear];
        return nil;
    }
    
    SWPBMVastMediaFile *bestMediaFile = [creative bestMediaFile];
    if (bestMediaFile == nil) {
        errorMessage = @"No suitable media file";
        [SWPBMError createError:error description:errorMessage statusCode:SWPBMErrorCodeFileNotFound];
        return nil;
    }
    
    SWPBMCreativeModel *creativeModel = [self createCreativeModelWithAd:vastAd creative:creative mediaFile:bestMediaFile error:error];
    if (creativeModel == nil) {
        return nil;
    }

    [creatives addObject:creativeModel];
    
    // Creative the Companion Ads creative model
    // Per the Vast spec, we have either 1 Linear or NonLinear, the rest are the companion ads/end cards.
    NSMutableArray<SWPBMVastCreativeCompanionAds *> *companionItems = [NSMutableArray<SWPBMVastCreativeCompanionAds *> new];
    for (SWPBMVastCreativeCompanionAds* item in vastAd.creatives) {
        if ([item isKindOfClass:[SWPBMVastCreativeCompanionAds class]]) {
            [companionItems addObject:item];
        }
    }
    
    if (companionItems.count > 0) {
        // Now try to create the companion items creatives.
        // Create a model of the best fitting companion ad.
        SWPBMCreativeModel *creativeModelCompanion = [self createCompanionCreativeModelWithAd:vastAd
                                                                               companionAds:companionItems
                                                                                   creative:creative];
        if (creativeModelCompanion) {
            // There is at least 1 companion.  Set the flag so that when the initial video creative has completed
            // display, the appropriate view controllers will prevent the "close" button and the learn more after the video has
            // finished, it will instead display the endcard.
            creativeModel.hasCompanionAd = YES;
            [creatives addObject:creativeModelCompanion];
        }
    }
    
    return creatives;
}

- (SWPBMCreativeModel *)createCreativeModelWithAd:(SWPBMVastInlineAd *)vastAd
                                       creative:(SWPBMVastCreativeLinear *)creative
                                      mediaFile:(SWPBMVastMediaFile *)mediaFile
                                          error:(NSError **)error {

    if (!creative.duration || creative.duration <= 0) {
        NSString *errorMessage = @"Creative duration is invalid";
        [SWPBMError createError:error description:errorMessage statusCode:SWPBMErrorCodeGeneral];
        return nil;
    }
    
    if (self.adConfiguration.videoControlsConfig.maxVideoDuration && creative.duration > self.adConfiguration.videoControlsConfig.maxVideoDuration.doubleValue) {
        NSString *errorMessage = @"Creative duration is bigger than maximum available playback time obtained from server response.";
        [SWPBMError createError:error description:errorMessage statusCode:SWPBMErrorCodeGeneral];
        return nil;
    } else if (self.adConfiguration.videoParameters.maxDuration.value && creative.duration > self.adConfiguration.videoParameters.maxDuration.value) {
        NSString *errorMessage = @"Creative duration is bigger than maximum available playback time set by the user.";
        [SWPBMError createError:error description:errorMessage statusCode:SWPBMErrorCodeGeneral];
        return nil;
    }

    SWPBMCreativeModel *creativeModel = [[SWPBMCreativeModel alloc] initWithAdConfiguration:self.adConfiguration];
    creativeModel.eventTracker = [[SWPBMAdModelEventTracker alloc] initWithCreativeModel:creativeModel serverConnection:self.serverConnection];
    creativeModel.verificationParameters = vastAd.verificationParameters;

    //Pack successful data into a CreativeModel
    creativeModel.videoFileURL = mediaFile.mediaURI;
    creativeModel.displayDurationInSeconds = [NSNumber numberWithDouble: creative.duration];
    creativeModel.skipOffset = creative.skipOffset;
    creativeModel.width = mediaFile.width;
    creativeModel.height = mediaFile.height;
    
    NSMutableDictionary *trackingURLs = [creative.vastTrackingEvents.trackingEvents mutableCopy];
    
    // Store the impression URIs so that can be fired at the appropriate time.
    NSString *impressionKey = [SWPBMTrackingEventDescription getDescription:SWPBMTrackingEventImpression];
    trackingURLs[impressionKey] = vastAd.impressionURIs;
    NSString *clickKey = [SWPBMTrackingEventDescription getDescription:SWPBMTrackingEventClick];
    trackingURLs[clickKey] = creative.clickTrackingURIs;
    
    creativeModel.trackingURLs = trackingURLs;
    creativeModel.clickThroughURL = creative.clickThroughURI;
    
    return creativeModel;
}

- (SWPBMCreativeModel *)createCompanionCreativeModelWithAd:(SWPBMVastInlineAd *)vastAd
                                            companionAds:(NSArray<SWPBMVastCreativeCompanionAds *>*)companionAds
                                                creative:(SWPBMVastCreativeLinear *)creative {
    if ((companionAds == nil) || (creative == nil)) {
        return nil;
    }
    
    if (companionAds.count == 0) {
        return nil;
    }
    
    SWPBMCreativeModel *creativeModel = [[SWPBMCreativeModel alloc] initWithAdConfiguration:self.adConfiguration];
    creativeModel.eventTracker = [[SWPBMAdModelEventTracker alloc] initWithCreativeModel:creativeModel serverConnection:self.serverConnection];
    creativeModel.verificationParameters = vastAd.verificationParameters;

    SWPBMVastCreativeCompanionAds* companionAd = [companionAds firstObject];
    if (companionAd.companions.count == 0) {
        return nil;
    }
    
    // get the most appropriate companion from the list.
    SWPBMVastCreativeCompanionAdsCompanion* companion = [self getMostAppropriateCompanion: companionAd];
    if (companion == nil) {
        return nil;
    }
    NSString* resource;
    switch (companion.resourceType) {
        case SWPBMVastResourceTypeStaticResource:
            // image. build html around resource
            resource = [self buildStaticResource:companion];
            break;
        case SWPBMVastResourceTypeIFrameResource:
            resource = companion.resource;
            break;
        case SWPBMVastResourceTypeHtmlResource:
            resource = companion.resource;
            break;
        default:
            // unrecognized companion type.
            return nil;
    }
    
    if (!resource) {
        return nil;
    }

    creativeModel.html = resource;
    creativeModel.width = companion.width;
    creativeModel.height = companion.height;
    creativeModel.clickThroughURL = companion.clickThroughURI;
    
    // Store the impression URIs so that can be fired at the appropriate time.
    NSMutableDictionary *trackingURLs = [companion.trackingEvents.trackingEvents mutableCopy];
    NSString *companionClickKey = [SWPBMTrackingEventDescription getDescription:SWPBMTrackingEventCompanionClick];

    NSMutableArray *trackingArray = trackingURLs[companionClickKey];
    // Create a companion array if it doesn't already exist.
    if (trackingURLs[companionClickKey] == nil) {
        trackingArray = [NSMutableArray new];
    }
    // Save the the tracking urls in the array.
    trackingURLs[companionClickKey] = [trackingArray arrayByAddingObjectsFromArray:companion.clickTrackingURIs];
    
    NSString *clickKey = [SWPBMTrackingEventDescription getDescription:SWPBMTrackingEventClick];
    trackingURLs[clickKey] = companion.clickTrackingURIs;

    creativeModel.trackingURLs = trackingURLs;

    // tag this creative model as an end card.
    creativeModel.isCompanionAd = YES;
    return creativeModel;
 }

- (SWPBMVastCreativeCompanionAdsCompanion*) getMostAppropriateCompanion: (SWPBMVastCreativeCompanionAds*) companionAd {
    // currently we only return the first option.
    // Todo: add additional logic for the most appropriate using the following:
    //  * size
    //  * type
    SWPBMVastCreativeCompanionAdsCompanion* companion;

    companion = [companionAd.companions firstObject];
    return companion;
}

- (NSString*) buildStaticResource: (SWPBMVastCreativeCompanionAdsCompanion*)companion {
    if (companion == nil) {
        return nil;
    }
    
    NSString * html = [NSString stringWithFormat:PrebidConstants.companionHTMLTemplate, companion.clickThroughURI, companion.resource];
    
    return html;
}

@end
