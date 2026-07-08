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

#import "SWPBMNetworkParameterBuilder.h"

#import <CoreTelephony/CTCarrier.h>

#import "SWPBMORTB.h"
#import "SWPBMMacros.h"
#import "SWLog+Extensions.h"

#import "SWSwiftImport.h"

#pragma mark - Internal Extension

@interface SWPBMNetworkParameterBuilder ()

@property (nonatomic, strong) CTTelephonyNetworkInfo *ctTelephonyNetworkInfo;
@property (nonatomic, strong) SWPBMReachability *reachability;

@end

#pragma mark - Implementation

@implementation SWPBMNetworkParameterBuilder

#pragma mark - Initialization
- (instancetype)initWithCtTelephonyNetworkInfo:(CTTelephonyNetworkInfo *)ctTelephonyNetworkInfo reachability:(SWPBMReachability *)reachability {
    self = [super init];
    if (self) {
        SWPBMAssert(ctTelephonyNetworkInfo && reachability);
        self.ctTelephonyNetworkInfo = ctTelephonyNetworkInfo;
        self.reachability = reachability;
    }
    
    return self;
}

#pragma mark - SWPBMParameterBuilder

- (void)buildBidRequest:(SWPBMORTBBidRequest *)bidRequest {
    if (!(self.ctTelephonyNetworkInfo && bidRequest)) {
        SWPBMLogError(@"Invalid properties");
        return;
    }
    
    // reachability type
    SWPBMNetworkType networkStatus = [self.reachability currentReachabilityStatus];
    bidRequest.device.connectiontype = [NSNumber numberWithInteger:networkStatus];
    
    [self setCarrierIn:bidRequest];
}

- (void)setCarrierIn:(SWPBMORTBBidRequest *)bidRequest {
    CTCarrier * carrier;
    
    if (@available(iOS 16.0, *)) {
        // do nothing - CTCarrier is deprecated with no replacement
    } else {
        carrier = [[self.ctTelephonyNetworkInfo.serviceSubscriberCellularProviders allValues] firstObject];
    }
    
    if (!carrier) {
        return;
    }
    
    //Update params dict
    NSString *countryCode = carrier.mobileCountryCode;
    NSString *carrierCode = carrier.mobileNetworkCode;
    if (countryCode && carrierCode) {
        NSString *mccmnc = [NSString stringWithFormat:@"%@-%@", countryCode, carrierCode];
        bidRequest.device.mccmnc = mccmnc;
    }
    
    //Update ORTB
    // carrier
    bidRequest.device.carrier = carrier.carrierName;
}

@end
