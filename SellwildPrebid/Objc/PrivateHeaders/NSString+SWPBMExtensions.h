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

#import <Foundation/Foundation.h>

@interface NSString(SWPBMExtensions)
- (BOOL) SWPBMdoesMatch: (nonnull NSString *) regex NS_SWIFT_NAME(SWPBMdoesMatch(_:));
- (int)  SWPBMnumberOfMatches: (nonnull NSString *) regex NS_SWIFT_NAME(SWPBMnumberOfMatches(_:));
- (nullable NSString *) SWPBMsubstringToString: (nonnull NSString *) to NS_SWIFT_NAME(SWPBMsubstringToString(_:));
- (nullable NSString *) SWPBMsubstringFromString: (nonnull NSString *) from NS_SWIFT_NAME(SWPBMsubstringFromString(_:));
- (nullable NSString *) SWPBMsubstringFromString: (nonnull NSString *) from toString:(nonnull NSString *) to NS_SWIFT_NAME(SWPBMsubstringFromString(_:toString:));
- (nonnull NSString *) SWPBMstringByReplacingRegex: (nonnull NSString *) regex replaceWith:(nonnull NSString *) replaceWithString NS_SWIFT_NAME(SWPBMstringByReplacingRegex(_:replaceWith:));
- (nullable NSString *) SWPBMsubstringFromIndex: (int) fromIndex toIndex: (int) toIndex NS_SWIFT_NAME(SWPBMsubstringFromIndex(_:toIndex:));
@end

