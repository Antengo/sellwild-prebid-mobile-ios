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

#import <UIKit/UIKit.h>
#import "SWPBMMRAIDJavascriptCommands.h"
#import "SWPBMFunctions+Private.h"
#import "SWLog+Extensions.h"

#import "SWSwiftImport.h"

#pragma mark - Constants

static NSString * const SWPBMMRAIDCommandFormatSize = @"%@:%@";

#pragma mark - Private Extension

@interface SWPBMMRAIDJavascriptCommands ()

@property (class, readonly) NSNumberFormatter* floatFormatter;

@end

#pragma mark - Implementation

@implementation SWPBMMRAIDJavascriptCommands

#pragma mark - command functions

+ (nonnull NSString *)isEnabled {
    return @"typeof mraid !== 'undefined'";
}

+ (nonnull NSString *)nativeCallComplete {
    return [NSString stringWithFormat:@"mraid.nativeCallComplete();"];
}

#pragma mark - SDK state change functions

+ (nonnull NSString *)onReady {
    return @"mraid.onReady();";
}

+ (nonnull NSString *)onReadyExpanded {
    return @"mraid.onReadyExpanded();";
}

+ (nonnull NSString *)onViewableChange:(BOOL)isViewable {
    NSString *strIsViewable = isViewable ? @"true" : @"false";
    return [NSString stringWithFormat:@"mraid.onViewableChange(%@);", strIsViewable];
}

+ (NSString *)onExposureChange:(id<SWPBMViewExposure>)viewExposure {
    return [NSString stringWithFormat:@"mraid.onExposureChange(\"%@\");", [viewExposure serializeWithFormatter:[SWPBMMRAIDJavascriptCommands floatFormatter]]];
}

+ (nonnull NSString *)onSizeChange:(CGSize)newSize {
    return [NSString stringWithFormat:@"mraid.onSizeChange(%@,%@);", [SWPBMMRAIDJavascriptCommands formatFloat:newSize.width], [SWPBMMRAIDJavascriptCommands formatFloat:newSize.height]];
}

+ (nonnull NSString *)onStateChange:(nonnull SWPBMMRAIDState *)newState {
    return [NSString stringWithFormat:@"mraid.onStateChange('%@');",newState];
}

+ (nonnull NSString *)onAudioVolumeChange:(NSNumber *)volumePercentage {
    return [NSString stringWithFormat:@"mraid.onAudioVolumeChange(%@);",
            volumePercentage == nil ? @"null" : [SWPBMMRAIDJavascriptCommands formatFloat:volumePercentage.floatValue]];
}

#pragma mark - update Ad data

+ (nonnull NSString *)updateSupportedFeatures {
    NSString *features = [SWPBMMRAIDJavascriptCommands getSupportedFeatureString];
    return [NSString stringWithFormat:@"mraid.allSupports = %@;", features];
}

+ (nonnull NSString *)updatePlacementType:(SWPBMMRAIDPlacementType)type {
    return [NSString stringWithFormat:@"mraid.placementType = '%@';", type];
}

+ (nonnull NSString *)updateMaxSize:(CGSize)newMaxSize {
    return [NSString stringWithFormat:@"mraid.setMaxSize(%@,%@);", [SWPBMMRAIDJavascriptCommands formatFloat:newMaxSize.width], [SWPBMMRAIDJavascriptCommands formatFloat:newMaxSize.height]];
}

+ (nonnull NSString *)updateCurrentAppOrientation:(NSString *)orientation locked:(BOOL)locked{
    return [NSString stringWithFormat:@"mraid.setCurrentAppOrientation('%@', %@);",
            orientation, locked ? @"true" : @"false"];
}

+ (nonnull NSString *)updateScreenSize:(CGSize)newScreenSize {
    NSString * width = [NSString stringWithFormat:SWPBMMRAIDCommandFormatSize, SWPBMMRAIDParseKeys.WIDTH, [SWPBMMRAIDJavascriptCommands formatFloat:newScreenSize.width]];
    NSString * height = [NSString stringWithFormat:SWPBMMRAIDCommandFormatSize, SWPBMMRAIDParseKeys.HEIGHT, [SWPBMMRAIDJavascriptCommands formatFloat:newScreenSize.height]];

    return [NSString stringWithFormat:@"mraid.screenSize = {%@,%@};", width, height];
}

+ (nonnull NSString *)updateDefaultPosition:(CGRect)position {
    NSString *strPosition = [SWPBMMRAIDJavascriptCommands getRectString:position];
    return [NSString stringWithFormat:@"mraid.defaultPosition = %@;", strPosition];
}

+ (nonnull NSString *)updateCurrentPosition:(CGRect)position {
    NSString *strPosition = [SWPBMMRAIDJavascriptCommands getRectString:position];
    return [NSString stringWithFormat:@"mraid.currentPosition = %@;", strPosition];
}

+ (nonnull NSString *)updateLocation:(CLLocationCoordinate2D)coordinate accuracy:(CLLocationAccuracy)accuracy  timeStamp:(NSTimeInterval)timeStamp {
    return [NSString stringWithFormat:@"mraid.setLocation(%@,%@,%@,%@);",
                [SWPBMMRAIDJavascriptCommands formatFloat:coordinate.latitude],
                [SWPBMMRAIDJavascriptCommands formatFloat:coordinate.longitude],
                [SWPBMMRAIDJavascriptCommands formatFloat:accuracy],
                [SWPBMMRAIDJavascriptCommands formatFloat:timeStamp]
            ];
}

#pragma mark - get data from Ad

+ (nonnull NSString *)getCurrentPosition {
    return @"JSON.stringify(mraid.getCurrentPosition());";
}

+ (nonnull NSString *)getOrientationProperties {
    return @"JSON.stringify(mraid.getOrientationProperties());";
}

+ (nonnull NSString *)getExpandProperties {
    return @"JSON.stringify(mraid.getExpandProperties());";
}
+ (nonnull NSString *)getResizeProperties {
    return @"JSON.stringify(mraid.getResizeProperties());";
}

#pragma mark - error

+ (nonnull NSString *)onErrorWithMessage:(nonnull NSString *)message action:(nonnull SWPBMMRAIDAction)action {
    return [NSString stringWithFormat:@"mraid.onError('%@','%@');", message, action];
}

#pragma mark - Internal methods

+ (NSString *)getSupportedFeatureString {
    
    NSDictionary<SWPBMMRAIDFeature, NSNumber*> *supports = @{
        SWPBMMRAIDFeatureSMS          : @(YES),
        SWPBMMRAIDFeaturePhone        : @(YES),
        SWPBMMRAIDFeatureCalendar     : @(NO),
        SWPBMMRAIDFeatureSavePicture  : @(NO),
        SWPBMMRAIDFeatureInlineVideo  : @(YES),
        SWPBMMRAIDFeatureLocation     : @(YES),
        SWPBMMRAIDFeatureVPAID        : @(NO),
    };
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:supports options:0 error:nil];
    if (!data) {
        SWPBMLogError(@"Could not generate support string");
        return @"";
    }
    
    NSString *ret = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return ret;
}

+ (NSString *)getRectString:(CGRect)position {
    NSString *x = [NSString stringWithFormat:SWPBMMRAIDCommandFormatSize, SWPBMMRAIDParseKeys.X, [SWPBMMRAIDJavascriptCommands formatFloat:position.origin.x]];
    NSString *y = [NSString stringWithFormat:SWPBMMRAIDCommandFormatSize, SWPBMMRAIDParseKeys.Y, [SWPBMMRAIDJavascriptCommands formatFloat:position.origin.y]];
    NSString *width = [NSString stringWithFormat:SWPBMMRAIDCommandFormatSize, SWPBMMRAIDParseKeys.WIDTH, [SWPBMMRAIDJavascriptCommands formatFloat:position.size.width]];
    NSString *height = [NSString stringWithFormat:SWPBMMRAIDCommandFormatSize, SWPBMMRAIDParseKeys.HEIGHT, [SWPBMMRAIDJavascriptCommands formatFloat:position.size.height]];

    return [NSString stringWithFormat:@"{%@, %@, %@, %@}", x, y, width, height];
}

+ (NSNumberFormatter *)floatFormatter {
    static NSNumberFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSNumberFormatter new];
        formatter.numberStyle = NSNumberFormatterNoStyle;
        formatter.minimumIntegerDigits = 1;
        formatter.minimumFractionDigits = 1;
        formatter.maximumFractionDigits = 4;
        formatter.usesGroupingSeparator = NO;
        formatter.decimalSeparator = @".";
    });
    
    return formatter;
}

+ (NSString *)formatFloat:(CGFloat)value {
    return [SWPBMMRAIDJavascriptCommands.floatFormatter stringFromNumber:@(value)];
}

@end
