//
// Copyright 2016 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "AppDelegate.h"
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>
#import "InAppPurchase.h"
@import Firebase;

@interface AppDelegate ()
@property (nonatomic, strong) NSString *textFromUrlScheme;
@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // Override point for customization after application launch.
    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:[InAppPurchase sharedManager]];
    
    [FIRApp configure];
    
    [GADMobileAds configureWithApplicationID:@"ca-app-pub-8184020611985232~2575709104"];
    
    NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024 diskCapacity:20 * 1024 * 1024 diskPath:nil];
    [NSURLCache setSharedURLCache:URLCache];
    
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    
    _textFromUrlScheme = @"";
    
    NSLog(@"AppDelegate");

    return YES;
}

- (NSString*) getTextFromUrlScheme {
    return _textFromUrlScheme;
}

- (void) clearTextFromUrlScheme {
    _textFromUrlScheme = @"";
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
    if (!url) {
        return false;
    }
    
    NSDictionary* pDic = [self parseQueryString:[url query]];
    NSLog(@"Parameters: \n %@", pDic);
    
    _textFromUrlScheme = [pDic objectForKey:@"text"];
    
    return true;
}


- (NSDictionary*) parseQueryString:(NSString *)_query
{
    NSMutableDictionary* pDic = [NSMutableDictionary dictionary];
    NSArray* pairs = [_query componentsSeparatedByString:@"&"];
    for (NSString* sObj in pairs) {
        NSArray* elements = [sObj componentsSeparatedByString:@"="];
        NSString* key =     [[elements objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString* value =   [[elements objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [pDic setObject:value forKey:key];
    }
    
    return pDic;
}

- (void)applicationWillResignActive:(UIApplication *)application {
  // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
  // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
  // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
  // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
  // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
