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

#import "SWPBMExternalLinkHandler.h"


@interface SWPBMExternalLinkHandler()
@property (nonatomic, strong, nonnull, readonly) SWPBMExternalURLOpenerBlock primaryUrlOpener;
@property (nonatomic, strong, nonnull, readonly) SWPBMExternalURLOpenerBlock deepLinkUrlOpener;
@end



@implementation SWPBMExternalLinkHandler

- (instancetype)initWithPrimaryUrlOpener:(SWPBMExternalURLOpenerBlock)primaryUrlOpener
                       deepLinkUrlOpener:(SWPBMExternalURLOpenerBlock)deepLinkUrlOpener
                      trackingUrlVisitor:(SWPBMTrackingURLVisitorBlock)trackingUrlVisitor
{
    if (!(self = [super init])) {
        return nil;
    }
    _primaryUrlOpener = primaryUrlOpener;
    _deepLinkUrlOpener = deepLinkUrlOpener;
    _trackingUrlVisitor = trackingUrlVisitor;
    return self;
}

- (void)openExternalUrl:(NSURL *)url
           trackingUrls:(nullable NSArray<NSString *> *)trackingUrls
             completion:(SWPBMURLOpenResultHandlerBlock)completion
onClickthroughExitBlock:(nullable SWPBMVoidBlock)onClickthroughExitBlock
{
    self.primaryUrlOpener(url, ^(BOOL success) {
        if (success) {
            self.trackingUrlVisitor(trackingUrls);
            completion(YES);
        } else {
            completion(NO);
        }
    }, onClickthroughExitBlock);
}

- (SWPBMExternalLinkHandler *)asDeepLinkHandler {
    return [[SWPBMExternalLinkHandler alloc] initWithPrimaryUrlOpener:self.deepLinkUrlOpener
                                                  deepLinkUrlOpener:self.deepLinkUrlOpener
                                                 trackingUrlVisitor:self.trackingUrlVisitor];
}

- (SWPBMExternalLinkHandler *)handlerByAddingUrlOpenAttempter:(SWPBMURLOpenAttempterBlock)urlOpenAttempter {
    SWPBMExternalURLOpenerBlock const currentUrlOpener = self.primaryUrlOpener;
    SWPBMExternalURLOpenerBlock const newCombinedOpener = ^(NSURL *url,
                                                          SWPBMURLOpenResultHandlerBlock completion,
                                                          SWPBMVoidBlock onClickthroughExitBlock) {
        urlOpenAttempter(url, ^SWPBMExternalURLOpenCallbacks * (BOOL willOpenURL) {
            if (willOpenURL) {
                return [[SWPBMExternalURLOpenCallbacks alloc] initWithUrlOpenedCallback:completion
                                                              onClickthroughExitBlock:onClickthroughExitBlock];
            } else {
                currentUrlOpener(url, completion, onClickthroughExitBlock);
                return [[SWPBMExternalURLOpenCallbacks alloc] initWithUrlOpenedCallback:^(BOOL urlOpened) {
                    // nop
                } onClickthroughExitBlock:nil];
            }
        });
    };
    return [[SWPBMExternalLinkHandler alloc] initWithPrimaryUrlOpener:newCombinedOpener
                                                  deepLinkUrlOpener:self.deepLinkUrlOpener
                                                 trackingUrlVisitor:self.trackingUrlVisitor];
}

@end
