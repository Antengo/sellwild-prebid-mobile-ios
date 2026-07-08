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

#import "SWPBMVastParser.h"

#import "SWPBMVastGlobals.h"
#import "SWPBMVastResponse.h"
#import "SWPBMVastInlineAd.h"
#import "SWPBMVastWrapperAd.h"
#import "SWPBMVastAbstractAd.h"
#import "SWPBMVastCreativeLinear.h"
#import "SWPBMVastCreativeNonLinearAds.h"
#import "SWPBMVastCreativeCompanionAds.h"
#import "SWPBMVastResourceContainerProtocol.h"
#import "SWPBMVastIcon.h"
#import "SWPBMVastCreativeCompanionAdsCompanion.h"
#import "SWPBMVastCreativeNonLinearAdsNonLinear.h"
#import "SWLog+Extensions.h"

#import "SWSwiftImport.h"

@interface SWPBMVastParser ()

@property (nonatomic, assign) BOOL parseSuccessful;

@end

@implementation SWPBMVastParser

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        self.parseSuccessful = false;
        self.currentElementName = @"";
        self.currentElementContent = @"";
        self.elementPath = [NSMutableArray array];
    }
    return self;
}

- (SWPBMVastResponse *)parseAdsResponse:(NSData *)data {
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.delegate = self;
    
    self.currentElementContext = @"";
    self.elementPath = [NSMutableArray array];
    [parser parse];
    
    return self.parseSuccessful ? self.parsedResponse : nil;
}

//The Companion, and NonLinear and Icon tags can all have StaticResource, IFrameResource and
//HTMLResource tag children. To represent this, the SWPBMVastIcon,
//SWPBMVastCreativeCompanionAdsCompanion, and SWPBMVastCreativeNonLinearAdsNonLinear classes
//all conform to SWPBMVastResourceContainer.
-(void)parseResourceForType:(SWPBMVastResourceType)type {
    
    if (!self.creative) {
        SWPBMLogError(@"No applicable creative");
        return;
    }
    
    id <SWPBMVastResourceContainerProtocol> container = [self extractCreativeContainer];

    //Bail if unsuccessful
    if (!container) {
        SWPBMLogError(@"No applicable container to apply currentElementContent of [%@] to. Type is %ld.",
                    self.currentElementContent, (long)type);
        return;
    }
    
    //Fill out SWPBMVastResourceContainer fields
    container.resourceType = type;
    container.resource = self.currentElementContent;
    if (type == SWPBMVastResourceTypeStaticResource) {
        container.staticType = self.currentElementAttributes[@"creativeType"];
    }
}

- (BOOL)parseBool:(NSString *)str {
    if (!str) {
        return false;
    }
    return [str isEqualToString: @"true"];
}

- (NSInteger)parseInt:(NSString *)str {
    if (!str) {
        return 0;
    }
    return str.integerValue;
}

- (float)parseFloat:(NSString *)str {
    if (!str) {
        return 0;
    }
    return str.floatValue;
}

-(NSTimeInterval)parseTimeInterval:(NSString *)str {
    if (!str) {
        return 0;
    }
    
    NSArray *components = [[[str componentsSeparatedByString:@":"] reverseObjectEnumerator] allObjects];
    NSTimeInterval totalSeconds = 0;
    NSInteger componentIndex = 0;
    
    for (NSString *component in components) {
        switch (componentIndex) {
            case 0: totalSeconds += component.doubleValue; break; //Seconds
            case 1: totalSeconds += component.doubleValue * 60; break; //Minutes
            case 2: totalSeconds += component.doubleValue * 60 * 60; break; //Hours
                
            default: {
                SWPBMLogError(@"Unable to parse time string: %@", str);
                return 0;
            }
        }
        
        componentIndex += 1;
    }
    
    return totalSeconds;
}

- (NSString *)parseString:(NSString *)str {
    if (!str) {
        return @"";
    }
    return str;
}

-(NSNumber *)parseSkipOffset:(NSString *)str {
    if (!str) {
        return nil;
    }
    
    NSTimeInterval interval = [self parseTimeInterval:str];
    return [NSNumber numberWithDouble:interval];
}

#pragma mark - NSXMLParserDelegate

-(void)parserDidStartDocument:(NSXMLParser *)parser {
    self.parsedResponse = [SWPBMVastResponse new];
}

-(void)parserDidEndDocument:(NSXMLParser *)parser {
    // sent when the parser has completed parsing. If this is encountered, the parse was successful.
    self.parseSuccessful = YES;
}

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary<NSString *,NSString *> *)attributeDict {
    
    // sent when the parser finds an element start tag.
    
    [self.elementPath addObject:elementName];
    self.currentElementName = elementName;
    self.currentElementAttributes = attributeDict;
    self.currentElementContent = @"";
    
    if ([elementName isEqualToString:@"VAST"]) {
        self.parsedResponse.version = attributeDict[@"version"];
    }
    else if ([elementName isEqualToString: @"Ad"]) {
        self.adAttributes = attributeDict;
    }
    else if ([elementName isEqualToString: @"InLine"]) {
        self.inlineAd = [SWPBMVastInlineAd new];
        self.ad = self.inlineAd;
    }
    else if ([elementName isEqualToString: @"Wrapper"]) {
        
        SWPBMVastWrapperAd *swpbmWrapperAd = [SWPBMVastWrapperAd new];
        
        id followAdditionalWrappersKey = attributeDict[@"followAdditionalWrappers"];
        if (followAdditionalWrappersKey) {
            swpbmWrapperAd.followAdditionalWrappers = [self parseBool:followAdditionalWrappersKey];
        }
        
        id allowMultipleAdsKey = attributeDict[@"allowMultipleAds"];
        if (allowMultipleAdsKey) {
            swpbmWrapperAd.allowMultipleAds = [self parseBool:allowMultipleAdsKey];
        }
        
        id fallbackOnNoAdKey = attributeDict[@"fallbackOnNoAd"];
        if (fallbackOnNoAdKey) {
            swpbmWrapperAd.fallbackOnNoAd = [self parseBool:fallbackOnNoAdKey];
        }
        
        self.wrapperAd = swpbmWrapperAd;
        self.ad = swpbmWrapperAd;
    }
    else if ([elementName isEqualToString: @"Creative"]) {
        self.creativeAttributes = attributeDict;
    }
    else if ([elementName isEqualToString: @"Linear"]) {
        SWPBMVastCreativeLinear *creative = [SWPBMVastCreativeLinear new];
        creative.skipOffset = [self parseSkipOffset:attributeDict[@"skipoffset"]];
        self.creative = creative;
    }
    else if ([elementName isEqualToString: @"CompanionAds"]) {
        SWPBMVastCreativeCompanionAds *creative = [SWPBMVastCreativeCompanionAds new];
        creative.requiredMode = [self parseString:attributeDict[@"required"]];
        self.creative = creative;
    }
    else if ([elementName isEqualToString: @"Companion"]) {
        SWPBMVastCreativeCompanionAds *swpbmVastCreativeCompanionAds = (SWPBMVastCreativeCompanionAds*) self.creative;
        if (!swpbmVastCreativeCompanionAds) {
            SWPBMLogError(@"Error - expected current creative to be SWPBMVastCreativeCompanionAds");
            return;
        }
        
        SWPBMVastCreativeCompanionAdsCompanion *companion = [SWPBMVastCreativeCompanionAdsCompanion new];
        companion.companionIdentifier = attributeDict[@"id"];
        companion.width = [self parseInt: attributeDict[@"width"]];
        companion.height = [self parseInt: attributeDict[@"height"]];
        companion.assetWidth = [self parseInt: attributeDict[@"assetWidth"]];
        companion.assetHeight = [self parseInt: attributeDict[@"assetHeight"]];
        [swpbmVastCreativeCompanionAds.companions addObject:companion];
    }
    else if ([elementName isEqualToString: @"NonLinearAds"]) {
        self.creative = [SWPBMVastCreativeNonLinearAds new];
    }
    else if ([elementName isEqualToString: @"NonLinear"]) {
        SWPBMVastCreativeNonLinearAds *swpbmVastCreativeNonLinearAds = (SWPBMVastCreativeNonLinearAds*) self.creative;
        if (!swpbmVastCreativeNonLinearAds) {
            SWPBMLogError(@"Expected current creative to be SWPBMVastCreativeNonLinearAds");
            return;
        }
        
        SWPBMVastCreativeNonLinearAdsNonLinear *swpbmVastCreativeNonLinearAdsNonLinear = [SWPBMVastCreativeNonLinearAdsNonLinear new];
        swpbmVastCreativeNonLinearAdsNonLinear.identifier = attributeDict[@"id"];
        swpbmVastCreativeNonLinearAdsNonLinear.width = [self parseInt: attributeDict[@"width"]];
        swpbmVastCreativeNonLinearAdsNonLinear.height = [self parseInt: attributeDict[@"height"]];
        swpbmVastCreativeNonLinearAdsNonLinear.assetWidth = [self parseInt: attributeDict[@"assetWidth"]];
        swpbmVastCreativeNonLinearAdsNonLinear.assetHeight = [self parseInt: attributeDict[@"assetHeight"]];
        swpbmVastCreativeNonLinearAdsNonLinear.scalable = [self parseBool: attributeDict[@"scalable"]];
        swpbmVastCreativeNonLinearAdsNonLinear.maintainAspectRatio = [self parseBool: attributeDict[@"maintainAspectRatio"]];
        swpbmVastCreativeNonLinearAdsNonLinear.minSuggestedDuration = [self parseTimeInterval: attributeDict[@"minSuggestedDuration"]];
        swpbmVastCreativeNonLinearAdsNonLinear.apiFramework = attributeDict[@"apiFramework"];
        [swpbmVastCreativeNonLinearAds.nonLinears addObject:swpbmVastCreativeNonLinearAdsNonLinear];
    }
    else if ([elementName isEqualToString: @"Icon"]) {
        SWPBMVastCreativeLinear *swpbmVastCreativeLinear = (SWPBMVastCreativeLinear*) self.creative;
        if (!swpbmVastCreativeLinear) {
            SWPBMLogError(@"Icon found, but current creative is not SWPBMVastCreativeLinear");
            return;
        }
        
        SWPBMVastIcon *icon = [SWPBMVastIcon new];
        icon.program = [self parseString: attributeDict[@"program"]];
        icon.width = [self parseInt: attributeDict[@"width"]];
        icon.height = [self parseInt: attributeDict[@"height"]];
        icon.xPosition = [self parseInt: attributeDict[@"xPosition"]];
        icon.yPosition = [self parseInt: attributeDict[@"yPosition"]];
        icon.duration = [self parseTimeInterval: attributeDict[@"duration"]];
        icon.startOffset = [self parseTimeInterval: attributeDict[@"startOffset"]];
        [swpbmVastCreativeLinear.icons addObject: icon];
    }
    else if ([elementName isEqualToString: @"MediaFile"]) {
        SWPBMVastCreativeLinear *swpbmVastCreativeLinear = (SWPBMVastCreativeLinear*) self.creative;
        if (!swpbmVastCreativeLinear) {
            SWPBMLogError(@"MediaFile found, but current creative is not SWPBMVastCreativeLinear");
            return;
        }
        
        SWPBMVastMediaFile *swpbmVastMediaFile = [SWPBMVastMediaFile new];
        swpbmVastMediaFile.id = attributeDict[@"id"];
        [swpbmVastMediaFile setDeliver:attributeDict[@"delivery"]];
        swpbmVastMediaFile.type = [self parseString: attributeDict[@"type"]];
        swpbmVastMediaFile.width = [self parseInt: attributeDict[@"width"]];
        swpbmVastMediaFile.height = [self parseInt: attributeDict[@"height"]];
        swpbmVastMediaFile.codec = attributeDict[@"codec"];
        swpbmVastMediaFile.apiFramework = attributeDict[@"apiFramework"];

        // After porting to Objective-C such casting will be omitted
        swpbmVastMediaFile.bitrate = [NSNumber numberWithFloat:[self parseFloat:attributeDict[@"bitrate"]]];
        swpbmVastMediaFile.minBitrate = [NSNumber numberWithFloat:[self parseFloat:attributeDict[@"minBitrate"]]];
        swpbmVastMediaFile.maxBitrate = [NSNumber numberWithFloat:[self parseFloat:attributeDict[@"maxBitrate"]]];
        swpbmVastMediaFile.scalable = [NSNumber numberWithBool:[self parseBool:attributeDict[@"scalable"]]];
        swpbmVastMediaFile.maintainAspectRatio = [NSNumber numberWithBool:[self parseBool:attributeDict[@"maintainAspectRatio"]]];
        [swpbmVastCreativeLinear.mediaFiles addObject:swpbmVastMediaFile];
    }
    else if ([elementName isEqualToString: @"AdVerifications"]) {
        self.verificationParameter = [SWPBMVideoVerificationParameters new];
    }
    else if ([elementName isEqualToString: @"Verification"]) {
        self.verificationResource = [SWPBMVideoVerificationResource new];
        self.verificationResource.vendorKey = attributeDict[@"vendor"];
    }
    else if ([elementName isEqualToString: @"JavaScriptResource"]) {
        self.verificationResource.apiFramework = attributeDict[@"apiFramework"];
    }
    //Unsupported:
    //else if ([elementName isEqualToString: @"ExecutableResource"]) {
    //}
    //else if ([elementName isEqualToString: @"VerificationParameters"]) {
    //}
}

-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if ([elementName isEqualToString: @"Error"]) {
        if ([[self.elementPath subarrayWithRange:NSMakeRange(0, 2)] isEqual: @[@"VAST", @"Ad"]]) {
            [self.ad.errorURIs addObject:self.currentElementContent];
        }
        else if ([self.elementPath isEqual:@[@"VAST", @"Ad"]]) {
            self.parsedResponse.noAdsResponseURI = self.currentElementContent;
        }
    }
    else if ([elementName isEqualToString: @"AdSystem"]) {
        self.ad.adSystem = self.currentElementContent;
        self.ad.adSystemVersion = [self parseString: self.currentElementAttributes[@"version"]];
    }
    else if ([elementName isEqualToString: @"AdParameters"]) {
        self.creative.adParameters = self.currentElementContent;
    }
    else if ([elementName isEqualToString: @"AdTitle"]) {
        self.inlineAd.title = self.currentElementContent;
    }
    else if ([elementName isEqualToString: @"Advertiser"]) {
        self.inlineAd.advertiser = self.currentElementContent;
    }
    else if ([elementName isEqualToString: @"Impression"]) {
        [self.ad.impressionURIs addObject:self.currentElementContent];
    }
    else if ([elementName isEqualToString: @"Ad"]) {
        if (self.ad) {
            SWPBMVastAbstractAd *unwrappedAd = self.ad;
            unwrappedAd.identifier = [self parseString: self.adAttributes[@"id"]];
            
            if (self.adAttributes[@"sequence"]) {
                NSString *strSequence = self.adAttributes[@"sequence"];
                if (strSequence.intValue) {
                    unwrappedAd.sequence = strSequence.intValue;
                }
            }
            
            unwrappedAd.ownerResponse = self.parsedResponse;
            
            NSMutableArray *ads = [NSMutableArray arrayWithArray:self.parsedResponse.vastAbstractAds];
            [ads addObject:unwrappedAd];
            self.parsedResponse.vastAbstractAds = ads;
        }
        else {
            SWPBMLogError(@"Ad tag ending with no ad object.");
        }
        
        self.inlineAd = nil;
        self.wrapperAd = nil;
        self.ad = nil;
        self.adAttributes = nil;
    }
    else if ([elementName isEqualToString: @"Creative"]) {
        self.creative.identifier = self.creativeAttributes[@"id"];
        self.creative.adId = self.creativeAttributes[@"AdID"];
        
        if (self.creativeAttributes[@"sequence"]) {
            NSString *strSequence = self.creativeAttributes[@"sequence"];
            if (strSequence.intValue) {
                self.creative.sequence = strSequence.intValue;
            }
        }
        
        // doubleclick can produce empty Creative nodes
        if (self.creative) {
            [self.ad.creatives addObject:self.creative];
        }
        
        self.creative = nil;
        self.creativeAttributes = nil;
    }
    else if ([elementName isEqualToString: @"Tracking"]) {
        NSString *event = self.currentElementAttributes[@"event"];
        if (!event) {
            return;
        }
        
        SWPBMVastTrackingEvents *vastTrackingEvents = nil;
        
        if ([self.creative isKindOfClass: [SWPBMVastCreativeCompanionAds class]]) {
            SWPBMVastCreativeCompanionAds *swpbmVastCreativeCompanionAds = (SWPBMVastCreativeCompanionAds*)self.creative;
            if (swpbmVastCreativeCompanionAds.companions.count) {
                SWPBMVastCreativeCompanionAdsCompanion *companion = swpbmVastCreativeCompanionAds.companions.lastObject;
                vastTrackingEvents = companion.trackingEvents;
            }
        }
        else if ([self.creative isKindOfClass: [SWPBMVastCreativeLinear class]]) {
            SWPBMVastCreativeLinear *swpbmVastCreativeLinear = (SWPBMVastCreativeLinear*)self.creative;
            vastTrackingEvents = swpbmVastCreativeLinear.vastTrackingEvents;
        }
        else if ([self.creative isKindOfClass: [SWPBMVastCreativeNonLinearAds class]]) {
            SWPBMVastCreativeNonLinearAds *swpbmVastCreativeNonLinearAds = (SWPBMVastCreativeNonLinearAds*)self.creative;
            if (swpbmVastCreativeNonLinearAds.nonLinears.count) {
                SWPBMVastCreativeNonLinearAdsNonLinear *nonLinear = swpbmVastCreativeNonLinearAds.nonLinears.lastObject;
                vastTrackingEvents = nonLinear.vastTrackingEvents;
            }
        }
        else if (self.verificationResource) {
            if (!self.verificationResource.trackingEvents) {
                self.verificationResource.trackingEvents = [SWPBMVastTrackingEvents new];
            }
            
            vastTrackingEvents = self.verificationResource.trackingEvents;
        }
        
        if (!vastTrackingEvents) {
            SWPBMLogError(@"No suitable tracking events object found to append contents of Tracking tag to");
            return;
        }
        
        [vastTrackingEvents addTrackingURL:self.currentElementContent event:event attributes:self.currentElementAttributes];
    }
    else if ([elementName isEqualToString: @"AdVerifications"]) {
        self.inlineAd.verificationParameters = self.verificationParameter;
        self.verificationParameter = nil;
    }
    else if ([elementName isEqualToString: @"Verification"]) {
        __auto_type verificationResources = self.verificationParameter.verificationResources;
        verificationResources = [verificationResources arrayByAddingObject:self.verificationResource];
        self.verificationParameter.verificationResources = verificationResources;
        
        self.verificationResource = nil;
    }
    else if ([elementName isEqualToString: @"JavaScriptResource"]) {
        self.verificationResource.url = self.currentElementContent;
    }
    // else if ([elementName isEqualToString: @"ExecutableResource"]) {
        // Unsuported
    // }
    else if ([elementName isEqualToString: @"VerificationParameters"]) {
        self.verificationResource.params = self.currentElementContent;
    }
    else if ([elementName isEqualToString: @"Duration"]) {
        SWPBMVastCreativeLinear *swpbmVastCreativeLinear = (SWPBMVastCreativeLinear*)self.creative;
        if (swpbmVastCreativeLinear) {
            swpbmVastCreativeLinear.duration = self.currentElementContent ? [self parseTimeInterval: self.currentElementContent] : 0;
        }
        else {
            SWPBMLogError(@"Duration tag found but creative not SWPBMVastCreativeLinear");
        }
    }
    else if ([elementName isEqualToString: @"ClickThrough"]) {
        SWPBMVastCreativeLinear *swpbmVastCreativeLinear = (SWPBMVastCreativeLinear*)self.creative;
        if (swpbmVastCreativeLinear) {
            swpbmVastCreativeLinear.clickThroughURI = self.currentElementContent;
        }
        else {
            SWPBMLogError(@"Clickthrough tag found but creative not SWPBMVastCreativeLinear");
        }
    }
    else if ([elementName isEqualToString: @"MediaFile"]) {
        SWPBMVastCreativeLinear *swpbmVastCreativeLinear = (SWPBMVastCreativeLinear*)self.creative;
        if (swpbmVastCreativeLinear) {
            if (swpbmVastCreativeLinear.mediaFiles.count) {
                SWPBMVastMediaFile *mediaFile = swpbmVastCreativeLinear.mediaFiles.lastObject;
                mediaFile.mediaURI = self.currentElementContent;
            }
        }
        else {
            SWPBMLogError(@"MediaFile tag found but creative not SWPBMVastCreativeLinear");
        }
    }
    else if ([elementName isEqualToString: @"StaticResource"]) {
        [self parseResourceForType:SWPBMVastResourceTypeStaticResource];
    }
    else if ([elementName isEqualToString: @"IFrameResource"]) {
        [self parseResourceForType:SWPBMVastResourceTypeIFrameResource];
    }
    else if ([elementName isEqualToString: @"HTMLResource"]) {
        [self parseResourceForType:SWPBMVastResourceTypeHtmlResource];
    }
    else if ([elementName isEqualToString: @"ClickTracking"] || [elementName isEqualToString: @"CustomClick"]) {
        SWPBMVastCreativeLinear *swpbmVastCreativeLinear = (SWPBMVastCreativeLinear*)self.creative;
        if (!swpbmVastCreativeLinear) {
            SWPBMLogError(@"%@ tag found but creative not SWPBMVastCreativeLinear", elementName);
            return;
        }
        [swpbmVastCreativeLinear.clickTrackingURIs addObject:_currentElementContent];
    }
    else if ([elementName isEqualToString: @"IconClickThrough"]) {
        SWPBMVastCreativeLinear *swpbmVastCreativeLinear = (SWPBMVastCreativeLinear*)self.creative;
        if (!swpbmVastCreativeLinear) {
            SWPBMLogError(@"IconClickThrough tag found but creative not SWPBMVastCreativeLinear");
            return;
        }
        
        if (swpbmVastCreativeLinear.icons.count) {
            SWPBMVastIcon *icon = swpbmVastCreativeLinear.icons.lastObject;
            icon.clickThroughURI = self.currentElementContent;
        }
    }
    else if ([elementName isEqualToString: @"IconClickTracking"]) {
        SWPBMVastCreativeLinear *swpbmVastCreativeLinear = (SWPBMVastCreativeLinear*)self.creative;
        if (!swpbmVastCreativeLinear) {
            SWPBMLogError(@"IconClickTracking tag found but creative not SWPBMVastCreativeLinear");
            return;
        }
        
        if (swpbmVastCreativeLinear.icons.count) {
            SWPBMVastIcon *icon = swpbmVastCreativeLinear.icons.lastObject;
            [icon.clickTrackingURIs addObject:self.currentElementContent];
        }
    }
    else if ([elementName isEqualToString: @"IconViewTracking"]) {
        SWPBMVastCreativeLinear *swpbmVastCreativeLinear = (SWPBMVastCreativeLinear*)self.creative;
        if (!swpbmVastCreativeLinear) {
            SWPBMLogError(@"IconViewTracking tag found but creative not SWPBMVastCreativeLinear");
            return;
        }
        
        if (swpbmVastCreativeLinear.icons.count) {
            SWPBMVastIcon *icon = swpbmVastCreativeLinear.icons.lastObject;
            icon.viewTrackingURI = self.currentElementContent;
        }
    }
    else if ([elementName isEqualToString: @"CompanionClickThrough"]) {
        SWPBMVastCreativeCompanionAds *swpbmVastCreativeCompanionAds = (SWPBMVastCreativeCompanionAds*)self.creative;
        if (!swpbmVastCreativeCompanionAds) {
            SWPBMLogError(@"CompanionClickThrough tag found but creative not SWPBMVastCreativeCompanionAds");
            return;
        }
        
        if (swpbmVastCreativeCompanionAds.companions.count) {
            SWPBMVastCreativeCompanionAdsCompanion *companion = swpbmVastCreativeCompanionAds.companions.lastObject;
            companion.clickThroughURI = self.currentElementContent;
        }
    }
    else if ([elementName isEqualToString: @"CompanionClickTracking"]) {
        SWPBMVastCreativeCompanionAds *swpbmVastCreativeCompanionAds = (SWPBMVastCreativeCompanionAds*)self.creative;
        if (!swpbmVastCreativeCompanionAds) {
            SWPBMLogError(@"CompanionClickTracking tag found but creative not SWPBMVastCreativeCompanionAds");
            return;
        }
        
        if (swpbmVastCreativeCompanionAds.companions.count) {
            SWPBMVastCreativeCompanionAdsCompanion *companion = swpbmVastCreativeCompanionAds.companions.lastObject;
            [companion.clickTrackingURIs addObject:self.currentElementContent];
        }
    }
    else if ([elementName isEqualToString: @"NonLinearClickThrough"]) {
        SWPBMVastCreativeNonLinearAds *swpbmVastCreativeNonLinearAds = (SWPBMVastCreativeNonLinearAds*)self.creative;
        if (!swpbmVastCreativeNonLinearAds) {
            SWPBMLogError(@"NonLinearClickThrough tag found but creative not SWPBMVastCreativeNonLinearAds");
            return;
        }
        
        if (swpbmVastCreativeNonLinearAds.nonLinears.count) {
            SWPBMVastCreativeNonLinearAdsNonLinear *swpbmVastCreativeNonLinearAdsNonLinear = swpbmVastCreativeNonLinearAds.nonLinears.lastObject;
            swpbmVastCreativeNonLinearAdsNonLinear.clickThroughURI = self.currentElementContent;
        }
        else {
            SWPBMLogError(@"NonLinearClickThrough tag found but no NonLinear objects to append content to");
        }
    }
    else if ([elementName isEqualToString: @"NonLinearClickTracking"]) {
        SWPBMVastCreativeNonLinearAds *swpbmVastCreativeNonLinearAds = (SWPBMVastCreativeNonLinearAds*)self.creative;
        if (!swpbmVastCreativeNonLinearAds) {
            SWPBMLogError(@"NonLinearClickTracking tag found but creative not SWPBMVastCreativeNonLinearAds");
            return;
        }
        
        if (swpbmVastCreativeNonLinearAds.nonLinears.count) {
            SWPBMVastCreativeNonLinearAdsNonLinear *swpbmVastCreativeNonLinearAdsNonLinear = swpbmVastCreativeNonLinearAds.nonLinears.lastObject;
            [swpbmVastCreativeNonLinearAdsNonLinear.clickTrackingURIs addObject:self.currentElementContent];
        }
        else {
            SWPBMLogError(@"NonLinearClickTracking tag found but no NonLinear objects to append content to");
        }
    }
    else if ([elementName isEqualToString: @"VASTAdTagURI"]) {
        self.wrapperAd.vastURI = self.currentElementContent;
    }
    
    if (self.elementPath.count > 0) {
        [self.elementPath removeLastObject];
    }
    else {
        SWPBMLogError(@"elementPath unexpectedly empty");
    }
    
    self.currentElementAttributes = nil;
}

-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    NSString *trimmedString = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.currentElementContent = [self.currentElementContent stringByAppendingString: trimmedString];
}

-(void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock {
    // this reports a CDATA block to the delegate as an NSData.
    NSString *string = [[NSString alloc] initWithData:CDATABlock encoding:NSUTF8StringEncoding];
    if (!string) {
        return;
    }
    
    //Trim CDATA Blocks. Normally you don't alter CDATA blocks at all, but we're getting URLs
    //padded with whitespace inside of CDATA blocks.
    NSString *trimmedString = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.currentElementContent = [self.currentElementContent stringByAppendingString: trimmedString];
}

#pragma mark - Helper Methods

- (id <SWPBMVastResourceContainerProtocol>)extractCreativeContainer {
    id <SWPBMVastResourceContainerProtocol> container = nil;
    
    if ([self.creative isKindOfClass: [SWPBMVastCreativeLinear class]]) {
        SWPBMVastCreativeLinear *swpbmVastCreativeLinear = (SWPBMVastCreativeLinear*)self.creative;
        if ([swpbmVastCreativeLinear.icons.lastObject isKindOfClass:[SWPBMVastIcon class]]) {
            container = swpbmVastCreativeLinear.icons.lastObject;
        }
    }
    else if ([self.creative isKindOfClass: [SWPBMVastCreativeCompanionAds class]]) {
        SWPBMVastCreativeCompanionAds *swpbmVastCreativeCompanionAds = (SWPBMVastCreativeCompanionAds*)self.creative;
        if ([swpbmVastCreativeCompanionAds.companions.lastObject isKindOfClass:[SWPBMVastCreativeCompanionAdsCompanion class]]) {
            container = swpbmVastCreativeCompanionAds.companions.lastObject;
        }
    }
    else if ([self.creative isKindOfClass: [SWPBMVastCreativeNonLinearAds class]]) {
        SWPBMVastCreativeNonLinearAds *swpbmVastNonLinearCreative = (SWPBMVastCreativeNonLinearAds*)self.creative;
        if ([swpbmVastNonLinearCreative.nonLinears.lastObject isKindOfClass:[SWPBMVastCreativeNonLinearAdsNonLinear class]]) {
            container = swpbmVastNonLinearCreative.nonLinears.lastObject;
        }
    }
    
    return container;
}

@end
