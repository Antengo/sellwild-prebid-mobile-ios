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

#import "SWPBMVastRequester.h"

#import "SWPBMConstants.h"
#import "SWPBMURLComponents.h"

#import "SWSwiftImport.h"

static NSString *vastContentType = @"application/x-www-form-urlencoded";

@implementation SWPBMVastRequester

+ (void)loadVastURL:(NSString *)url connection:(id<SWPBPrebidServerConnectionProtocol>)connection completion:(AdRequestCallback)completion {
    
    SWPBMURLComponents *urlComponents = [[SWPBMURLComponents alloc] initWithUrl:url paramsDict:@{}];
    if (!urlComponents) {
        NSError *error = [SWPBMError errorWithDescription:@"Failed to create SWPBMURLComponents" statusCode:SWPBMErrorCodeUndefined];
        completion(nil, error);
        return;
    }
    
    NSData *data = [[urlComponents argumentsString] dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        NSError *error = [SWPBMError errorWithDescription:@"Unable to create Data from SWPBMURLComponents.argumentsString" statusCode:SWPBMErrorCodeUndefined];
        completion(nil, error);
        return;
    }

    [connection post:urlComponents.urlString
         contentType:vastContentType
                data:data timeout:SWPBPrebidConstants.CONNECTION_TIMEOUT_DEFAULT
            callback:^(SWPBPrebidServerResponse * _Nonnull serverResponse) {
        if (serverResponse.error) {
            completion(nil, serverResponse.error);
            return;
        }
        
        if (serverResponse.statusCode != 200) {
            NSString *message = [NSString stringWithFormat:@"Server responded with status code %li", (long)serverResponse.statusCode];
            completion(nil, [SWPBMError errorWithDescription:message statusCode:serverResponse.statusCode]);
            return;
        }
        
        NSData *vastData = serverResponse.rawData;
        if (!vastData) {
            completion(nil, [SWPBMError errorWithDescription:@"No Data From Server"
                                                statusCode:SWPBMErrorCodeFileNotFound]);
            return;
        }
        
        completion(serverResponse, nil);
    }];
}

@end
