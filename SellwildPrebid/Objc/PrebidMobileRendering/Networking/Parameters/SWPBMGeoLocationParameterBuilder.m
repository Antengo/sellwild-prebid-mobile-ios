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

#import "SWPBMGeoLocationParameterBuilder.h"
#import "SWPBMORTB.h"
#import "SWPBMConstants.h"
#import "SWPBMMacros.h"
#import "SWLog+Extensions.h"
#import <CoreLocation/CoreLocation.h>

#import "SWSwiftImport.h"

#pragma mark - Internal Extension

@interface SWPBMGeoLocationParameterBuilder()

@property (nonatomic, strong) SWPBMLocationManager *locationManager;

@end

#pragma mark - Implementation

@implementation SWPBMGeoLocationParameterBuilder

#pragma mark - Initialization

- (nonnull instancetype)initWithLocationManager:(nonnull SWPBMLocationManager *)locationManager {
    self = [super init];
    if (self) {
        SWPBMAssert(locationManager);
        
        self.locationManager = locationManager;
    }
    
    return self;
}

#pragma mark - SWPBMParameterBuilder

- (void)buildBidRequest:(SWPBMORTBBidRequest *)bidRequest {
    if (SellwildPrebid.shared.shareGeoLocation == false) {
        return;;
    }
    if (!(self.locationManager && bidRequest)) {
        SWPBMLogError(@"Invalid properties");
        return;
    }
    
    if (self.locationManager.coordinatesAreValid) {
        // Rounds with the precision defined in SWPBTargeting, or returns the original coordinates if precision is nil.
        CLLocationCoordinate2D coordinates = [[SWPBUtils shared] roundWithCoordinates:self.locationManager.coordinates precision:[[SWPBTargeting shared] locationPrecision]];
        bidRequest.device.geo.type = @(SWPBPrebidConstants.LOCATION_SOURCE_GPS);
        bidRequest.device.geo.lat = @(coordinates.latitude);
        bidRequest.device.geo.lon = @(coordinates.longitude);
    }
}

@end
