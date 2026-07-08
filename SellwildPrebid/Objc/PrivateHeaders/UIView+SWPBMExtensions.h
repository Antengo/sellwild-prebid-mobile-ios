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

@interface UIView (SWPBMExtensions)

- (void)SWPBMAddCropAndCenterConstraintsWithInitialWidth:(CGFloat)initialWidth initialHeight:(CGFloat)initialHeight
    NS_SWIFT_NAME(SWPBMAddCropAndCenterConstraints(initialWidth:initialHeight:));

- (void)SWPBMAddBottomRightConstraintsWithMarginSize:(CGSize)marginSize;

- (void)SWPBMAddBottomRightConstraintsWithViewSize:(CGSize)viewSize marginSize:(CGSize)marginSize
    NS_SWIFT_NAME(SWPBMAddBottomRightConstraints(viewSize:marginSize:));

- (void)SWPBMAddBottomLeftConstraintsWithViewSize:(CGSize)viewSize marginSize:(CGSize)marginSize
    NS_SWIFT_NAME(SWPBMAddBottomLeftConstraints(viewSize:marginSize:));

- (void)SWPBMAddTopRightConstraintsWithViewSize:(CGSize)viewSize marginSize:(CGSize)marginSize
    NS_SWIFT_NAME(SWPBMAddTopRightConstraints(viewSize:marginSize:));

- (void)SWPBMAddTopLeftConstraintsWithViewSize:(CGSize)viewSize marginSize:(CGSize)marginSize
NS_SWIFT_NAME(SWPBMAddTopLeftConstraints(viewSize:marginSize:));

- (void)LogViewHierarchy;

- (BOOL)swpbmIsVisibleInView:(UIView *)inView;

@end
