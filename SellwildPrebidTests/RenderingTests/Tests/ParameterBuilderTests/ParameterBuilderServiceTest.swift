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

import Foundation
import AppTrackingTransparency
import XCTest
import CoreLocation

@testable import SellwildPrebid

class ParameterBuilderServiceTest : XCTestCase {
    
    override func setUp() {
        UtilitiesForTesting.resetTargeting(.shared)
        SellwildPrebid.shared.shareGeoLocation = true
        Targeting.shared.locationPrecision = nil
    }
    
    override func tearDown() {
        UtilitiesForTesting.resetTargeting(.shared)
    }
    
    var sdkVersion: String { return Bundle(for: BannerView.self).infoDictionary!["CFBundleShortVersionString"] as! String }
    
    func testBuildParamsDict() {
        let url = "https://openx.com"
        let publisherName = "Publisher"
        
        let adConfiguration = AdConfiguration()
        
        let targeting = Targeting.shared
        targeting.parameterDictionary.removeAll()
        targeting.parameterDictionary["foo"] = "bar"
        targeting.coppa = 1
        targeting.storeURL = url
        targeting.publisherName = publisherName
        targeting.addUserKeyword("keyword1,keyword2")
        targeting.addAppKeyword("appKeyword1,appKeyword2")
        
        let sdkConfiguration = SellwildPrebid.mock
        
        let mockBundle = MockBundle()
        let mockDeviceAccessManager = MockDeviceAccessManager(rootViewController: nil)
        if #available(iOS 14, *) {
            MockDeviceAccessManager.mockAppTrackingTransparencyStatus = .authorized
        }
        let mockLocationManagerSuccessful = MockLocationManagerSuccessful.sharedMock
        mockLocationManagerSuccessful.latestAuthorizationStatus = .authorizedWhenInUse
        let mockCTTelephonyNetworkInfo = MockCTTelephonyNetworkInfo()
        let mockReachability = MockReachability.shared
        
        UserConsentDataManager.shared.gdprConsentString = "consentstring"
        UserConsentDataManager.shared.subjectToGDPR = false
        
        let paramsDict = SWPBMParameterBuilderService.buildParamsDict(
            with: adConfiguration,
            bundle:mockBundle,
            swpbmLocationManager: mockLocationManagerSuccessful,
            swpbmDeviceAccessManager: mockDeviceAccessManager,
            ctTelephonyNetworkInfo: mockCTTelephonyNetworkInfo,
            reachability: mockReachability,
            sdkConfiguration: sdkConfiguration,
            sdkVersion: "MOCK_SDK_VERSION",
            targeting: targeting,
            extraParameterBuilders: nil
        )
        
        //Create a new SWPBMORTBBidRequest based off of the json string in the params dict
        guard let strORTB = paramsDict[PrebidConstants.OPEN_RTB_SCHEME] else {
            XCTFail("No ORTB string in parameter keys")
            return
        }
        
        let bidRequest: SWPBMORTBBidRequest
        do {
            bidRequest = try SWPBMORTBBidRequest.from(jsonString:strORTB)
        } catch {
            XCTFail("\(error)")
            return
        }
        
        //Verify SWPBMBasicParameterBuilder
        SWPBMAssertEq(bidRequest.imp.count, 1)
        SWPBMAssertEq(bidRequest.imp.first?.displaymanager, "prebid-mobile")
        SWPBMAssertEq(bidRequest.imp.first?.displaymanagerver, "MOCK_SDK_VERSION")
        SWPBMAssertEq(bidRequest.imp.first?.secure, 1)
        
        //Verify GeoLocationParameterBuilder
        SWPBMAssertEq(bidRequest.device.geo.type, 1)
        SWPBMAssertEq(bidRequest.device.geo.lat!.doubleValue, mockLocationManagerSuccessful.coordinates.latitude)
        SWPBMAssertEq(bidRequest.device.geo.lon!.doubleValue, mockLocationManagerSuccessful.coordinates.longitude)
        
        //Verify SWPBMAppInfoParameterBuilder
        SWPBMAssertEq(bidRequest.app.name, mockBundle.mockBundleDisplayName)
        SWPBMAssertEq(bidRequest.app.bundle, mockBundle.mockBundleIdentifier)
        SWPBMAssertEq(bidRequest.app.publisher?.name, publisherName)
        
        //Verify DeviceInfoParameterBuilder
        SWPBMAssertEq(bidRequest.device.w!.intValue, Int(mockDeviceAccessManager.screenSize().width))
        SWPBMAssertEq(bidRequest.device.h!.intValue, Int(mockDeviceAccessManager.screenSize().height))
        SWPBMAssertEq(bidRequest.device.ifa, MockDeviceAccessManager.mockAdvertisingIdentifier)
        SWPBMAssertEq(bidRequest.device.lmt, 0)
        SWPBMAssertEq(bidRequest.device.hwv, mockDeviceAccessManager.platformString)
        
        
        if #available(iOS 16, *) {
            // do nothing - CTCarrier is deprecated
        } else {
            //Verify NetworkParameterBuilder
            let expectedMccmnc = "\(mockCTTelephonyNetworkInfo.subscriberCellularProvider!.mobileCountryCode!)-\(mockCTTelephonyNetworkInfo.subscriberCellularProvider!.mobileNetworkCode!)"
            SWPBMAssertEq(bidRequest.device.mccmnc, expectedMccmnc)
            SWPBMAssertEq(bidRequest.device.mccmnc, expectedMccmnc)
            SWPBMAssertEq(bidRequest.device.carrier, MockCTCarrier.mockCarrierName)
            SWPBMAssertEq(bidRequest.device.mccmnc, expectedMccmnc)
            
            //Verify SupportedProtocolsParameterBuilder
            SWPBMAssertEq(bidRequest.imp.count, 1)
            SWPBMAssertEq(bidRequest.imp.first?.banner?.api, nil)
        }
        
        //Verify ORTBParameterBuilder
        guard #available(iOS 11.0, *) else {
            Log.warn("iOS 11 or higher is needed to support the .sortedKeys option for JSONEncoding which puts keys in the order that they appear in the class. Before that, string encoding results are unpredictable.")
            return
        }
        
        var deviceExt = ""
        if #available(iOS 14.0, *) {
            deviceExt = "\"ext\":{\"atts\":3},"
        }
        
        var carrier = ""
        var mccmnc = ""
        
        if #available(iOS 16, *) {
            // do nothing - CTCarrier is deprecated with no replacement
        }
        else {
            carrier = "\"carrier\":\"MOCK_CARRIER_NAME\","
            mccmnc = "\"mccmnc\":\"123-456\","
        }
        
        let expectedOrtb = """
        {\"app\":{\"bundle\":\"Mock.Bundle.Identifier\",\"keywords\":\"appKeyword1,appKeyword2\",\"name\":\"MockBundleDisplayName\",\"publisher\":{\"name\":\"Publisher\"},\"storeurl\":\"https:\\/\\/openx.com\"},\"device\":{\(carrier)\"connectiontype\":2,\(deviceExt)\"geo\":{\"lat\":34.149335,\"lon\":-118.1328249,\"type\":1},\"h\":200,\"hwv\":\"iPhone1,1\",\"ifa\":\"abc123\",\"language\":\"ml\",\"lmt\":0,\"make\":\"MockMake\",\(mccmnc)\"model\":\"MockModel\",\"os\":\"MockOS\",\"osv\":\"1.2.3\",\"w\":100},\"imp\":[{\"clickbrowser\":1,\"displaymanager\":\"prebid-mobile\",\"displaymanagerver\":\"MOCK_SDK_VERSION\",\"ext\":{\"dlp\":1},\"instl\":0,\"secure\":1}],\"regs\":{\"coppa\":1,\"ext\":{\"gdpr\":0}},\"user\":{\"ext\":{\"consent\":\"consentstring\"},\"keywords\":\"keyword1,keyword2\"}}
        """
        SWPBMAssertEq(strORTB, expectedOrtb)
    }
    
    func testDeviceLocationPrecisionInParamsDict() {
        
        let adConfiguration = AdConfiguration()
        
        let targeting = Targeting.shared
        targeting.parameterDictionary.removeAll()
        targeting.locationPrecision = NSNumber(value: 2)
        SellwildPrebid.shared.shareGeoLocation = true
        
        let sdkConfiguration = SellwildPrebid.mock
        
        let mockBundle = MockBundle()
        let mockDeviceAccessManager = MockDeviceAccessManager(rootViewController: nil)
        if #available(iOS 14, *) {
            MockDeviceAccessManager.mockAppTrackingTransparencyStatus = .authorized
        }
        let mockLocationManagerSuccessful = MockLocationManagerSuccessful.sharedMock
        let mockCTTelephonyNetworkInfo = MockCTTelephonyNetworkInfo()
        let mockReachability = MockReachability.shared
        
        let paramsDict = SWPBMParameterBuilderService.buildParamsDict(
            with: adConfiguration,
            bundle:mockBundle,
            swpbmLocationManager: mockLocationManagerSuccessful,
            swpbmDeviceAccessManager: mockDeviceAccessManager,
            ctTelephonyNetworkInfo: mockCTTelephonyNetworkInfo,
            reachability: mockReachability,
            sdkConfiguration: sdkConfiguration,
            sdkVersion: "MOCK_SDK_VERSION",
            targeting: targeting,
            extraParameterBuilders: nil
        )
        
        //Create a new SWPBMORTBBidRequest based off of the json string in the params dict
        guard let strORTB = paramsDict[PrebidConstants.OPEN_RTB_SCHEME] else {
            XCTFail("No ORTB string in parameter keys")
            return
        }
        
        let bidRequest: SWPBMORTBBidRequest
        do {
            bidRequest = try SWPBMORTBBidRequest.from(jsonString:strORTB)
        } catch {
            XCTFail("\(error)")
            return
        }
        
        //Verify GeoLocationParameterBuilder
        let preciseLocation = Utils.shared.round(coordinates: mockLocationManagerSuccessful.coordinates, precision: targeting.locationPrecision)
        
        SWPBMAssertEq(bidRequest.device.geo.type, 1)
        SWPBMAssertEq(bidRequest.device.geo.lat!.doubleValue, preciseLocation.latitude)
        SWPBMAssertEq(bidRequest.device.geo.lon!.doubleValue, preciseLocation.longitude)
        
        //Verify User Geo is not set
        XCTAssertNil(bidRequest.user.geo.lat)
        XCTAssertNil(bidRequest.user.geo.lon)
        
        //Verify ORTBParameterBuilder
        guard #available(iOS 11.0, *) else {
            Log.warn("iOS 11 or higher is needed to support the .sortedKeys option for JSONEncoding which puts keys in the order that they appear in the class. Before that, string encoding results are unpredictable.")
            return
        }
        
        var deviceExt = ""
        if #available(iOS 14.0, *) {
            deviceExt = "\"ext\":{\"atts\":3},"
        }

        let expectedOrtb = """
        {\"app\":{\"bundle\":\"Mock.Bundle.Identifier\",\"name\":\"MockBundleDisplayName\"},\"device\":{\"connectiontype\":2,\(deviceExt)\"geo\":{\"lat\":34.15,\"lon\":-118.13,\"type\":1},\"h\":200,\"hwv\":\"iPhone1,1\",\"ifa\":\"abc123\",\"language\":\"ml\",\"lmt\":0,\"make\":\"MockMake\",\"model\":\"MockModel\",\"os\":\"MockOS\",\"osv\":\"1.2.3\",\"w\":100},\"imp\":[{\"clickbrowser\":1,\"displaymanager\":\"prebid-mobile\",\"displaymanagerver\":\"MOCK_SDK_VERSION\",\"ext\":{\"dlp\":1},\"instl\":0,\"secure\":1}],\"regs\":{\"coppa\":0}}
        """
        
        SWPBMAssertEq(strORTB, expectedOrtb)
    }
    
    func testUserLocationPrecisionInParamsDict() {
        
        let adConfiguration = AdConfiguration()
        
        let targeting = Targeting.shared
        targeting.parameterDictionary.removeAll()
        targeting.locationPrecision = NSNumber.init(value: 2)
        
        SellwildPrebid.shared.shareGeoLocation = false
        
        let sdkConfiguration = SellwildPrebid.mock
        
        let mockBundle = MockBundle()
        let mockDeviceAccessManager = MockDeviceAccessManager(rootViewController: nil)
        if #available(iOS 14, *) {
            MockDeviceAccessManager.mockAppTrackingTransparencyStatus = .authorized
        }
        let mockLocationManagerSuccessful = MockLocationManagerSuccessful.sharedMock
        
        targeting.coordinate = NSValue(mkCoordinate: mockLocationManagerSuccessful.coordinates) 
        let mockCTTelephonyNetworkInfo = MockCTTelephonyNetworkInfo()
        let mockReachability = MockReachability.shared
        
        let paramsDict = SWPBMParameterBuilderService.buildParamsDict(
            with: adConfiguration,
            bundle:mockBundle,
            swpbmLocationManager: mockLocationManagerSuccessful,
            swpbmDeviceAccessManager: mockDeviceAccessManager,
            ctTelephonyNetworkInfo: mockCTTelephonyNetworkInfo,
            reachability: mockReachability,
            sdkConfiguration: sdkConfiguration,
            sdkVersion: "MOCK_SDK_VERSION",
            targeting: targeting,
            extraParameterBuilders: nil
        )
        
        //Create a new SWPBMORTBBidRequest based off of the json string in the params dict
        guard let strORTB = paramsDict[PrebidConstants.OPEN_RTB_SCHEME] else {
            XCTFail("No ORTB string in parameter keys")
            return
        }
        
        let bidRequest: SWPBMORTBBidRequest
        do {
            bidRequest = try SWPBMORTBBidRequest.from(jsonString:strORTB)
        } catch {
            XCTFail("\(error)")
            return
        }
        
        //Verify GeoLocationParameterBuilder
        XCTAssertNil(bidRequest.device.geo.lat)
        XCTAssertNil(bidRequest.device.geo.lon)

        //Verify User Geo is not set
        let preciseLocation = Utils.shared.round(coordinates: mockLocationManagerSuccessful.coordinates, precision: targeting.locationPrecision)
        SWPBMAssertEq(bidRequest.user.geo.lat!.doubleValue, preciseLocation.latitude)
        SWPBMAssertEq(bidRequest.user.geo.lon!.doubleValue, preciseLocation.longitude)
        
        //Verify ORTBParameterBuilder
        guard #available(iOS 11.0, *) else {
            Log.warn("iOS 11 or higher is needed to support the .sortedKeys option for JSONEncoding which puts keys in the order that they appear in the class. Before that, string encoding results are unpredictable.")
            return
        }
        
        var deviceExt = ""
        if #available(iOS 14.0, *) {
            deviceExt = "\"ext\":{\"atts\":3},"
        }

        let expectedOrtb = """
        {\"app\":{\"bundle\":\"Mock.Bundle.Identifier\",\"name\":\"MockBundleDisplayName\"},\"device\":{\"connectiontype\":2,\(deviceExt)\"h\":200,\"hwv\":\"iPhone1,1\",\"ifa\":\"abc123\",\"language\":\"ml\",\"lmt\":0,\"make\":\"MockMake\",\"model\":\"MockModel\",\"os\":\"MockOS\",\"osv\":\"1.2.3\",\"w\":100},\"imp\":[{\"clickbrowser\":1,\"displaymanager\":\"prebid-mobile\",\"displaymanagerver\":\"MOCK_SDK_VERSION\",\"ext\":{\"dlp\":1},\"instl\":0,\"secure\":1}],\"regs\":{\"coppa\":0},\"user\":{\"geo\":{\"lat\":34.15,\"lon\":-118.13}}}
        """
        
        SWPBMAssertEq(strORTB, expectedOrtb)
    }
    
    func testSettingHighLocationPrecisionInParamsDict() {
        
        let adConfiguration = AdConfiguration()
        
        let targeting = Targeting.shared
        targeting.parameterDictionary.removeAll()
        targeting.locationPrecision = NSNumber(value: Int.max)
        
        SellwildPrebid.shared.shareGeoLocation = false
        
        let sdkConfiguration = SellwildPrebid.mock
        
        let mockBundle = MockBundle()
        let mockDeviceAccessManager = MockDeviceAccessManager(rootViewController: nil)
        if #available(iOS 14, *) {
            MockDeviceAccessManager.mockAppTrackingTransparencyStatus = .authorized
        }
        let mockLocationManagerSuccessful = MockLocationManagerSuccessful.sharedMock
        
        targeting.coordinate = NSValue(mkCoordinate: mockLocationManagerSuccessful.coordinates)
        let mockCTTelephonyNetworkInfo = MockCTTelephonyNetworkInfo()
        let mockReachability = MockReachability.shared
        
        let paramsDict = SWPBMParameterBuilderService.buildParamsDict(
            with: adConfiguration,
            bundle:mockBundle,
            swpbmLocationManager: mockLocationManagerSuccessful,
            swpbmDeviceAccessManager: mockDeviceAccessManager,
            ctTelephonyNetworkInfo: mockCTTelephonyNetworkInfo,
            reachability: mockReachability,
            sdkConfiguration: sdkConfiguration,
            sdkVersion: "MOCK_SDK_VERSION",
            targeting: targeting,
            extraParameterBuilders: nil
        )
        
        //Create a new SWPBMORTBBidRequest based off of the json string in the params dict
        guard let strORTB = paramsDict[PrebidConstants.OPEN_RTB_SCHEME] else {
            XCTFail("No ORTB string in parameter keys")
            return
        }
        
        let bidRequest: SWPBMORTBBidRequest
        do {
            bidRequest = try SWPBMORTBBidRequest.from(jsonString:strORTB)
        } catch {
            XCTFail("\(error)")
            return
        }
        
        //Verify GeoLocationParameterBuilder
        XCTAssertNil(bidRequest.device.geo.lat)
        XCTAssertNil(bidRequest.device.geo.lon)

        //Verify User Geo is not set
        let preciseLocation = Utils.shared.round(coordinates: mockLocationManagerSuccessful.coordinates, precision: targeting.locationPrecision)
        SWPBMAssertEq(bidRequest.user.geo.lat!.doubleValue, preciseLocation.latitude)
        SWPBMAssertEq(bidRequest.user.geo.lon!.doubleValue, preciseLocation.longitude)
        
        //Verify ORTBParameterBuilder
        guard #available(iOS 11.0, *) else {
            Log.warn("iOS 11 or higher is needed to support the .sortedKeys option for JSONEncoding which puts keys in the order that they appear in the class. Before that, string encoding results are unpredictable.")
            return
        }
        
        var deviceExt = ""
        if #available(iOS 14.0, *) {
            deviceExt = "\"ext\":{\"atts\":3},"
        }

        let expectedOrtb = """
        {\"app\":{\"bundle\":\"Mock.Bundle.Identifier\",\"name\":\"MockBundleDisplayName\"},\"device\":{\"connectiontype\":2,\(deviceExt)\"h\":200,\"hwv\":\"iPhone1,1\",\"ifa\":\"abc123\",\"language\":\"ml\",\"lmt\":0,\"make\":\"MockMake\",\"model\":\"MockModel\",\"os\":\"MockOS\",\"osv\":\"1.2.3\",\"w\":100},\"imp\":[{\"clickbrowser\":1,\"displaymanager\":\"prebid-mobile\",\"displaymanagerver\":\"MOCK_SDK_VERSION\",\"ext\":{\"dlp\":1},\"instl\":0,\"secure\":1}],\"regs\":{\"coppa\":0},\"user\":{\"geo\":{\"lat\":34.149335,\"lon\":-118.1328249}}}
        """
        
        SWPBMAssertEq(strORTB, expectedOrtb)
    }
    
    func testSettingNegativeLocationPrecisionInParamsDict() {
        
        let adConfiguration = AdConfiguration()
        
        let targeting = Targeting.shared
        targeting.parameterDictionary.removeAll()
        targeting.locationPrecision = NSNumber(value: Int.min)
        
        SellwildPrebid.shared.shareGeoLocation = false
        
        let sdkConfiguration = SellwildPrebid.mock
        
        let mockBundle = MockBundle()
        let mockDeviceAccessManager = MockDeviceAccessManager(rootViewController: nil)
        if #available(iOS 14, *) {
            MockDeviceAccessManager.mockAppTrackingTransparencyStatus = .authorized
        }
        let mockLocationManagerSuccessful = MockLocationManagerSuccessful.sharedMock
        
        targeting.coordinate = NSValue(mkCoordinate: mockLocationManagerSuccessful.coordinates)
        let mockCTTelephonyNetworkInfo = MockCTTelephonyNetworkInfo()
        let mockReachability = MockReachability.shared
        
        let paramsDict = SWPBMParameterBuilderService.buildParamsDict(
            with: adConfiguration,
            bundle:mockBundle,
            swpbmLocationManager: mockLocationManagerSuccessful,
            swpbmDeviceAccessManager: mockDeviceAccessManager,
            ctTelephonyNetworkInfo: mockCTTelephonyNetworkInfo,
            reachability: mockReachability,
            sdkConfiguration: sdkConfiguration,
            sdkVersion: "MOCK_SDK_VERSION",
            targeting: targeting,
            extraParameterBuilders: nil
        )
        
        //Create a new SWPBMORTBBidRequest based off of the json string in the params dict
        guard let strORTB = paramsDict[PrebidConstants.OPEN_RTB_SCHEME] else {
            XCTFail("No ORTB string in parameter keys")
            return
        }
        
        let bidRequest: SWPBMORTBBidRequest
        do {
            bidRequest = try SWPBMORTBBidRequest.from(jsonString:strORTB)
        } catch {
            XCTFail("\(error)")
            return
        }
        
        //Verify GeoLocationParameterBuilder
        XCTAssertNil(bidRequest.device.geo.lat)
        XCTAssertNil(bidRequest.device.geo.lon)

        //Verify User Geo is not set
        let preciseLocation = Utils.shared.round(coordinates: mockLocationManagerSuccessful.coordinates, precision: targeting.locationPrecision)
        SWPBMAssertEq(bidRequest.user.geo.lat!.doubleValue, preciseLocation.latitude)
        SWPBMAssertEq(bidRequest.user.geo.lon!.doubleValue, preciseLocation.longitude)
        
        //Verify ORTBParameterBuilder
        guard #available(iOS 11.0, *) else {
            Log.warn("iOS 11 or higher is needed to support the .sortedKeys option for JSONEncoding which puts keys in the order that they appear in the class. Before that, string encoding results are unpredictable.")
            return
        }
        
        var deviceExt = ""
        if #available(iOS 14.0, *) {
            deviceExt = "\"ext\":{\"atts\":3},"
        }

        let expectedOrtb = """
        {\"app\":{\"bundle\":\"Mock.Bundle.Identifier\",\"name\":\"MockBundleDisplayName\"},\"device\":{\"connectiontype\":2,\(deviceExt)\"h\":200,\"hwv\":\"iPhone1,1\",\"ifa\":\"abc123\",\"language\":\"ml\",\"lmt\":0,\"make\":\"MockMake\",\"model\":\"MockModel\",\"os\":\"MockOS\",\"osv\":\"1.2.3\",\"w\":100},\"imp\":[{\"clickbrowser\":1,\"displaymanager\":\"prebid-mobile\",\"displaymanagerver\":\"MOCK_SDK_VERSION\",\"ext\":{\"dlp\":1},\"instl\":0,\"secure\":1}],\"regs\":{\"coppa\":0},\"user\":{\"geo\":{\"lat\":34.149335,\"lon\":-118.1328249}}}
        """
        
        SWPBMAssertEq(strORTB, expectedOrtb)
    }
    
    func testSettingZeroLocationPrecisionInParamsDict() {
        
        let adConfiguration = AdConfiguration()
        
        let targeting = Targeting.shared
        targeting.parameterDictionary.removeAll()
        targeting.locationPrecision = NSNumber(value: Int.zero)
        
        SellwildPrebid.shared.shareGeoLocation = false
        
        let sdkConfiguration = SellwildPrebid.mock
        
        let mockBundle = MockBundle()
        let mockDeviceAccessManager = MockDeviceAccessManager(rootViewController: nil)
        if #available(iOS 14, *) {
            MockDeviceAccessManager.mockAppTrackingTransparencyStatus = .authorized
        }
        let mockLocationManagerSuccessful = MockLocationManagerSuccessful.sharedMock
        
        targeting.coordinate = NSValue(mkCoordinate: mockLocationManagerSuccessful.coordinates)
        let mockCTTelephonyNetworkInfo = MockCTTelephonyNetworkInfo()
        let mockReachability = MockReachability.shared
        
        let paramsDict = SWPBMParameterBuilderService.buildParamsDict(
            with: adConfiguration,
            bundle:mockBundle,
            swpbmLocationManager: mockLocationManagerSuccessful,
            swpbmDeviceAccessManager: mockDeviceAccessManager,
            ctTelephonyNetworkInfo: mockCTTelephonyNetworkInfo,
            reachability: mockReachability,
            sdkConfiguration: sdkConfiguration,
            sdkVersion: "MOCK_SDK_VERSION",
            targeting: targeting,
            extraParameterBuilders: nil
        )
        
        //Create a new SWPBMORTBBidRequest based off of the json string in the params dict
        guard let strORTB = paramsDict[PrebidConstants.OPEN_RTB_SCHEME] else {
            XCTFail("No ORTB string in parameter keys")
            return
        }
        
        let bidRequest: SWPBMORTBBidRequest
        do {
            bidRequest = try SWPBMORTBBidRequest.from(jsonString:strORTB)
        } catch {
            XCTFail("\(error)")
            return
        }
        
        //Verify GeoLocationParameterBuilder
        XCTAssertNil(bidRequest.device.geo.lat)
        XCTAssertNil(bidRequest.device.geo.lon)

        //Verify User Geo is not set
        let preciseLocation = Utils.shared.round(coordinates: mockLocationManagerSuccessful.coordinates, precision: targeting.locationPrecision)
        SWPBMAssertEq(bidRequest.user.geo.lat!.doubleValue, preciseLocation.latitude)
        SWPBMAssertEq(bidRequest.user.geo.lon!.doubleValue, preciseLocation.longitude)
        
        //Verify ORTBParameterBuilder
        guard #available(iOS 11.0, *) else {
            Log.warn("iOS 11 or higher is needed to support the .sortedKeys option for JSONEncoding which puts keys in the order that they appear in the class. Before that, string encoding results are unpredictable.")
            return
        }
        
        var deviceExt = ""
        if #available(iOS 14.0, *) {
            deviceExt = "\"ext\":{\"atts\":3},"
        }

        let expectedOrtb = """
        {\"app\":{\"bundle\":\"Mock.Bundle.Identifier\",\"name\":\"MockBundleDisplayName\"},\"device\":{\"connectiontype\":2,\(deviceExt)\"h\":200,\"hwv\":\"iPhone1,1\",\"ifa\":\"abc123\",\"language\":\"ml\",\"lmt\":0,\"make\":\"MockMake\",\"model\":\"MockModel\",\"os\":\"MockOS\",\"osv\":\"1.2.3\",\"w\":100},\"imp\":[{\"clickbrowser\":1,\"displaymanager\":\"prebid-mobile\",\"displaymanagerver\":\"MOCK_SDK_VERSION\",\"ext\":{\"dlp\":1},\"instl\":0,\"secure\":1}],\"regs\":{\"coppa\":0},\"user\":{\"geo\":{\"lat\":34,\"lon\":-118}}}
        """
        
        SWPBMAssertEq(strORTB, expectedOrtb)
    }
    
    func testDeviceLocationNoUsedIfDenied() {
        
        let adConfiguration = AdConfiguration()
        
        let targeting = Targeting.shared
        targeting.parameterDictionary.removeAll()
        targeting.locationPrecision = NSNumber.init(value: 2)
        
        SellwildPrebid.shared.shareGeoLocation = true
        
        let sdkConfiguration = SellwildPrebid.mock
        
        let mockBundle = MockBundle()
        let mockDeviceAccessManager = MockDeviceAccessManager(rootViewController: nil)
        if #available(iOS 14, *) {
            MockDeviceAccessManager.mockAppTrackingTransparencyStatus = .authorized
        }
        
        let mockLocationManagerUnSuccessful = MockLocationManagerUnSuccessful.sharedMock
        
        let mockCTTelephonyNetworkInfo = MockCTTelephonyNetworkInfo()
        let mockReachability = MockReachability.shared
        
        let paramsDict = SWPBMParameterBuilderService.buildParamsDict(
            with: adConfiguration,
            bundle:mockBundle,
            swpbmLocationManager: mockLocationManagerUnSuccessful,
            swpbmDeviceAccessManager: mockDeviceAccessManager,
            ctTelephonyNetworkInfo: mockCTTelephonyNetworkInfo,
            reachability: mockReachability,
            sdkConfiguration: sdkConfiguration,
            sdkVersion: "MOCK_SDK_VERSION",
            targeting: targeting,
            extraParameterBuilders: nil
        )
        
        //Create a new SWPBMORTBBidRequest based off of the json string in the params dict
        guard let strORTB = paramsDict[PrebidConstants.OPEN_RTB_SCHEME] else {
            XCTFail("No ORTB string in parameter keys")
            return
        }
        
        let bidRequest: SWPBMORTBBidRequest
        do {
            bidRequest = try SWPBMORTBBidRequest.from(jsonString:strORTB)
        } catch {
            XCTFail("\(error)")
            return
        }
        
        //Verify GeoLocationParameterBuilder
        XCTAssertNil(bidRequest.device.geo.lat)
        XCTAssertNil(bidRequest.device.geo.lon)
        
        //Verify User Geo is not set
        XCTAssertNil(bidRequest.user.geo.lat)
        XCTAssertNil(bidRequest.user.geo.lon)
        
        //Verify ORTBParameterBuilder
        guard #available(iOS 11.0, *) else {
            Log.warn("iOS 11 or higher is needed to support the .sortedKeys option for JSONEncoding which puts keys in the order that they appear in the class. Before that, string encoding results are unpredictable.")
            return
        }
        
        var deviceExt = ""
        if #available(iOS 14.0, *) {
            deviceExt = "\"ext\":{\"atts\":3},"
        }

        let expectedOrtb = """
        {\"app\":{\"bundle\":\"Mock.Bundle.Identifier\",\"name\":\"MockBundleDisplayName\"},\"device\":{\"connectiontype\":2,\(deviceExt)\"h\":200,\"hwv\":\"iPhone1,1\",\"ifa\":\"abc123\",\"language\":\"ml\",\"lmt\":0,\"make\":\"MockMake\",\"model\":\"MockModel\",\"os\":\"MockOS\",\"osv\":\"1.2.3\",\"w\":100},\"imp\":[{\"clickbrowser\":1,\"displaymanager\":\"prebid-mobile\",\"displaymanagerver\":\"MOCK_SDK_VERSION\",\"ext\":{\"dlp\":1},\"instl\":0,\"secure\":1}],\"regs\":{\"coppa\":0}}
        """
        
        SWPBMAssertEq(strORTB, expectedOrtb)
    }
    
    func testDeviceLocationNotUsedIfUndetermined() {
        
        let adConfiguration = AdConfiguration()
        
        let targeting = Targeting.shared
        targeting.parameterDictionary.removeAll()
        targeting.locationPrecision = NSNumber.init(value: 2)
        
        SellwildPrebid.shared.shareGeoLocation = true
        
        let sdkConfiguration = SellwildPrebid.mock
        
        let mockBundle = MockBundle()
        let mockDeviceAccessManager = MockDeviceAccessManager(rootViewController: nil)
        if #available(iOS 14, *) {
            MockDeviceAccessManager.mockAppTrackingTransparencyStatus = .authorized
        }
        let mockLocationManagerUnSuccessful = MockLocationManagerUnSuccessful.sharedMock
        mockLocationManagerUnSuccessful.latestAuthorizationStatus = .notDetermined
        
        let mockCTTelephonyNetworkInfo = MockCTTelephonyNetworkInfo()
        let mockReachability = MockReachability.shared
        
        let paramsDict = SWPBMParameterBuilderService.buildParamsDict(
            with: adConfiguration,
            bundle:mockBundle,
            swpbmLocationManager: mockLocationManagerUnSuccessful,
            swpbmDeviceAccessManager: mockDeviceAccessManager,
            ctTelephonyNetworkInfo: mockCTTelephonyNetworkInfo,
            reachability: mockReachability,
            sdkConfiguration: sdkConfiguration,
            sdkVersion: "MOCK_SDK_VERSION",
            targeting: targeting,
            extraParameterBuilders: nil
        )
        
        //Create a new SWPBMORTBBidRequest based off of the json string in the params dict
        guard let strORTB = paramsDict[PrebidConstants.OPEN_RTB_SCHEME] else {
            XCTFail("No ORTB string in parameter keys")
            return
        }
        
        let bidRequest: SWPBMORTBBidRequest
        do {
            bidRequest = try SWPBMORTBBidRequest.from(jsonString:strORTB)
        } catch {
            XCTFail("\(error)")
            return
        }
        
        //Verify GeoLocationParameterBuilder
        XCTAssertNil(bidRequest.device.geo.lat)
        XCTAssertNil(bidRequest.device.geo.lon)
        
        //Verify User Geo is not set
        XCTAssertNil(bidRequest.user.geo.lat)
        XCTAssertNil(bidRequest.user.geo.lon)
        
        //Verify ORTBParameterBuilder
        guard #available(iOS 11.0, *) else {
            Log.warn("iOS 11 or higher is needed to support the .sortedKeys option for JSONEncoding which puts keys in the order that they appear in the class. Before that, string encoding results are unpredictable.")
            return
        }
        
        var deviceExt = ""
        if #available(iOS 14.0, *) {
            deviceExt = "\"ext\":{\"atts\":3},"
        }

        let expectedOrtb = """
        {\"app\":{\"bundle\":\"Mock.Bundle.Identifier\",\"name\":\"MockBundleDisplayName\"},\"device\":{\"connectiontype\":2,\(deviceExt)\"h\":200,\"hwv\":\"iPhone1,1\",\"ifa\":\"abc123\",\"language\":\"ml\",\"lmt\":0,\"make\":\"MockMake\",\"model\":\"MockModel\",\"os\":\"MockOS\",\"osv\":\"1.2.3\",\"w\":100},\"imp\":[{\"clickbrowser\":1,\"displaymanager\":\"prebid-mobile\",\"displaymanagerver\":\"MOCK_SDK_VERSION\",\"ext\":{\"dlp\":1},\"instl\":0,\"secure\":1}],\"regs\":{\"coppa\":0}}
        """
        
        SWPBMAssertEq(strORTB, expectedOrtb)
    }
}
