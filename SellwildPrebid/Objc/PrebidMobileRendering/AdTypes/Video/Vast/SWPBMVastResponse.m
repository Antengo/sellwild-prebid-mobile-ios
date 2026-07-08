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

#import "SWPBMVastResponse.h"

#import "SWPBMVastInlineAd.h"
#import "SWPBMVastWrapperAd.h"
#import "SWPBMVastCreativeLinear.h"
#import "SWPBMVastCreativeNonLinearAds.h"
#import "SWPBMVastCreativeCompanionAds.h"

#import "SWSwiftImport.h"

@implementation SWPBMVastResponse

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {        
        self.vastAbstractAds = [NSMutableArray<SWPBMVastAbstractAd *> array];
    }
    return self;
}

//TODO: Check support for adPods
//var adPod = [AnyObject]()


//Flatten response compacts all the chaining <Wrapper> tags in a Vast response.

// <Wrapper> tags can chain but ultimately terminate in an <InLine> tag.
// <Wrapper> tags may have an optional <Creative> tag. If the creative is of type <Linear> or <NonLinear>, then we are to
//take the tracking information and add it to the terminating <InLine> tag's creative.
//If it's of type Companion, then we are to keep the companion in a separate data structure (something we don't currently support)

- (NSArray<SWPBMVastAbstractAd *> *)flattenResponseAndReturnError:(NSError *__autoreleasing  _Nullable *)error {
    
    NSMutableArray *inlineAdAccumulator = [NSMutableArray<SWPBMVastAbstractAd *> array];
    
    for (id ad in self.vastAbstractAds) {
        if ([ad isKindOfClass:[SWPBMVastInlineAd class]]) {
            [inlineAdAccumulator addObject:ad];
        }
        else if ([ad isKindOfClass:[SWPBMVastWrapperAd class]]) {
            SWPBMVastWrapperAd *wrapper = ad;
            
            //If this is a wrapper then we should have a nextResponse child

            SWPBMVastResponse *unwrappedVastResponse = wrapper.vastResponse;
            if (!unwrappedVastResponse) {
                [SWPBMError createError:error message:@"No nextResponse on a wrapper"
                                 type:SWPBMErrorType.serverError];
                return nil;
            }
            
            @try {
                //Start by "flattening" it such that any Wrappers Ads in its ads array are resolved into Inline Ads.
                NSArray *inlineAdsFromWrapper = [unwrappedVastResponse flattenResponseAndReturnError:error];
                
                //Copy our tracking info onto the inline ads
                [unwrappedVastResponse copyTrackingFromWrapper:wrapper toInlineAds:inlineAdsFromWrapper];
                [inlineAdAccumulator addObjectsFromArray:inlineAdsFromWrapper];                
            } @catch (NSException *exception) {
                @throw (exception);
            }
        }
        else {
            NSString *message = [NSString stringWithFormat:@"Encountered unexpected class type: %@", ad];
            [SWPBMError createError:error message:message
                             type:SWPBMErrorType.internalError];
            return nil;
        }
    }
    
    //Post-flattening, we should have at least 1 ad
    if (inlineAdAccumulator.count == 0) {
        [SWPBMError createError:error message:@"No Inline Ads found during wrapper flattening" type:SWPBMErrorType.internalError];
        return nil;
    }
    
    return inlineAdAccumulator.copy;
}

#pragma mark - Private

- (void)copyTrackingFromWrapper:(SWPBMVastWrapperAd *)wrapper toInlineAds:(nonnull NSArray<SWPBMVastInlineAd *> *)inlineAds {
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //We assume that Creatives on Wrapper elements are essentially "fake" and only contain additional tracking
    //information for ads in the child response.
    //We also assume that they can occasionally contain the companion ad creative for ads in the child response,
    //but we don't support that feature.
    //
    //This seems to be a safe assumption of industry practices based on some googling of criticism of the VAST spec:
    //https://www.aerserv.com/vast-wrapper-problems/
    //
    //And IAB's own statements on how Wrapper creatives work:
    //https://www.iab.com/wp-content/uploads/2015/06/VASTv3_0.pdf
    //Which reads:
    //
    //  Since a Wrapper redirects the video player to another server for the Ad, including creative in the
    //  Wrapper is optional. In some cases, the Companion creative for an Ad may be included with resource
    //  files in the Wrapper, while redirecting the video player to another server for the Inline Linear or
    //  NonLinear portion of the Ad.
    //
    //  Creative elements in a Wrapper are typically used to collect tracking information on the InLine creative
    //  that are served subsequent to the Wrapper. If the <Creatives> element is included in the Wrapper,
    //  one or more <Creative> elements may be included (but is not required; an empty <Creatives>
    //  element is acceptable). At most, each <Creative> element may contain one of: <Linear>,
    //  <NonLinearAds>, or <CompanionAds>.
    //
    //  Wrapper creative differ from InLine creative. The following sections describe each in detail.
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    
    //Copy tracking info from this wrapper onto its inline ads.
    for (SWPBMVastInlineAd *inlineAd in inlineAds) {
        
        //Walk the creatives on the wrapper

        for (SWPBMVastCreativeAbstract *wrapperCreative in wrapper.creatives) {
            
            //If the inline ad has any "real" creatives of the same type as the "fake" creatives on the wrapper,
            //copy the "fake" creative's tracking info onto the "real" creative.

            for (SWPBMVastCreativeAbstract *inlineAdCreative in inlineAd.creatives) {
                
                if ([inlineAdCreative isKindOfClass:[SWPBMVastCreativeLinear class]] &&
                    [wrapperCreative isKindOfClass:[SWPBMVastCreativeLinear class]]) {
                    
                    SWPBMVastCreativeLinear *inlineAdSWPBMVastCreativeLinear = (SWPBMVastCreativeLinear*)inlineAdCreative;
                    SWPBMVastCreativeLinear *wrapperAdSWPBMVastCreativeLinear = (SWPBMVastCreativeLinear*)wrapperCreative;
                    [inlineAdSWPBMVastCreativeLinear.clickTrackingURIs addObjectsFromArray:wrapperAdSWPBMVastCreativeLinear.clickTrackingURIs];
                    [inlineAdSWPBMVastCreativeLinear.vastTrackingEvents addTrackingEvents:wrapperAdSWPBMVastCreativeLinear.vastTrackingEvents];
                }
                else if ([inlineAdCreative isKindOfClass:[SWPBMVastCreativeNonLinearAds class]] &&
                         [wrapperCreative isKindOfClass:[SWPBMVastCreativeNonLinearAds class]]) {
                    
                    SWPBMVastCreativeNonLinearAds *inlineAdSWPBMVastCreativeNonLinearAds = (SWPBMVastCreativeNonLinearAds*)inlineAdCreative;
                    SWPBMVastCreativeNonLinearAds *wrapperAdSWPBMVastCreativeNonLinearAds = (SWPBMVastCreativeNonLinearAds*)wrapperCreative;
                    [inlineAdSWPBMVastCreativeNonLinearAds copyTracking:wrapperAdSWPBMVastCreativeNonLinearAds];
                }
                else if ([inlineAdCreative isKindOfClass:[SWPBMVastCreativeCompanionAds class]] &&
                         [wrapperCreative isKindOfClass:[SWPBMVastCreativeCompanionAds class]]) {
                    
                    SWPBMVastCreativeCompanionAds *inlineAdSWPBMVastCreativeCompanionAds = (SWPBMVastCreativeCompanionAds*)inlineAdCreative;
                    SWPBMVastCreativeCompanionAds *wrapperAdSWPBMVastCreativeCompanionAds = (SWPBMVastCreativeCompanionAds*)wrapperCreative;
                    [inlineAdSWPBMVastCreativeCompanionAds copyTracking:wrapperAdSWPBMVastCreativeCompanionAds];
                }
            }
        }
        
        [inlineAd.impressionURIs addObjectsFromArray:wrapper.impressionURIs];
        [inlineAd.errorURIs addObjectsFromArray:wrapper.errorURIs];
    }
}

@end
