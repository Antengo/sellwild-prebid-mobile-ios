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

class SWPBMVastLoaderTestSingleInline: XCTestCase {
    
    var vastRequestSuccessfulExpectation:XCTestExpectation!

    override func setUp() {
        self.continueAfterFailure = true
        MockServer.shared.reset()
    }
    
    override func tearDown() {
        MockServer.shared.reset()
        self.vastRequestSuccessfulExpectation = nil
    }
    
    func testRequest() {

        self.vastRequestSuccessfulExpectation = self.expectation(description: "Expected VAST Load to be successful")
        
        //Make an PrebidServerConnection and redirect its network requests to the Mock Server
        let conn = UtilitiesForTesting.createConnectionForMockedTest()
        let adConfiguration = AdConfiguration()
        adConfiguration.adFormats = [.video]
        
        let adLoadManager = MockSWPBMAdLoadManagerVAST(bid: RawWinningBidFabricator.makeWinningBid(price: 0.1, bidder: "bidder", cacheID: "cache-id"), connection:conn, adConfiguration: adConfiguration)
        
        adLoadManager.mock_requestCompletedSuccess = { response in
            self.requestCompletedSuccess(response)
        }
        
        adLoadManager.mock_requestCompletedFailure = { error in
            XCTFail("\(error)")
        }
        
        let requester = SWPBMAdRequesterVAST(serverConnection:conn, adConfiguration: adConfiguration)
        requester.adLoadManager = adLoadManager
        
        if let data = UtilitiesForTesting.loadFileAsDataFromBundle("document_with_one_inline_ad.xml") {
            requester.buildAdsArray(data)
        }
                
        self.waitForExpectations(timeout: 2.0, handler: nil)
    }

    //MARK: SWPBMVastLoaderDelegate
    
    func requestCompletedSuccess(_ vastResponse: SWPBMAdRequestResponseVAST) {
        
        //There should be 1 ad.
        //An Ad can be either inline or wrapper; this should be inline.
        SWPBMAssertEq(vastResponse.ads?.count, 1)
        guard let ad = vastResponse.ads?.first as? SWPBMVastInlineAd else {
            XCTFail()
            return;
        }
        
        SWPBMAssertEq(ad.title, "VAST 2.0 Instream Test 1")
        SWPBMAssertEq(ad.adSystem, "Inline AdSystem")
        SWPBMAssertEq(ad.adSystemVersion, "1.0")
        SWPBMAssertEq(ad.advertiser, "Example Advertiser")
        SWPBMAssertEq(ad.errorURIs, ["http://myErrorURL/AdError"])
        SWPBMAssertEq(ad.impressionURIs, ["http://myTrackingURL/inline/impression", "http://myTrackingURL/inline/anotherImpression"])
        
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
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["creativeView"], ["http://myTrackingURL/inline/creativeView"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["start"], ["http://myTrackingURL/inline/start1", "http://myTrackingURL/inline/start2"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["midpoint"], ["http://myTrackingURL/inline/midpoint"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["firstQuartile"], ["http://myTrackingURL/inline/firstQuartile"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["thirdQuartile"], ["http://myTrackingURL/inline/thirdQuartile"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["complete"], ["http://myTrackingURL/inline/complete"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["mute"], ["http://myTrackingURL/inline/mute"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["unmute"], ["http://myTrackingURL/inline/unmute"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["pause"], ["http://myTrackingURL/inline/pause"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["rewind"], ["http://myTrackingURL/inline/rewind"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["resume"], ["http://myTrackingURL/inline/resume"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["fullscreen"], ["http://myTrackingURL/inline/fullscreen"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["expand"], ["http://myTrackingURL/inline/expand"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["collapse"], ["http://myTrackingURL/inline/collapse"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["acceptInvitation"], ["http://myTrackingURL/inline/acceptInvitation"])
        SWPBMAssertEq(swpbmVastCreativeLinear.vastTrackingEvents.trackingEvents["close"], ["http://myTrackingURL/inline/close"])
        
        SWPBMAssertEq(swpbmVastCreativeLinear.adParameters, "params=for&request=gohere")
        SWPBMAssertEq(swpbmVastCreativeLinear.clickThroughURI, "http://www.openx.com")
        SWPBMAssertEq(swpbmVastCreativeLinear.clickTrackingURIs, ["http://myTrackingURL/inline/click1", "http://myTrackingURL/inline/click2", "http://myTrackingURL/inline/custom1", "http://myTrackingURL/inline/custom2"])
        
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
        var swpbmVastCreativeCompanionAdsCompanion = swpbmVastCreativeCompanionAds.companions[0] as! SWPBMVastCreativeCompanionAdsCompanion
        SWPBMAssertEq(swpbmVastCreativeCompanionAdsCompanion.companionIdentifier, "big_box")
        SWPBMAssertEq(swpbmVastCreativeCompanionAdsCompanion.width, 300)
        SWPBMAssertEq(swpbmVastCreativeCompanionAdsCompanion.height, 250)
        //Should we support expandedWidth="600" expandedHeight="500" apiFramework="VPAID" ??
        SWPBMAssertEq(swpbmVastCreativeCompanionAdsCompanion.resource, "http://demo.tremormedia.com/proddev/vast/Blistex1.jpg")
        
        //TODO: change from "staticResource" to "jpeg" or something?
        SWPBMAssertEq(swpbmVastCreativeCompanionAdsCompanion.resourceType, SWPBMVastResourceType.staticResource)
        let trackingEvents = swpbmVastCreativeCompanionAdsCompanion.trackingEvents.trackingEvents
        SWPBMAssertEq(trackingEvents.count, 1)
        SWPBMAssertEq(trackingEvents["creativeView"], ["http://myTrackingURL/inline/firstCompanionCreativeView"])
        SWPBMAssertEq(swpbmVastCreativeCompanionAdsCompanion.clickThroughURI, "http://www.openx.com")
        
        //Second Companion
        swpbmVastCreativeCompanionAdsCompanion = swpbmVastCreativeCompanionAds.companions[1] as! SWPBMVastCreativeCompanionAdsCompanion
        SWPBMAssertEq(swpbmVastCreativeCompanionAdsCompanion.resource, "http://ad3.liverail.com/util/companions.php")
        SWPBMAssertEq(swpbmVastCreativeCompanionAdsCompanion.resourceType, SWPBMVastResourceType.iFrameResource)
        
        //Creative 3 - NonLinearAds
        let swpbmVastCreativeNonLinearAds = ad.creatives[2] as! SWPBMVastCreativeNonLinearAds
        SWPBMAssertEq(swpbmVastCreativeNonLinearAds.nonLinears.count, 2)
        
        //First NonLinear
        var swpbmVastCreativeNonLinearAdsNonLinear = swpbmVastCreativeNonLinearAds.nonLinears[0] as! SWPBMVastCreativeNonLinearAdsNonLinear
        SWPBMAssertEq(swpbmVastCreativeNonLinearAdsNonLinear.resource, "http://cdn.liverail.com/adasset/228/330/overlay.jpg")
        SWPBMAssertEq(swpbmVastCreativeNonLinearAdsNonLinear.id, "special_overlay")
        SWPBMAssertEq(swpbmVastCreativeNonLinearAdsNonLinear.width, 300)
        SWPBMAssertEq(swpbmVastCreativeNonLinearAdsNonLinear.height, 50)
        SWPBMAssertEq(swpbmVastCreativeNonLinearAdsNonLinear.apiFramework, "VPAID")
        SWPBMAssertEq(swpbmVastCreativeNonLinearAdsNonLinear.scalable, true)
        SWPBMAssertEq(swpbmVastCreativeNonLinearAdsNonLinear.maintainAspectRatio, true)
        SWPBMAssertEq(swpbmVastCreativeNonLinearAdsNonLinear.clickThroughURI, "http://t3.liverail.com")
        
        //Second NonLinear
        swpbmVastCreativeNonLinearAdsNonLinear = swpbmVastCreativeNonLinearAds.nonLinears[1] as! SWPBMVastCreativeNonLinearAdsNonLinear
        SWPBMAssertEq(swpbmVastCreativeNonLinearAdsNonLinear.resource, "http://ad3.liverail.com/util/non_linear.php")
        SWPBMAssertEq(swpbmVastCreativeNonLinearAdsNonLinear.width, 728)
        SWPBMAssertEq(swpbmVastCreativeNonLinearAdsNonLinear.height, 90)
        SWPBMAssertEq(swpbmVastCreativeNonLinearAdsNonLinear.clickThroughURI, "http://www.openx.com")
        
        // Must be in the end of the method
        self.vastRequestSuccessfulExpectation.fulfill()
    }
}
