/*! @file OKTExternalUserAgentIOSCustomBrowser.m
    @brief AppAuth iOS SDK
    @copyright
        Copyright 2018 Google LLC
    @copydetails
        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the License.
        You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.
    @modifications
        Copyright (C) 2019 Okta Inc.
 */

#import <Foundation/Foundation.h>

#if !TARGET_OS_OSX

#import "OKTExternalUserAgentIOSCustomBrowser.h"

#import <UIKit/UIKit.h>

#import "OKTAuthorizationRequest.h"
#import "OKTAuthorizationService.h"
#import "OKTErrorUtilities.h"
#import "OKTURLQueryComponent.h"

NS_ASSUME_NONNULL_BEGIN

@implementation OKTExternalUserAgentIOSCustomBrowser

+ (instancetype)CustomBrowserChrome {
  // Chrome iOS documentation: https://developer.chrome.com/multidevice/ios/links
  OKTCustomBrowserURLTransformation transform = [[self class] URLTransformationSchemeSubstitutionHTTPS:@"googlechromes" HTTP:@"googlechrome"];
  NSURL *appStoreURL =
  [NSURL URLWithString:@"itms-apps://itunes.apple.com/us/app/chrome/id535886823"];
  return [[[self class] alloc] initWithURLTransformation:transform
                                        canOpenURLScheme:@"googlechromes"
                                             appStoreURL:appStoreURL];
}

+ (instancetype)CustomBrowserFirefox {
  // Firefox iOS documentation: https://github.com/mozilla-mobile/firefox-ios-open-in-client
  OKTCustomBrowserURLTransformation transform =
      [[self class] URLTransformationSchemeConcatPrefix:@"firefox://open-url?url="];
  NSURL *appStoreURL =
  [NSURL URLWithString:@"itms-apps://itunes.apple.com/us/app/firefox-web-browser/id989804926"];
  return [[[self class] alloc] initWithURLTransformation:transform
                                        canOpenURLScheme:@"firefox"
                                             appStoreURL:appStoreURL];
}

+ (instancetype)CustomBrowserOpera {
  OKTCustomBrowserURLTransformation transform =
      [[self class] URLTransformationSchemeSubstitutionHTTPS:@"opera-https" HTTP:@"opera-http"];
  NSURL *appStoreURL =
  [NSURL URLWithString:@"itms-apps://itunes.apple.com/us/app/opera-mini-web-browser/id363729560"];
  return [[[self class] alloc] initWithURLTransformation:transform
                                        canOpenURLScheme:@"opera-https"
                                             appStoreURL:appStoreURL];
}

+ (instancetype)CustomBrowserSafari {
  OKTCustomBrowserURLTransformation transformNOP = ^NSURL *(NSURL *requestURL) {
    return requestURL;
  };
  OKTExternalUserAgentIOSCustomBrowser *transform =
      [[[self class] alloc] initWithURLTransformation:transformNOP];
  return transform;
}

+ (OKTCustomBrowserURLTransformation)
    URLTransformationSchemeSubstitutionHTTPS:(NSString *)browserSchemeHTTPS
                                        HTTP:(nullable NSString *)browserSchemeHTTP {
  OKTCustomBrowserURLTransformation transform = ^NSURL *(NSURL *requestURL) {
    // Replace the URL Scheme with the Chrome equivalent.
    NSString *newScheme = nil;
    if ([requestURL.scheme isEqualToString:@"https"]) {
      newScheme = browserSchemeHTTPS;
    } else if ([requestURL.scheme isEqualToString:@"http"]) {
      if (!browserSchemeHTTP) {
        NSAssert(false, @"No HTTP scheme registered for browser");
        return nil;
      }
      newScheme = browserSchemeHTTP;
    }
     
    // Replaces the URI scheme with the custom scheme
    NSURLComponents *components = [NSURLComponents componentsWithURL:requestURL
                                             resolvingAgainstBaseURL:YES];
    components.scheme = newScheme;
    return components.URL;
  };
  return transform;
}

+ (OKTCustomBrowserURLTransformation)URLTransformationSchemeConcatPrefix:(NSString *)URLprefix {
  OKTCustomBrowserURLTransformation transform = ^NSURL *(NSURL *requestURL) {
    NSString *requestURLString = [requestURL absoluteString];
    NSMutableCharacterSet *allowedParamCharacters =
        [OKTURLQueryComponent URLParamValueAllowedCharacters];
    NSString *encodedUrl = [requestURLString stringByAddingPercentEncodingWithAllowedCharacters:allowedParamCharacters];
    NSString *newURL = [NSString stringWithFormat:@"%@%@", URLprefix, encodedUrl];
    return [NSURL URLWithString:newURL];
  };
  return transform;
}

- (nullable instancetype)initWithURLTransformation:
    (OKTCustomBrowserURLTransformation)URLTransformation {
  return [self initWithURLTransformation:URLTransformation canOpenURLScheme:nil appStoreURL:nil];
}

- (nullable instancetype)
    initWithURLTransformation:(OKTCustomBrowserURLTransformation)URLTransformation
             canOpenURLScheme:(nullable NSString *)canOpenURLScheme
                  appStoreURL:(nullable NSURL *)appStoreURL {
  self = [super init];
  if (self) {
    _URLTransformation = URLTransformation;
    _canOpenURLScheme = canOpenURLScheme;
    _appStoreURL = appStoreURL;
  }
  return self;
}

- (BOOL)presentExternalUserAgentRequest:(nonnull id<OKTExternalUserAgentRequest>)request
                                session:(nonnull id<OKTExternalUserAgentSession>)session {
  // If the app store URL is set, checks if the app is installed and if not opens the app store.
  if (_appStoreURL && _canOpenURLScheme) {
    // Verifies existence of LSApplicationQueriesSchemes Info.plist key.
    NSArray __unused* canOpenURLs =
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"LSApplicationQueriesSchemes"];
    NSAssert(canOpenURLs, @"plist missing LSApplicationQueriesSchemes key");
    NSAssert1([canOpenURLs containsObject:_canOpenURLScheme],
              @"plist missing LSApplicationQueriesSchemes entry for '%@'", _canOpenURLScheme);

    // Opens AppStore if app isn't installed
    NSString *testURLString = [NSString stringWithFormat:@"%@://example.com", _canOpenURLScheme];
    NSURL *testURL = [NSURL URLWithString:testURLString];
    if (![[UIApplication sharedApplication] canOpenURL:testURL]) {
      [[UIApplication sharedApplication] openURL:_appStoreURL options:@{} completionHandler:nil];
      
      return NO;
    }
  }
  
  // Transforms the request URL and opens it.
  NSURL *requestURL = [request externalUserAgentRequestURL];
  requestURL = _URLTransformation(requestURL);
    
  __block BOOL openedInBrowser = NO;
  
  dispatch_group_t group = dispatch_group_create();
  
  dispatch_group_enter(group);
  [[UIApplication sharedApplication] openURL:requestURL options:@{} completionHandler:^(BOOL success) {
      openedInBrowser = success;
      dispatch_group_leave(group);
  }];
  
  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

  return openedInBrowser;
}

- (void)dismissExternalUserAgentAnimated:(BOOL)animated
                                completion:(nonnull void (^)(void))completion {
  completion();
}

@end

NS_ASSUME_NONNULL_END

#endif
