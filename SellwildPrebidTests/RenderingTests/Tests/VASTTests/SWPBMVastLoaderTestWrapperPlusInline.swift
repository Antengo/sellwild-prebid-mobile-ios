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

import XCTest

@testable @_spi(SWPBMInternal) import SellwildPrebid

class SWPBMVastLoaderTestWrapperPlusInline: XCTestCase {
    
    var didFetchInline:XCTestExpectation!
    var vastRequestSuccessfulExpectation:XCTestExpectation!
    
    var vastServerResponse: SWPBMAdRequestResponseVAST?
    
    override func setUp() {
        self.continueAfterFailure = true
        MockServer.shared.reset()
    }
    
    override func tearDown() {
        MockServer.shared.reset()
        self.didFetchInline = nil
        self.vastRequestSuccessfulExpectation = nil
    }
    
    func testRequest() {
        
        self.didFetchInline = self.expectation(description: "Expected PrebidServerConnection to hit foo.com/inline")
        self.vastRequestSuccessfulExpectation = self.expectation(description: "vastRequestSuccessfulExpectation #1")
        
        let conn = UtilitiesForTesting.createConnectionForMockedTest()
        
        ////////////////////////////
        //Mock a server at "foo.com"
        ////////////////////////////
        MockServer.shared.reset()
        let ruleInline =  MockServerRule(urlNeedle: "foo.com/inline/vast", mimeType:  MockServerMimeType.XML.rawValue, connectionID: conn.internalID, fileName: "document_with_one_inline_ad.xml")
        ruleInline.mockServerReceivedRequestHandler = { (urlRequest:URLRequest) in
            Log.info("didFetchInline.fulfill()")
            self.didFetchInline.fulfill()
        }
        
        MockServer.shared.resetRules([ruleInline])
        
        //Handle 404's
        MockServer.shared.notFoundRule.mockServerReceivedRequestHandler = { (urlRequest:URLRequest) in
            XCTFail("Unexpected request for \(urlRequest)")
        }
        
        //////////////////////////////////////////////////////////////////////////////////
        //Make an PrebidServerConnection and redirect its network requests to the Mock Server
        //////////////////////////////////////////////////////////////////////////////////
        
        
        let adConfiguration = AdConfiguration()
        
        let adLoadManager = MockSWPBMAdLoadManagerVAST(bid: RawWinningBidFabricator.makeWinningBid(price: 0.1, bidder: "bidder", cacheID: "cache-id"), connection:conn, adConfiguration: adConfiguration)
        
        adLoadManager.mock_requestCompletedSuccess = { response in
            self.vastServerResponse = response
            self.vastRequestSuccessfulExpectation.fulfill()
        }
        
        adLoadManager.mock_requestCompletedFailure = { error in
            XCTFail(error.localizedDescription)
        }
        
        let requester = SWPBMAdRequesterVAST(serverConnection:conn, adConfiguration: adConfiguration)
        requester.adLoadManager = adLoadManager
        
        if let data = UtilitiesForTesting.loadFileAsDataFromBundle("document_with_one_wrapper_ad.xml") {
            requester.buildAdsArray(data)
        }
        
        self.waitForExpectations(timeout: 2)
        
        guard let response = self.vastServerResponse else {
            XCTFail()
            return
        }
        
        check(response)
        
        let inlineVastRequestSuccessfulExpectation = self.expectation(description: "Expected Inline VAST Load to be successful")
        
        let modelMaker = SWPBMCreativeModelCollectionMakerVAST(serverConnection:conn, adConfiguration: adConfiguration)
        
        
        modelMaker.makeModels(response,
                              successCallback: { models in
            let createModelCount = 2  // For video interstitials with End Card, count is 2. Includes all companions.
            XCTAssertEqual(models.count, createModelCount)
            inlineVastRequestSuccessfulExpectation.fulfill()
        },
                              failureCallback: { error in
            inlineVastRequestSuccessfulExpectation.fulfill()
            XCTFail(error.localizedDescription)
        })
        
        self.waitForExpectations(timeout: 10, handler: nil)
    }
    
    // MARK: - Check result
    
    func check(_ response: NSObject) {
        guard let vastResponse = response as? SWPBMAdRequestResponseVAST else {
            XCTFail()
            return
        }
        
        guard let ads = vastResponse.ads else {
            XCTFail()
            return
        }
        
        //There should be 1 ad.
        //An Ad can be either inline or wrapper; this should be inline.
        if (ads.count != 1) {
            XCTFail("Expected 1 ad, got \(ads.count)")
            return
        }
        
        let ad = ads.first!
        
        SWPBMAssertEq(ad.adSystem, "Inline AdSystem")
        SWPBMAssertEq(ad.adSystemVersion, "1.0")
        SWPBMAssertEq(ad.errorURIs, ["http://myErrorURL/AdError"])
        SWPBMAssertEq(ad.impressionURIs, ["http://myTrackingURL/inline/impression", "http://myTrackingURL/inline/anotherImpression", "http://myTrackingURL/wrapper/impression", "http://myTrackingURL/wrapper/anotherImpression"])
        
        //There should be 3 creatives:
        //a Linear Creative
        //a Companion ad Creative composed of two companions (an image and an iframe)
        //And a NonlinearAds Creative composed of two Nonlinear ads (an image and an iframe)
        SWPBMAssertEq(ad.creatives.count, 3)
        
        //Creative 1  - Linear
        let swpbmVastCreativeLinear = ad.creatives[0] as! SWPBMVastCreativeLinear
        SWPBMAssertEq(swpbmVastCreativeLinear.AdId, "601364")
        SWPBMAssertEq(swpbmVastCreativeLinear.id, "6012")
        SWPBMAssertEq(swpbmVastCreativeLinear.sequence, 1)
        SWPBMAssertEq(swpbmVastCreativeLinear.duration, 6)
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["creativeView"], ["http://myTrackingURL/inline/creativeView", "http://myTrackingURL/wrapper/creativeView"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["start"], ["http://myTrackingURL/inline/start1", "http://myTrackingURL/inline/start2", "http://myTrackingURL/wrapper/start1", "http://myTrackingURL/wrapper/start2"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["midpoint"], ["http://myTrackingURL/inline/midpoint", "http://myTrackingURL/wrapper/midpoint"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["firstQuartile"], ["http://myTrackingURL/inline/firstQuartile", "http://myTrackingURL/wrapper/firstQuartile"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["thirdQuartile"], ["http://myTrackingURL/inline/thirdQuartile", "http://myTrackingURL/wrapper/thirdQuartile"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["complete"], ["http://myTrackingURL/inline/complete", "http://myTrackingURL/wrapper/complete"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["mute"], ["http://myTrackingURL/inline/mute", "http://myTrackingURL/wrapper/mute"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["unmute"], ["http://myTrackingURL/inline/unmute", "http://myTrackingURL/wrapper/unmute"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["pause"], ["http://myTrackingURL/inline/pause", "http://myTrackingURL/wrapper/pause"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["rewind"], ["http://myTrackingURL/inline/rewind", "http://myTrackingURL/wrapper/rewind"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["resume"], ["http://myTrackingURL/inline/resume", "http://myTrackingURL/wrapper/resume"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["fullscreen"], ["http://myTrackingURL/inline/fullscreen", "http://myTrackingURL/wrapper/fullscreen"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["expand"], ["http://myTrackingURL/inline/expand", "http://myTrackingURL/wrapper/expand"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["collapse"], ["http://myTrackingURL/inline/collapse", "http://myTrackingURL/wrapper/collapse"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["acceptInvitation"], ["http://myTrackingURL/inline/acceptInvitation", "http://myTrackingURL/wrapper/acceptInvitation"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["close"], ["http://myTrackingURL/inline/close", "http://myTrackingURL/wrapper/close"])
        
        SWPBMAssertEq(swpbmVastCreativeLinear.adParameters, "params=for&request=gohere")
        SWPBMAssertEq(swpbmVastCreativeLinear.clickThroughURI, "http://www.openx.com")
        SWPBMAssertEq(swpbmVastCreativeLinear.clickTrackingURIs, ["http://myTrackingURL/inline/click1", "http://myTrackingURL/inline/click2", "http://myTrackingURL/inline/custom1", "http://myTrackingURL/inline/custom2", "http://myTrackingURL/wrapper/click1", "http://myTrackingURL/wrapper/click2", "http://myTrackingURL/wrapper/custom1", "http://myTrackingURL/wrapper/custom2"])
        
        SWPBMAssertEq(swpbmVastCreativeLinear.mediaFiles.count, 1)
        
        let mediaFile = swpbmVastCreativeLinear.mediaFiles.firstObject as! SWPBMVastMediaFile
        SWPBMAssertEq(mediaFile.id, "firstFile")
        SWPBMAssertEq(mediaFile.streamingDeliver, false)
        SWPBMAssertEq(mediaFile.type, "video/mp4")
        SWPBMAssertEq(mediaFile.bitrate, 500)
        SWPBMAssertEq(mediaFile.width, 400)
        SWPBMAssertEq(mediaFile.height, 300)
        SWPBMAssertEq(mediaFile.scalable, true)
        SWPBMAssertEq(mediaFile.maintainAspectRatio, true)
        SWPBMAssertEq(mediaFile.apiFramework, "VPAID")
        SWPBMAssertEq(mediaFile.mediaURI, "http://get_video_file")
        
        
        //Creative 2 - CompanionAds
        let swpbmVastCreativeCompanionAds = ad.creatives[1] as! SWPBMVastCreativeCompanionAds
        SWPBMAssertEq(swpbmVastCreativeCompanionAds.companions.count, 2)
        
        //First Companion
        let swpbmVastCreativeCompanionAdsCompanion = swpbmVastCreativeCompanionAds.companions[0] as! SWPBMVastCreativeCompanionAdsCompanion
        SWPBMAssertEq(swpbmVastCreativeCompanionAdsCompanion.companionIdentifier, "big_box")
        SWPBMAssertEq(swpbmVastCreativeCompanionAdsCompanion.width, 300)
        SWPBMAssertEq(swpbmVastCreativeCompanionAdsCompanion.height, 250)
        //Should we support expandedWidth="600" expandedHeight="500" apiFramework="VPAID" ??
        SWPBMAssertEq(swpbmVastCreativeCompanionAdsCompanion.resource, "http://demo.tremormedia.com/proddev/vast/Blistex1.jpg")
        
        //TODO: change from "staticResource" to "jpeg" or something?
        SWPBMAssertEq(swpbmVastCreativeCompanionAdsCompanion.resourceType, SWPBMVastResourceType.staticResource)
        let trackingEvents = swpbmVastCreativeCompanionAdsCompanion.trackingEvents.trackingEvents
        SWPBMAssertEq(trackingEvents.count, 2)
        SWPBMAssertEq(trackingEvents["creativeView"], ["http://myTrackingURL/inline/firstCompanionCreativeView"])
        SWPBMAssertEq(trackingEvents["creativeViewFromWrapper"], ["http://myTrackingURL/wrapper/firstCompanionCreativeView"])
        SWPBMAssertEq(swpbmVastCreativeCompanionAdsCompanion.clickThroughURI, "http://www.openx.com")
        
    }
}
