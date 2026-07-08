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
import XCTest

@testable import SellwildPrebid

class SWPBMORTBAbstractTest : XCTestCase {
    
    private var sdkVersion: String {
        let infoDic = Bundle(for: BannerView.self).infoDictionary
        return infoDic!["CFBundleShortVersionString"] as! String
    }
    
    private var omidVersion: String {
        return SWPBMFunctions.sdkVersion();
    }
    
    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 OpenXSDK/\(SellwildPrebid.shared.version)"
    
    private var logToFile: LogToFileLock?
    
    override func tearDown() {
        logToFile = nil
        super.tearDown()
    }
    
    //Check default values of all objects decending from SWPBMORTBAbstract
    func testDefaultToJsonString() {
        
        codeAndDecode(abstract:SWPBMORTBBidRequest(), expectedString: "{\"imp\":[{\"clickbrowser\":1,\"ext\":{\"dlp\":1},\"instl\":0,\"secure\":0}]}")
        
        //Source not implemented
        codeAndDecode(abstract:SWPBMORTBRegs(), expectedString: "{}")
        codeAndDecode(abstract:SWPBMORTBImp(), expectedString: "{\"clickbrowser\":1,\"ext\":{\"dlp\":1},\"instl\":0,\"secure\":0}")
        
        //Metric not implemented
        codeAndDecode(abstract:SWPBMORTBBanner(), expectedString: "{}")
        codeAndDecode(abstract:SWPBMORTBVideo(), expectedString: "{}")
        
        //Audio not implemented
        //Native not implemented
        codeAndDecode(abstract:SWPBMORTBFormat(), expectedString: "{}")
        codeAndDecode(abstract:SWPBMORTBPmp(), expectedString: "{}")
        codeAndDecode(abstract:SWPBMORTBDeal(), expectedString: "{\"bidfloor\":0,\"bidfloorcur\":\"USD\",\"wadomain\":[],\"wseat\":[]}")
        
        //Site not implemented
        codeAndDecode(abstract:SWPBMORTBApp(), expectedString: "{}")
        //Publisher not implemented
        //Content not implemented
        //Producer not implemented
        codeAndDecode(abstract:SWPBMORTBDevice(), expectedString: "{}")
        codeAndDecode(abstract:SWPBMORTBGeo(), expectedString: "{}")
        codeAndDecode(abstract:SWPBMORTBUser(), expectedString: "{}")
        //Data not implemented
        //Segment not implemented
        
        codeAndDecode(abstract:SWPBMORTBBidRequestExtPrebid(), expectedString: "{}")
        codeAndDecode(abstract:SWPBMORTBImpExtPrebid(), expectedString: "{}")
        
        codeAndDecode(abstract: SWPBMORTBImpExtSkadn(), expectedString: "{}")
    }
    
    func testAbstractMethods() {
        logToFile = .init()
        
        let abstract = try! SWPBMORTBAbstract.from(jsonString: "")
        let _ = try! abstract.toJsonString()
        
        let log = Log.getLogFileAsString() ?? ""
        XCTAssert(log.contains("You should not initialize abstract class directly"))
        XCTAssert(log.contains("You must override toJsonDictionary in a subclass"))
    }
    
    func testCopying() {
        let initial = SWPBMORTBBidRequest()
        
        initial.imp[0].banner = SWPBMORTBBanner()
        initial.imp[0].video = SWPBMORTBVideo()
        initial.imp[0].pmp.deals = [SWPBMORTBDeal()]
        
        initial.imp[0].banner?.format = [SWPBMORTBFormat()]
        initial.imp[0].banner?.format[0].w = 640
        initial.imp[0].banner?.format[0].h = 480
        initial.imp[0].banner?.format[0].wratio = 4
        initial.imp[0].banner?.format[0].hratio = 3
        initial.imp[0].banner?.format[0].wmin = 160
        
        initial.extPrebid.storedRequestID = "testAccID"
        initial.imp[0].extPrebid.storedRequestID = "testCfgID"
        
        XCTAssertFalse(initial.imp[0].extPrebid.isRewardedInventory)
        initial.imp[0].extPrebid.isRewardedInventory = true
        
        let copy = initial.copy() as! SWPBMORTBBidRequest
        
        XCTAssertNotEqual(initial, copy)
        
        XCTAssertNotEqual(initial.imp, copy.imp)
        XCTAssertEqual(initial.imp.count, 1)
        XCTAssertEqual(initial.imp.count, copy.imp.count)
        for i in (0 ..< initial.imp.count) {
            
            let impInitial = initial.imp[i]
            let impCopy = copy.imp[i]
            
            XCTAssertNotEqual(impInitial, impCopy)
            
            XCTAssertNotEqual(impInitial.banner, impCopy.banner)
            
            XCTAssertFalse(impInitial.banner!.format as AnyObject === impCopy.banner!.format as AnyObject)
            XCTAssertFalse(impInitial.banner!.format[0] === impCopy.banner!.format[0])
            XCTAssertEqual(impInitial.banner?.format[0].w, impCopy.banner?.format[0].w)
            XCTAssertEqual(impInitial.banner?.format[0].h, impCopy.banner?.format[0].h)
            XCTAssertEqual(impInitial.banner?.format[0].wratio, impCopy.banner?.format[0].wratio)
            XCTAssertEqual(impInitial.banner?.format[0].hratio, impCopy.banner?.format[0].hratio)
            XCTAssertEqual(impInitial.banner?.format[0].wmin, impCopy.banner?.format[0].wmin)
            
            XCTAssertNotEqual(impInitial.video, impCopy.video)
            
            XCTAssertNotEqual(impInitial.extPrebid, impCopy.extPrebid)
            XCTAssertEqual(impInitial.extPrebid.storedRequestID, impCopy.extPrebid.storedRequestID)
            XCTAssertEqual(impInitial.extPrebid.isRewardedInventory, impCopy.extPrebid.isRewardedInventory)
            
            XCTAssertNotEqual(impInitial.pmp, impCopy.pmp)
            
            XCTAssertNotEqual(impInitial.pmp.deals, impCopy.pmp.deals)
            XCTAssertEqual(impInitial.pmp.deals.count, 1)
            XCTAssertEqual(impInitial.pmp.deals.count, impCopy.pmp.deals.count)
            
            for j in (0 ..< impInitial.pmp.deals.count) {
                XCTAssertNotEqual(impInitial.pmp.deals[j], impCopy.pmp.deals[j])
            }
        }
        
        XCTAssertNotEqual(initial.app, copy.app)
        
        XCTAssertNotEqual(initial.device, copy.device)
        XCTAssertNotEqual(initial.device.geo, copy.device.geo)
        
        XCTAssertNotEqual(initial.user, copy.user)
        XCTAssertNotEqual(initial.user.geo, copy.user.geo)
        
        XCTAssertNotEqual(initial.regs, copy.regs)
        
        XCTAssertNotEqual(initial.extPrebid, copy.extPrebid)
        XCTAssertEqual(initial.extPrebid.storedRequestID, copy.extPrebid.storedRequestID)
    }
    
    func testBidRequestToJsonString() {
        let swpbmORTBBidRequest = SWPBMORTBBidRequest()
        let uuid = UUID().uuidString
        swpbmORTBBidRequest.requestID = uuid
        
        codeAndDecode(abstract: swpbmORTBBidRequest, expectedString: "{\"id\":\"\(uuid)\",\"imp\":[{\"clickbrowser\":1,\"ext\":{\"dlp\":1},\"instl\":0,\"secure\":0}]}")
        
        swpbmORTBBidRequest.tmax = 2000
        
        codeAndDecode(abstract: swpbmORTBBidRequest, expectedString: "{\"id\":\"\(uuid)\",\"imp\":[{\"clickbrowser\":1,\"ext\":{\"dlp\":1},\"instl\":0,\"secure\":0}],\"tmax\":2000}")
        
        swpbmORTBBidRequest.test = 2
        
        codeAndDecode(abstract: swpbmORTBBidRequest, expectedString: "{\"id\":\"\(uuid)\",\"imp\":[{\"clickbrowser\":1,\"ext\":{\"dlp\":1},\"instl\":0,\"secure\":0}],\"test\":2,\"tmax\":2000}")
    }
    
    func testBidRequestExtPrebidToJsonString() {
        let extPrebid = SWPBMORTBBidRequestExtPrebid()
        extPrebid.storedRequestID = "b4eb1475-4e3d-4186-97b7-25b6a6cf8618"
        extPrebid.dataBidders = ["openx", "prebid", "thanatos"]
        extPrebid.storedAuctionResponse = "stored-auction-response-test"
        extPrebid.sdkRenderers = [["name": "MockRenderer1", "version": "0.0.1"], ["name": "MockRenderer2", "version": "0.0.2"]]
        
        codeAndDecode(abstract: extPrebid, expectedString: "{\"data\":{\"bidders\":[\"openx\",\"prebid\",\"thanatos\"]},\"sdk\":{\"renderers\":[{\"name\":\"MockRenderer1\",\"version\":\"0.0.1\"},{\"name\":\"MockRenderer2\",\"version\":\"0.0.2\"}]},\"storedauctionresponse\":{\"id\":\"stored-auction-response-test\"},\"storedrequest\":{\"id\":\"b4eb1475-4e3d-4186-97b7-25b6a6cf8618\"},\"targeting\":{}}")
        
        let swpbmORTBBidRequest = SWPBMORTBBidRequest()
        swpbmORTBBidRequest.extPrebid = extPrebid
        
        codeAndDecode(abstract: swpbmORTBBidRequest, expectedString: "{\"ext\":{\"prebid\":{\"data\":{\"bidders\":[\"openx\",\"prebid\",\"thanatos\"]},\"sdk\":{\"renderers\":[{\"name\":\"MockRenderer1\",\"version\":\"0.0.1\"},{\"name\":\"MockRenderer2\",\"version\":\"0.0.2\"}]},\"storedauctionresponse\":{\"id\":\"stored-auction-response-test\"},\"storedrequest\":{\"id\":\"b4eb1475-4e3d-4186-97b7-25b6a6cf8618\"},\"targeting\":{}}},\"imp\":[{\"clickbrowser\":1,\"ext\":{\"dlp\":1},\"instl\":0,\"secure\":0}]}")
    }
    
    func testSourceToJsonString() {
        let swpbmORTBSource = SWPBMORTBSource()
        
        let tid = UUID().uuidString
        let pchain = "some_pchain_string"
        
        swpbmORTBSource.fd = 0
        swpbmORTBSource.tid = tid
        swpbmORTBSource.pchain = pchain
        
        codeAndDecode(abstract: swpbmORTBSource, expectedString: "{\"fd\":0,\"pchain\":\"\(pchain)\",\"tid\":\"\(tid)\"}")
    }
    
    func testRegsToJsonString() {
        let swpbmORTBRegs = SWPBMORTBRegs()
        swpbmORTBRegs.coppa = 1
        XCTAssertEqual(swpbmORTBRegs.coppa, 1)
        codeAndDecode(abstract:swpbmORTBRegs, expectedString:"{\"coppa\":1}")
        
        swpbmORTBRegs.coppa = 0
        XCTAssertEqual(swpbmORTBRegs.coppa, 0)
        codeAndDecode(abstract:swpbmORTBRegs, expectedString:"{\"coppa\":0}")
        
        swpbmORTBRegs.coppa = -1
        XCTAssertEqual(swpbmORTBRegs.coppa, nil)
        codeAndDecode(abstract:swpbmORTBRegs, expectedString:"{}")
        
        swpbmORTBRegs.coppa = 1.5
        XCTAssertEqual(swpbmORTBRegs.coppa, nil)
        codeAndDecode(abstract:swpbmORTBRegs, expectedString:"{}")
    }
    
    // MARK: SWPBMORTBImp
    
    func testImpToJsonString() {
        let swpbmORTBImp = SWPBMORTBImp()
        
        let uuid = UUID().uuidString
        swpbmORTBImp.impID = uuid
        swpbmORTBImp.banner = SWPBMORTBBanner()
        swpbmORTBImp.video = SWPBMORTBVideo()
        swpbmORTBImp.native = ORTBNative()
        swpbmORTBImp.pmp = SWPBMORTBPmp()
        swpbmORTBImp.displaymanager = "MOCK_SDK_NAME"
        swpbmORTBImp.displaymanagerver = "MOCK_SDK_VERSION"
        swpbmORTBImp.instl = 1
        swpbmORTBImp.rewarded = 1
        swpbmORTBImp.tagid = "tagid"
        swpbmORTBImp.secure = 1
        swpbmORTBImp.extData = ["lookup_words": ["dragon", "flame"]]
        
        codeAndDecode(abstract: swpbmORTBImp, expectedString: "{\"clickbrowser\":1,\"displaymanager\":\"MOCK_SDK_NAME\",\"displaymanagerver\":\"MOCK_SDK_VERSION\",\"ext\":{\"data\":{\"lookup_words\":[\"dragon\",\"flame\"]},\"dlp\":1},\"id\":\"\(uuid)\",\"instl\":1,\"native\":{\"ver\":\"1.2\"},\"rwdd\":1,\"secure\":1,\"tagid\":\"tagid\"}")
    }
    
    func testSWPBMORTBImpExtSkadnToJsonString() { 
        let skadn = SWPBMORTBImpExtSkadn()
        skadn.sourceapp = "12345678"
        skadn.skadnetids = ["1", "2", "3"]
        
        var expectedString = "{\"skadnetids\":[\"1\",\"2\",\"3\"],\"sourceapp\":\"12345678\",\"versions\":\(SWPBMFunctions.supportedSKAdNetworkVersions())}"
        expectedString.removeAll(where: { $0 == " "})
        
        codeAndDecode(abstract: skadn, expectedString: expectedString)
    }
    
    func testNativeToJsonString() {
        let swpbmORTBNative = ORTBNative()
        
        XCTAssertEqual(swpbmORTBNative.ver, "1.2")
        XCTAssertNil(swpbmORTBNative.request as NSString?)
        XCTAssertNil(swpbmORTBNative.api)
        XCTAssertNil(swpbmORTBNative.battr)
        
        codeAndDecode(abstract: swpbmORTBNative, expectedString: "{\"ver\":\"1.2\"}")
        
        swpbmORTBNative.request = "some request string goes here"
        swpbmORTBNative.api = [42]
        swpbmORTBNative.battr = [1, 3, 13]
        
        codeAndDecode(abstract: swpbmORTBNative, expectedString: "{\"api\":[42],\"battr\":[1,3,13],\"request\":\"some request string goes here\",\"ver\":\"1.2\"}")
    }
    
    func testImpExtPrebidToJsonString() {
        let extPrebid = SWPBMORTBImpExtPrebid()
        extPrebid.storedRequestID = "b4eb1475-4e3d-4186-97b7-25b6a6cf8618"
        XCTAssertFalse(extPrebid.isRewardedInventory)
        
        codeAndDecode(abstract: extPrebid, expectedString: "{\"storedrequest\":{\"id\":\"b4eb1475-4e3d-4186-97b7-25b6a6cf8618\"}}")
        
        let swpbmORTBImp = SWPBMORTBImp()
        swpbmORTBImp.extPrebid = extPrebid
        
        codeAndDecode(abstract: swpbmORTBImp, expectedString: "{\"clickbrowser\":1,\"ext\":{\"prebid\":{\"storedrequest\":{\"id\":\"b4eb1475-4e3d-4186-97b7-25b6a6cf8618\"}}},\"instl\":0,\"secure\":0}")
    }
    
    func testImpExtPrebidToJsonStringRewarded() {
        let extPrebid = SWPBMORTBImpExtPrebid()
        extPrebid.storedRequestID = "b4eb1475-4e3d-4186-97b7-25b6a6cf8618"
        extPrebid.isRewardedInventory = true
        
        codeAndDecode(abstract: extPrebid, expectedString: "{\"is_rewarded_inventory\":1,\"storedrequest\":{\"id\":\"b4eb1475-4e3d-4186-97b7-25b6a6cf8618\"}}")
        
        let swpbmORTBImp = SWPBMORTBImp()
        swpbmORTBImp.extPrebid = extPrebid
        
        codeAndDecode(abstract: swpbmORTBImp, expectedString: "{\"clickbrowser\":1,\"ext\":{\"prebid\":{\"is_rewarded_inventory\":1,\"storedrequest\":{\"id\":\"b4eb1475-4e3d-4186-97b7-25b6a6cf8618\"}}},\"instl\":0,\"secure\":0}")
    }
    
    func testImpExtGPID() {
        let gpid = "/12345/home_screen#identifier"
        
        let imp = SWPBMORTBImp()
        imp.extGPID = gpid
        
        codeAndDecode(abstract: imp, expectedString: "{\"clickbrowser\":1,\"ext\":{\"dlp\":1,\"gpid\":\"\\/12345\\/home_screen#identifier\"},\"instl\":0,\"secure\":0}")
    }
    
    func testBannerToJsonString() {
        let swpbmORTBBanner = SWPBMORTBBanner()
        swpbmORTBBanner.pos = 1                   //Above the fold
        swpbmORTBBanner.api = [2,5]
        
        codeAndDecode(abstract: swpbmORTBBanner, expectedString: "{\"api\":[2,5],\"pos\":1}")
        
        swpbmORTBBanner.format = [SWPBMORTBFormat()]
        swpbmORTBBanner.format[0].w = 728
        swpbmORTBBanner.format[0].h = 90
        
        codeAndDecode(abstract: swpbmORTBBanner, expectedString: "{\"api\":[2,5],\"format\":[{\"h\":90,\"w\":728}],\"pos\":1}")
    }
    
    func testVideoToJsonString() {
        let swpbmORTBVideo = SWPBMORTBVideo()
        
        swpbmORTBVideo.minduration = 10
        swpbmORTBVideo.maxduration = 100
        swpbmORTBVideo.w = 100
        swpbmORTBVideo.h = 200
        swpbmORTBVideo.startdelay = 5
        swpbmORTBVideo.linearity = 1
        swpbmORTBVideo.minbitrate = 20
        swpbmORTBVideo.maxbitrate = 40
        swpbmORTBVideo.mimes = PrebidConstants.SUPPORTED_VIDEO_MIME_TYPES
        swpbmORTBVideo.protocols = [2, 5]
        swpbmORTBVideo.pos = 7
        swpbmORTBVideo.delivery = [3]
        swpbmORTBVideo.playbackend = 2
        
        codeAndDecode(abstract: swpbmORTBVideo, expectedString: "{\"delivery\":[3],\"h\":200,\"linearity\":1,\"maxbitrate\":40,\"maxduration\":100,\"mimes\":[\"video\\/mp4\",\"video\\/quicktime\",\"video\\/x-m4v\",\"video\\/3gpp\",\"video\\/3gpp2\"],\"minbitrate\":20,\"minduration\":10,\"playbackend\":2,\"pos\":7,\"protocols\":[2,5],\"startdelay\":5,\"w\":100}")
    }
    
    func testFormatToJsonString() {
        let swpbmORTBFormat = SWPBMORTBFormat()
        swpbmORTBFormat.w = 320
        swpbmORTBFormat.h = 50
        codeAndDecode(abstract: swpbmORTBFormat, expectedString: "{\"h\":50,\"w\":320}")
        
        swpbmORTBFormat.w = nil
        swpbmORTBFormat.h = nil
        swpbmORTBFormat.wratio = 16
        swpbmORTBFormat.hratio = 9
        swpbmORTBFormat.wmin = 60
        codeAndDecode(abstract: swpbmORTBFormat, expectedString: "{\"hratio\":9,\"wmin\":60,\"wratio\":16}")
    }
    
    func testPmpToJsonString() {
        let swpbmORTBPmp = SWPBMORTBPmp()
        swpbmORTBPmp.private_auction = 1
        swpbmORTBPmp.deals.append(SWPBMORTBDeal())
        swpbmORTBPmp.deals.first?.bidfloor = 1.0
        
        codeAndDecode(abstract: swpbmORTBPmp, expectedString: "{\"deals\":[{\"bidfloor\":1,\"bidfloorcur\":\"USD\",\"wadomain\":[],\"wseat\":[]}],\"private_auction\":1}")
    }
    
    func testDealToJsonString() {
        let swpbmORTBDeal = SWPBMORTBDeal()
        
        swpbmORTBDeal.id = "id"
        swpbmORTBDeal.bidfloor = 100.0
        swpbmORTBDeal.bidfloorcur = "GBP"
        swpbmORTBDeal.at = 1
        swpbmORTBDeal.wseat = ["seat1", "seat2", "seat3"]
        swpbmORTBDeal.wadomain = ["advertiser1.com", "advertiser2.com", "advertiser3.com"]
        
        codeAndDecode(abstract: swpbmORTBDeal, expectedString: "{\"at\":1,\"bidfloor\":100,\"bidfloorcur\":\"GBP\",\"id\":\"id\",\"wadomain\":[\"advertiser1.com\",\"advertiser2.com\",\"advertiser3.com\"],\"wseat\":[\"seat1\",\"seat2\",\"seat3\"]}")
    }
    
    func testAppToJsonString() {
        
        let swpbmORTBApp = SWPBMORTBApp()
        
        swpbmORTBApp.id = "foo"
        swpbmORTBApp.name = "PubApp"
        swpbmORTBApp.bundle = "com.PubApp"
        swpbmORTBApp.domain = "pubapp.com"
        swpbmORTBApp.storeurl = "itunes.com?pubapp"
        swpbmORTBApp.ver = "1.2"
        swpbmORTBApp.privacypolicy = 1
        swpbmORTBApp.paid = 1
        swpbmORTBApp.keywords = "foo,bar,baz"
        swpbmORTBApp.content = ORTBAppContent()
        swpbmORTBApp.content?.url = "https://corresponding.section.publishers.website"
        
        codeAndDecode(abstract: swpbmORTBApp, expectedString: "{\"bundle\":\"com.PubApp\",\"content\":{\"url\":\"https:\\/\\/corresponding.section.publishers.website\"},\"domain\":\"pubapp.com\",\"id\":\"foo\",\"keywords\":\"foo,bar,baz\",\"name\":\"PubApp\",\"paid\":1,\"privacypolicy\":1,\"storeurl\":\"itunes.com?pubapp\",\"ver\":\"1.2\"}")
    }
    
    func testAppContentToJsonString() {
        let appContent = ORTBAppContent()
        appContent.episode = 2
        appContent.title = "title"
        appContent.series = "series"
        appContent.season = "season"
        appContent.artist = "artist"
        appContent.genre = "genre"
        appContent.album = "album"
        appContent.isrc = "isrc"
        
        let producer = ORTBContentProducer()
        producer.name = "producerName"
        producer.cat = ["producerCat"]
        producer.domain = "domain"
        
        appContent.producer = producer
        appContent.cat = ["cat"]
        appContent.prodq = 1
        appContent.context = 1
        appContent.contentrating = "contentrating"
        appContent.userrating = "userrating"
        appContent.qagmediarating = 1
        appContent.keywords = "keywords"
        appContent.livestream = 0
        appContent.sourcerelationship = 0
        appContent.len = 1
        appContent.language = "language"
        appContent.embeddable = 0
        
        let data = ORTBContentData()
        data.name = "dataName"
        
        let segment = ORTBContentSegment()
        segment.name = "segmentName"
        segment.value = "segmentValue"
        data.segment = [segment]
        
        appContent.data = [data]
        appContent.url = "https://www.url.com"
        
        codeAndDecode(abstract: appContent, expectedString: "{\"album\":\"album\",\"artist\":\"artist\",\"cat\":[\"cat\"],\"contentrating\":\"contentrating\",\"context\":1,\"data\":[{\"name\":\"dataName\",\"segment\":[{\"name\":\"segmentName\",\"value\":\"segmentValue\"}]}],\"embeddable\":0,\"episode\":2,\"genre\":\"genre\",\"isrc\":\"isrc\",\"keywords\":\"keywords\",\"language\":\"language\",\"len\":1,\"livestream\":0,\"prodq\":1,\"producer\":{\"cat\":[\"producerCat\"],\"domain\":\"domain\",\"name\":\"producerName\"},\"qagmediarating\":1,\"season\":\"season\",\"series\":\"series\",\"sourcerelationship\":0,\"title\":\"title\",\"url\":\"https:\\/\\/www.url.com\",\"userrating\":\"userrating\"}")
    }
    
    func testAppExtPrebidToJsonString() {
        let swpbmORTBApp = SWPBMORTBApp()
        let appExtPrebid = swpbmORTBApp.ext.prebid
        
        codeAndDecode(abstract: appExtPrebid, expectedString: "{}")
        
        appExtPrebid.source = "openx"
        appExtPrebid.version = sdkVersion
        swpbmORTBApp.ext.data = ["app_categories": ["news", "movies"]]
        
        codeAndDecode(abstract: appExtPrebid, expectedString: "{\"source\":\"openx\",\"version\":\"\(sdkVersion)\"}")
        
        codeAndDecode(abstract: swpbmORTBApp, expectedString: "{\"ext\":{\"data\":{\"app_categories\":[\"news\",\"movies\"]},\"prebid\":{\"source\":\"openx\",\"version\":\"\(sdkVersion)\"}}}")
    }
    
    func testDeviceWithIfaToJsonString() {
        let swpbmORTBPDevice = initORTBDevice(ifa: "ifa")
        swpbmORTBPDevice.ua = userAgent
        let userAgentEscaped = userAgent.replacingOccurrences(of: "/", with: "\\/")
        codeAndDecode(abstract: swpbmORTBPDevice, expectedString: "{\"carrier\":\"AT&T\",\"connectiontype\":6,\"devicetype\":1,\"didmd5\":\"didmd5\",\"didsha1\":\"didsha1\",\"geofetch\":1,\"h\":100,\"hwv\":\"X\",\"ifa\":\"ifa\",\"js\":1,\"language\":\"en\",\"lmt\":1,\"make\":\"Apple\",\"mccmnc\":\"310-680\",\"model\":\"iPhone\",\"os\":\"iOS\",\"osv\":\"11.1\",\"ppi\":100,\"pxratio\":1.5,\"ua\":\"\(userAgentEscaped)\",\"w\":200}")
    }
    
    func testDeviceWithoutIfaToJsonString() {
        let swpbmORTBPDevice = initORTBDevice(ifa: nil)
        swpbmORTBPDevice.ua = userAgent
        let userAgentEscaped = userAgent.replacingOccurrences(of: "/", with: "\\/")
        codeAndDecode(abstract: swpbmORTBPDevice, expectedString: "{\"carrier\":\"AT&T\",\"connectiontype\":6,\"devicetype\":1,\"didmd5\":\"didmd5\",\"didsha1\":\"didsha1\",\"dpidmd5\":\"dpidmd5\",\"dpidsha1\":\"dpidsha1\",\"geofetch\":1,\"h\":100,\"hwv\":\"X\",\"js\":1,\"language\":\"en\",\"lmt\":1,\"macmd5\":\"macmd5\",\"macsha1\":\"macsha1\",\"make\":\"Apple\",\"mccmnc\":\"310-680\",\"model\":\"iPhone\",\"os\":\"iOS\",\"osv\":\"11.1\",\"ppi\":100,\"pxratio\":1.5,\"ua\":\"\(userAgentEscaped)\",\"w\":200}")
    }
    
    func testDeviceWithExtAttsToJsonString() {
        let swpbmORTBPDevice = initORTBDevice(ifa: nil)
        swpbmORTBPDevice.ua = userAgent
        swpbmORTBPDevice.extAtts.atts = 3
        swpbmORTBPDevice.extAtts.ifv = "ifv"
        
        let userAgentEscaped = userAgent.replacingOccurrences(of: "/", with: "\\/")
        codeAndDecode(abstract: swpbmORTBPDevice, expectedString: "{\"carrier\":\"AT&T\",\"connectiontype\":6,\"devicetype\":1,\"didmd5\":\"didmd5\",\"didsha1\":\"didsha1\",\"dpidmd5\":\"dpidmd5\",\"dpidsha1\":\"dpidsha1\",\"ext\":{\"atts\":3,\"ifv\":\"ifv\"},\"geofetch\":1,\"h\":100,\"hwv\":\"X\",\"js\":1,\"language\":\"en\",\"lmt\":1,\"macmd5\":\"macmd5\",\"macsha1\":\"macsha1\",\"make\":\"Apple\",\"mccmnc\":\"310-680\",\"model\":\"iPhone\",\"os\":\"iOS\",\"osv\":\"11.1\",\"ppi\":100,\"pxratio\":1.5,\"ua\":\"\(userAgentEscaped)\",\"w\":200}")
    }
    
    func testGeoToJsonString() {
        let swpbmORTBGeo = SWPBMORTBGeo()
        
        swpbmORTBGeo.lat = 34.1477849
        swpbmORTBGeo.lon = -118.1445155
        swpbmORTBGeo.type = 1
        swpbmORTBGeo.accuracy = 200
        swpbmORTBGeo.lastfix = 5
        swpbmORTBGeo.country = "USA"
        swpbmORTBGeo.region = "CA"
        swpbmORTBGeo.regionfips104 = "US"
        swpbmORTBGeo.metro = "foo"
        swpbmORTBGeo.city = "Pasadena"
        swpbmORTBGeo.zip = "91101"
        swpbmORTBGeo.utcoffset = -480
        
        codeAndDecode(abstract: swpbmORTBGeo, expectedString: "{\"accuracy\":200,\"city\":\"Pasadena\",\"country\":\"USA\",\"lastfix\":5,\"lat\":34.1477849,\"lon\":-118.1445155,\"metro\":\"foo\",\"region\":\"CA\",\"regionfips104\":\"US\",\"type\":1,\"utcoffset\":-480,\"zip\":\"91101\"}")
    }
    
    func testUserToJsonString() {
        let swpbmORTBUser = SWPBMORTBUser()
        
        swpbmORTBUser.keywords = "key1,key2,key3"
        swpbmORTBUser.geo.lat = 34.1477849
        swpbmORTBUser.geo.lon = -118.1445155
        swpbmORTBUser.ext!["data"] = ["registration_date": "31.02.2021"]
        swpbmORTBUser.userid = "userid"
        
        codeAndDecode(
            abstract: swpbmORTBUser,
            expectedString: "{\"ext\":{\"data\":{\"registration_date\":\"31.02.2021\"}},\"geo\":{\"lat\":34.1477849,\"lon\":-118.1445155},\"id\":\"userid\",\"keywords\":\"key1,key2,key3\"}"
        )
    }
    
    func testUserEidsToJsonString() {
        let user = SWPBMORTBUser()
        
        user.appendEids([["key": ["key":"value"]]])
        
        codeAndDecode(
            abstract: user,
            expectedString: "{\"ext\":{\"eids\":[{\"key\":{\"key\":\"value\"}}]}}"
        )
    }
    
    func testUserEidsInExtToJsonString() {
        let user = SWPBMORTBUser()
        
        user.ext = ["eids":[["key": ["key":"value"]]]]
        
        codeAndDecode(
            abstract: user,
            expectedString: "{\"ext\":{\"eids\":[{\"key\":{\"key\":\"value\"}}]}}"
        )
    }
    
    func testUserEidsAndExtToJsonString() {
        let user = SWPBMORTBUser()
        
        user.ext = ["eids":[["key": ["key":"value"]]]]
        user.appendEids([["key2": ["key2":"value2"]]])
        
        codeAndDecode(
            abstract: user,
            expectedString: "{\"ext\":{\"eids\":[{\"key\":{\"key\":\"value\"}},{\"key2\":{\"key2\":\"value2\"}}]}}"
        )
    }
    
    // MARK: - Utility
    
    func initORTBDevice(ifa: String?) -> SWPBMORTBDevice {
        let swpbmORTBPDevice = SWPBMORTBDevice()
        swpbmORTBPDevice.lmt = 1
        swpbmORTBPDevice.devicetype = 1
        swpbmORTBPDevice.make = "Apple"
        swpbmORTBPDevice.model = "iPhone"
        swpbmORTBPDevice.os = "iOS"
        swpbmORTBPDevice.osv = "11.1"
        swpbmORTBPDevice.hwv = "X"
        swpbmORTBPDevice.h = 100
        swpbmORTBPDevice.w = 200
        swpbmORTBPDevice.ppi = 100
        swpbmORTBPDevice.pxratio = 1.5
        swpbmORTBPDevice.js = 1
        swpbmORTBPDevice.geofetch = 1
        swpbmORTBPDevice.language = "en"
        swpbmORTBPDevice.carrier = "AT&T"
        swpbmORTBPDevice.mccmnc = "310-680"
        swpbmORTBPDevice.connectiontype = 6
        swpbmORTBPDevice.ifa = ifa
        swpbmORTBPDevice.didsha1 = "didsha1"
        swpbmORTBPDevice.didmd5 = "didmd5"
        swpbmORTBPDevice.dpidsha1 = "dpidsha1"
        swpbmORTBPDevice.dpidmd5 = "dpidmd5"
        swpbmORTBPDevice.macsha1 = "macsha1"
        swpbmORTBPDevice.macmd5 = "macmd5"
        return swpbmORTBPDevice
    }
    
    func codeAndDecode<T : SWPBMORTBAbstract>(abstract:T, expectedString:String, file: StaticString = #file, line: UInt = #line) {
        
        guard #available(iOS 11.0, *) else {
            Log.warn("iOS 11 or higher is needed to support the .sortedKeys option for JSONEncoding which puts keys in the order that they appear in the class. Before that, string encoding results are unpredictable.")
            return
        }
        
        do {
            //Make a copy of the object
            let newCodable = abstract as SWPBMORTBAbstract
            
            //Convert it to json
            let newJsonString = try newCodable.toJsonString()
            
            //Strings should match
            SWPBMAssertEq(newJsonString, expectedString, file:file, line:line)
        } catch {
            XCTFail("\(error)", file:file, line:line)
        }
    }
    
    func codeAndDecode<T : SWPBMJsonCodable>(abstract:T, expectedString:String, file: StaticString = #file, line: UInt = #line) {
        
        guard #available(iOS 11.0, *) else {
            Log.warn("iOS 11 or higher is needed to support the .sortedKeys option for JSONEncoding which puts keys in the order that they appear in the class. Before that, string encoding results are unpredictable.")
            return
        }
        
        do {
            //Convert it to json
            let newJsonString = try abstract.toJsonString()
            
            //Strings should match
            SWPBMAssertEq(newJsonString, expectedString, file:file, line:line)
        } catch {
            XCTFail("\(error)", file:file, line:line)
        }
    }
}
