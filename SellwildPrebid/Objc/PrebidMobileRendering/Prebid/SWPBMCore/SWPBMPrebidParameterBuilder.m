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

#import "SWPBMPrebidParameterBuilder.h"

#import "SWPBMORTB.h"

#import "SWPBMBidRequesterFactoryBlock.h"
#import "SWPBMWinNotifierBlock.h"

#import "SWPBMORTBAppExt.h"

#import "SWPBMFunctions.h"
#import "SWLog+Extensions.h"

#import "SWSwiftImport.h"

@interface SWPBMPrebidParameterBuilder ()

@property (nonatomic, strong, nonnull, readonly) AdUnitConfig *adConfiguration;
@property (nonatomic, strong, nonnull, readonly) SellwildPrebid *sdkConfiguration;
@property (nonatomic, strong, nonnull, readonly) Targeting *targeting;
@property (nonatomic, strong, nonnull, readonly) SWPBMUserAgentService *userAgentService;

@end

@implementation SWPBMPrebidParameterBuilder

- (instancetype)initWithAdConfiguration:(AdUnitConfig *)adConfiguration
                       sdkConfiguration:(SellwildPrebid *)sdkConfiguration
                              targeting:(Targeting *)targeting
                       userAgentService:(SWPBMUserAgentService *)userAgentService
{
    if (!(self = [super init])) {
        return nil;
    }
    _adConfiguration = adConfiguration;
    _sdkConfiguration = sdkConfiguration;
    _targeting = targeting;
    _userAgentService = userAgentService;
    return self;
}

- (void)buildBidRequest:(nonnull SWPBMORTBBidRequest *)bidRequest {
    
    NSSet<AdFormat *> *adFormats = self.adConfiguration.adConfiguration.adFormats;
    BOOL const isHTML = ([adFormats containsObject:AdFormat.banner]);
    BOOL const isInterstitial = self.adConfiguration.adConfiguration.isInterstitialAd;
    
    NSString *requestID = self.sdkConfiguration.prebidServerAccountId;
    NSString *settingsID = self.sdkConfiguration.auctionSettingsId;
    if (settingsID) {
        if ([[settingsID stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) {
            SWPBMLogWarn(@"Auction settings Id is invalid. Prebid Server Account Id will be used.");
        } else {
            requestID = settingsID;
        }
    }
    
    bidRequest.requestID = [NSUUID UUID].UUIDString;
    bidRequest.extPrebid.storedRequestID        = requestID;
    bidRequest.extPrebid.storedAuctionResponse  = SellwildPrebid.shared.storedAuctionResponse;
    bidRequest.extPrebid.dataBidders            = self.targeting.accessControlList;
    bidRequest.extPrebid.storedBidResponses     = [SellwildPrebid.shared getStoredBidResponses];

    if (!self.adConfiguration.adConfiguration.isOriginalAPI) {
        bidRequest.extPrebid.sdkRenderers = [PrebidMobilePluginRegister.shared getAllPluginsJSONRepresentation];
    }

    if (SellwildPrebid.shared.pbsDebug) {
        bidRequest.test = @1;
    }
    
    if (SellwildPrebid.shared.useCacheForReportingWithRenderingAPI || SellwildPrebid.shared.requireServerSideBidCache) {
        SWPBMMutableJsonDictionary * const cache = [SWPBMMutableJsonDictionary new];
        cache[@"bids"] = [SWPBMMutableJsonDictionary new];
        cache[@"vastxml"] = [SWPBMMutableJsonDictionary new];
        bidRequest.extPrebid.cache = cache;
    }
    
    // For multiformat ad units we should get hb_format in PBS response.
    // In order to do this, we shoould specify ext.prebid.targeting.includeformat
    if (adFormats.count >= 2) {
        bidRequest.extPrebid.targeting[@"includeformat"] = [[NSNumber alloc] initWithBool:YES];
    }

    if(SellwildPrebid.shared.includeWinners)
    {
        bidRequest.extPrebid.targeting[@"includewinners"] = [[NSNumber alloc] initWithBool:YES];
    }

    if(SellwildPrebid.shared.includeBidderKeys)
    {
        bidRequest.extPrebid.targeting[@"includebidderkeys"] = [[NSNumber alloc] initWithBool:YES];
    }
    
    bidRequest.app.publisher.publisherID        = self.sdkConfiguration.prebidServerAccountId;
    bidRequest.app.ver          = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
    bidRequest.device.pxratio   = @([UIScreen mainScreen].scale);
    bidRequest.source.tid       = [NSUUID UUID].UUIDString;
    bidRequest.device.ua        = self.userAgentService.userAgent;
    
    if (self.targeting.gdprConsentString && self.targeting.gdprConsentString.length > 0) {
        bidRequest.user.ext[@"consent"] = self.targeting.gdprConsentString;
    }

    SWPBMORTBSourceExtOMID *extSource = [SWPBMORTBSourceExtOMID new];
    
    if (!self.adConfiguration.adConfiguration.isOriginalAPI) {
        extSource.omidpn = @"Prebid";
        extSource.omidpv = [SWPBMFunctions sdkVersion];
    }
    
    if (Targeting.shared.omidPartnerName) {
        extSource.omidpn = Targeting.shared.omidPartnerName;
    }
    
    if (Targeting.shared.omidPartnerVersion) {
        extSource.omidpv = Targeting.shared.omidPartnerVersion;
    }

    bidRequest.source.extOMID = extSource;

    NSArray<SWPBMORTBFormat *> *formats = nil;
    const NSInteger formatsCount = (CGSizeEqualToSize(self.adConfiguration.adSize, CGSizeZero) ? 0 : 1) + self.adConfiguration.additionalSizes.count;
    
    if (formatsCount > 0) {
        NSMutableArray<SWPBMORTBFormat *> * const newFormats = [[NSMutableArray alloc] initWithCapacity:formatsCount];
        if (!CGSizeEqualToSize(self.adConfiguration.adSize, CGSizeZero)) {
            NSValue *value = [NSValue valueWithCGSize:self.adConfiguration.adSize];
            [newFormats addObject:[SWPBMPrebidParameterBuilder ortbFormatWithSize: value]];
        }
        for (NSValue *nextSize in self.adConfiguration.additionalSizes) {
            [newFormats addObject:[SWPBMPrebidParameterBuilder ortbFormatWithSize:nextSize]];
        }
        formats = newFormats;
    } else if (isInterstitial) {
        if (self.adConfiguration.minSizePerc && isHTML) {
            const CGSize minSizePerc = self.adConfiguration.minSizePerc.CGSizeValue;
            SWPBMORTBDeviceExtPrebidInterstitial * const interstitial = bidRequest.device.extPrebid.interstitial;
            interstitial.minwidthperc = @(minSizePerc.width);
            interstitial.minheightperc = @(minSizePerc.height);
        }
    }
    
    SWPBMORTBAppExt * const appExt = bidRequest.app.ext;
    SWPBMORTBAppExtPrebid * const appExtPrebid = appExt.prebid;
    
    if ([self.targeting getAppExtData].count > 0) {
        appExt.data = [self.targeting getAppExtData];
    }
    
    for (SWPBMORTBImp *nextImp in bidRequest.imp) {
        nextImp.impID = [NSUUID UUID].UUIDString;
        nextImp.extPrebid.storedRequestID = self.adConfiguration.configId;
        nextImp.extPrebid.storedAuctionResponse = SellwildPrebid.shared.storedAuctionResponse;
        nextImp.extGPID = self.adConfiguration.gpid;
        
        nextImp.extPrebid.isRewardedInventory = self.adConfiguration.adConfiguration.isRewarded;
        if (self.adConfiguration.adConfiguration.isRewarded) {
            nextImp.rewarded = @(1);
        }
        
        NSString * pbAdSlot = [self.adConfiguration getPbAdSlot];
        
        nextImp.extData[@"pbadslot"] = pbAdSlot;
        
        for (AdFormat* adFormat in adFormats) {
            if (adFormat == AdFormat.banner) {
                SWPBMORTBBanner * const nextBanner = nextImp.banner;
            
                BannerParameters *bannerParameters = self.adConfiguration.adConfiguration.bannerParameters;
                NSMutableArray<SWPBMORTBFormat *> *mergedFormats = [NSMutableArray new];
                
                if (formats) {
                    [mergedFormats addObjectsFromArray:formats];
                }
                
                if (bannerParameters.adSizes && bannerParameters.adSizes.count > 0) {
                    for (NSValue *sizeValue in bannerParameters.adSizes) {
                        [mergedFormats addObject:[SWPBMPrebidParameterBuilder ortbFormatWithSize:sizeValue]];
                    }
                }
                
                NSArray<SWPBMORTBFormat *> *uniqueFormats = [[NSSet setWithArray:mergedFormats] allObjects];
                if (uniqueFormats.count > 0) {
                    nextBanner.format = uniqueFormats;
                }

                if (bannerParameters.api && bannerParameters.api.count > 0) {
                    nextBanner.api = bannerParameters.rawAPI;
                }
                
                if (self.adConfiguration.adPosition != SWPBMAdPositionUndefined) {
                    nextBanner.pos = @(self.adConfiguration.adPosition);
                }
            } else if (adFormat == AdFormat.video) {
                SWPBMORTBVideo * const nextVideo = nextImp.video;
                
                if (!self.adConfiguration.adConfiguration.isOriginalAPI) {
                    if (self.adConfiguration.adConfiguration.isInterstitialAd) {
                        nextVideo.playbackend = @(1);
                    } else {
                        nextVideo.playbackend = @(2);
                    }
                    nextVideo.pos = @(7);
                    nextVideo.protocols = @[@(2),@(5)];
                    nextVideo.mimes = PrebidConstants.SUPPORTED_VIDEO_MIME_TYPES;
                }
                
                nextVideo.delivery = @[@(3)];
                
                if (formats.count) {
                    SWPBMORTBFormat * const primarySize = (SWPBMORTBFormat *)formats[0];
                    nextVideo.w = primarySize.w;
                    nextVideo.h = primarySize.h;
                }
                
                VideoParameters *videoParameters = self.adConfiguration.adConfiguration.videoParameters;
                                
                if (videoParameters.api && videoParameters.api.count > 0) {
                    nextVideo.api = videoParameters.rawAPI;
                }
                
                if (videoParameters.maxBitrate) {
                    nextVideo.maxbitrate = [NSNumber numberWithInteger:videoParameters.maxBitrate.value];
                }
                
                if (videoParameters.minBitrate) {
                    nextVideo.minbitrate = [NSNumber numberWithInteger:videoParameters.minBitrate.value];
                }
                
                if (videoParameters.maxDuration) {
                    nextVideo.maxduration = [NSNumber numberWithInteger:videoParameters.maxDuration.value];
                }
                
                if (videoParameters.minDuration) {
                    nextVideo.minduration = [NSNumber numberWithInteger:videoParameters.minDuration.value];
                }
                
                if (videoParameters.mimes && videoParameters.mimes.count > 0) {
                    nextVideo.mimes = videoParameters.mimes;
                }
                
                if (videoParameters.playbackMethod && videoParameters.playbackMethod.count > 0) {
                    nextVideo.playbackmethod = videoParameters.rawPlaybackMethod;
                }
                
                if (videoParameters.protocols && videoParameters.protocols.count > 0) {
                    nextVideo.protocols = videoParameters.rawProtocols;
                }
                
                if (videoParameters.startDelay) {
                    nextVideo.startdelay = [NSNumber numberWithInteger:videoParameters.startDelay.value];
                }
                
                if (videoParameters.placement) {
                    nextVideo.placement = [NSNumber numberWithInteger:videoParameters.placement.value];
                }
                
                if (videoParameters.plcmnt) {
                    nextVideo.plcmt = [NSNumber numberWithInteger:videoParameters.plcmnt.value];
                }
                
                if (videoParameters.linearity) {
                    nextVideo.linearity = [NSNumber numberWithInteger:videoParameters.linearity.value];
                }
                
                if (videoParameters.battr && videoParameters.battr.count > 0) {
                    nextVideo.battr = videoParameters.rawBattrs;
                }

                if (videoParameters.rawSkippable) {
                    nextVideo.skip = videoParameters.rawSkippable;
                }
                
                if (self.adConfiguration.adPosition != SWPBMAdPositionUndefined) {
                    nextVideo.pos = @(self.adConfiguration.adPosition);
                }
            } else if (adFormat == AdFormat.native) {
                SWPBMORTBNative * const nextNative = nextImp.native;
                nextNative.request = [self.adConfiguration.nativeAdConfiguration.markupRequestObject toJsonStringWithError:nil];
                NSString * const ver = self.adConfiguration.nativeAdConfiguration.version;
                if (ver) {
                    nextNative.ver = ver;
                }
            }
        }
        
        if (isInterstitial) {
            nextImp.instl = @(1);
        }
        
        if (!appExtPrebid.source) {
            appExtPrebid.source = @"prebid-mobile";
        }
        
        if (!appExtPrebid.version) {
            appExtPrebid.version = SellwildPrebid.shared.version;
        }
    }
}

+ (SWPBMORTBFormat *)ortbFormatWithSize:(NSValue *)size {
    SWPBMORTBFormat * const format = [[SWPBMORTBFormat alloc] init];
    CGSize const cgSize = size.CGSizeValue;
    format.w = @(cgSize.width);
    format.h = @(cgSize.height);
    return format;
}

@end
