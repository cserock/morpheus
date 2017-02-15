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

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioServices.h>

#import "HomeController.h"
#import "AudioController.h"
#import "SpeechRecognitionService.h"
#import "google/cloud/speech/v1beta1/CloudSpeech.pbrpc.h"
#import "Reachability.h"

#import <AFNetworking/AFNetworking.h>

#import "AppDelegate.h"
#import "UIButton+Badge.h"
#import "InAppPurchase.h"

@import Firebase;
@import GoogleMobileAds;

#define SAMPLE_RATE 16000.0f

#define ALERT_STOP_RECORDING 1
#define ALERT_STOP_CHECKING 2

#define DEFAULT_ENGLISH_REGION @"en-US"

#define API_CHECK_GRAMMER_KEY @"Ui2Ec5aA0SoAnzst"

#define API_CHECK_GRAMMER_URL @"https://api.textgears.com/check.php"

#define FREE_TEXT_LIMIT 256
#define PAID_TEXT_LIMIT 2048
#define IS_PAID NO
#define ITEM_1_ID @"me.neosave.morpheus.item01"

@interface HomeController () <AudioControllerDelegate, UITextViewDelegate, UIAlertViewDelegate, AVSpeechSynthesizerDelegate>
@property (weak, nonatomic) IBOutlet UIButton *btnRecordAudio;
@property (weak, nonatomic) IBOutlet UIButton *btnCheckGrammer;
@property (weak, nonatomic) IBOutlet UILabel *placeHolderLabel;
@property (nonatomic, strong) IBOutlet UITextView *textView;
@property (nonatomic, strong) NSMutableData *audioData;

@property (nonatomic, strong) NSString *recordedString;
@property (nonatomic, strong) NSString *checkedGrammerString;

@property (nonatomic, strong) UIAlertView *infoAlert;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UILabel *lblTextCount;
@property (weak, nonatomic) IBOutlet UIImageView *imgCheckedGrammer;
@property (weak, nonatomic) IBOutlet UIView *dimmedView;

@property (weak, nonatomic) IBOutlet UIButton *btnListen;
@property (nonatomic, strong) NSString *englishRegionCode;
@property (nonatomic, strong) NSURLSessionDataTask *task;

@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong) NSString *todayString;
@property (assign) Boolean isAnonymous;
@property (assign) Boolean isPaid;

@property (nonatomic, strong) FIRDatabaseReference *ref;
@property (assign) int limitListenCount;
@property (assign) int limitCheckCount;
@property (assign) int textLimitCount;

@property (nonatomic, strong) FIRRemoteConfig *remoteConfig;

@property (assign) int adProtage;
@property (assign) int dailyFreeListenItem;
@property (assign) int dailyFreeCheckItem;
@property (assign) Boolean iApEnabled;
@property (assign) int freeCharLength;
@property (assign) Boolean isUpdate;
@property (assign) Boolean isPurchasing;

@property (assign) Boolean isUpdatedAfterCheck;

@property (nonatomic, strong) GADInterstitial *interstitial;

@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@property (nonatomic, strong) AVSpeechSynthesizer *synthesizer;


@end

@implementation HomeController

NSString *const kAdProtageConfigKey = @"ad_protage";
NSString *const kDailyFreeListenItemConfigKey = @"daily_free_listen_item";
NSString *const kDailyFreeListenCheckItemConfigKey = @"daily_free_check_item";
NSString *const kInAppEnabledConfigKey = @"iap_enabled";
NSString *const kFreeCharLengthConfigKey = @"free_char_length";
NSString *const kIsUpdateConfigKey = @"is_update";


- (void)viewWillAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(productPurchased:) name: @"InAppPurchasedNotification" object:nil];
    
    // init paid
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _isPaid = [defaults boolForKey:ITEM_1_ID];
    
    // fetch from server
    if((_uid != nil) && ![_uid isEqualToString:@""]){
        [self fetchConfig];
    }
    
    _isPurchasing = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"InAppPurchasedNotification" object:nil];
}

- (void)productPurchased:(NSNotification *)notification {
    
    [_spinner stopAnimating];
    
    NSArray *data = notification.object;
    NSString *productIdentifier = [data objectAtIndex:0];
    NSString *mode = [data objectAtIndex:1];
    NSString *transactionIdentifier = [data objectAtIndex:2];
    NSString *transactionDate = [data objectAtIndex:3];
    NSString *uId = [FIRAuth auth].currentUser.uid;
    
    NSLog(@"mode : %@", mode);
    NSLog(@"productIdentifier : %@", productIdentifier);
    NSLog(@"transactionIdentifier : %@", transactionIdentifier);
    
    if([mode isEqualToString:@"error"]){
        return;
    }
    
    if([productIdentifier isEqualToString:ITEM_1_ID]){
        
        // update purchase info
        _ref = [[FIRDatabase database] reference];
        NSDictionary *purchase = @{@"uid": uId,
                                   @"pid": productIdentifier,
                                   @"tid": transactionIdentifier,
                                   @"date": transactionDate};
        
        NSDictionary *updates = @{[@"/purchases/" stringByAppendingString:transactionIdentifier]: purchase};
        [_ref updateChildValues:updates];
        
        if([mode isEqualToString:@"buy"]){
            
            // init paid
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            _isPaid = [defaults boolForKey:ITEM_1_ID];
            
            // fetch from server
            [self fetchConfig];
        }
    }
}

/*
 - (void)createAndLoadInterstitial {
 self.interstitial =
 [[GADInterstitial alloc] initWithAdUnitID:@"ca-app-pub-8184020611985232/4052442309"];
 
 GADRequest *request = [GADRequest request];
 // Request test ads on devices you specify. Your test device ID is printed to the console when
 // an ad request is made.
 request.testDevices = @[ kGADSimulatorID, @"3640560a43cefa8528943c9bcd3307c785234636" ];
 [self.interstitial loadRequest:request];
 }
 */

- (GADInterstitial *)createAndLoadInterstitial {
    GADInterstitial *interstitial =
    [[GADInterstitial alloc] initWithAdUnitID:@"ca-app-pub-8184020611985232/4052442309"];
    interstitial.delegate = self;
    
    GADRequest *request = [GADRequest request];
    // Request test ads on devices you specify. Your test device ID is printed to the console when
    // an ad request is made.
    request.testDevices = @[ kGADSimulatorID, @"3640560a43cefa8528943c9bcd3307c785234636" ];
  
    [interstitial loadRequest:request];
    return interstitial;
}

- (void)interstitialDidDismissScreen:(GADInterstitial *)interstitial {
    self.interstitial = [self createAndLoadInterstitial];
}

- (void) initUserLimit {
    
    // check user limit
    NSDate *date = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    [dateFormatter setDateFormat:@"yyyyMMdd"];
    _todayString = [dateFormatter stringFromDate:date];
    
    NSLog(@"today : %@", _todayString);
    
    _ref = [[FIRDatabase database] reference];
    
    FIRDatabaseQuery *userLimitQuery = [[[_ref child:@"user_limit"] child:_uid] child:_todayString];
    
    [userLimitQuery observeEventType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
        // Get user value
        NSDictionary *user_limit = snapshot.value;
        
        NSLog(@"checkCount : %@", user_limit);
        
        if(user_limit == (NSDictionary*) [NSNull null]){
            // delete rows not today
            [[[_ref child:@"user_limit"] child:_uid] removeValue];
            
            // set today
            [[[[_ref child:@"user_limit"] child:_uid] child:_todayString] setValue:@{@"listen_count": [NSString stringWithFormat:@"%d", _dailyFreeListenItem], @"check_count": [NSString stringWithFormat:@"%d", _dailyFreeCheckItem]}];
        } else {
            
            _limitListenCount = [[user_limit objectForKey:@"listen_count"] intValue];
            _limitCheckCount = [[user_limit objectForKey:@"check_count"] intValue];
            
            NSLog(@"Listen count : %d, Check count : %d", _limitListenCount, _limitCheckCount);
        }
        
        [self updateButtonBadge];
        
        [_spinner stopAnimating];
        _dimmedView.hidden = YES;
        
        // ...
    } withCancelBlock:^(NSError * _Nonnull error) {
        NSLog(@"%@", error.localizedDescription);
        
        [_spinner stopAnimating];
        _dimmedView.hidden = YES;
        [self showAlertTempError];
    }];
}

- (void) showAd {
    
    int rand = arc4random_uniform(100);
    NSLog(@"ad protage : %d, rand : %d", _adProtage, rand);
    
    if(rand > (100 - _adProtage)){
        
        [self.interstitial presentFromRootViewController:self];
        
        // ad
        [FIRAnalytics logEventWithName:kFIREventViewItem parameters:@{
                                                                      kFIRParameterContentType:@"home",
                                                                      kFIRParameterItemID:@"ad"
                                                                      }];
    }
    
}

- (void) updateButtonBadge {
    if(_isPaid){
        _btnRecordAudio.shouldHideBadgeAtZero = YES;
    } else {
        _btnRecordAudio.shouldHideBadgeAtZero = NO;
    }
    _btnRecordAudio.badgeValue = [NSString stringWithFormat:@"%d", _limitListenCount];
    _btnRecordAudio.badgeMinSize = 16.0;
    _btnRecordAudio.badgeBGColor = [UIColor whiteColor];
    _btnRecordAudio.badgeTextColor = [UIColor colorWithRed:49.0/255.0 green:122.0/255.0 blue:208.0/255.0 alpha:1.0];
    _btnRecordAudio.badgeFont = [UIFont fontWithName:@"HelveticaNeue" size:12];
    _btnRecordAudio.badgeOriginX = _btnRecordAudio.frame.size.width - 30;
    _btnRecordAudio.badgeOriginY = ((_btnRecordAudio.frame.size.height/2) - (_btnRecordAudio.badge.frame.size.height/2));
    
    if(_isPaid){
        _btnCheckGrammer.shouldHideBadgeAtZero = YES;
    } else {
        _btnCheckGrammer.shouldHideBadgeAtZero = NO;
    }
    _btnCheckGrammer.badgeValue = [NSString stringWithFormat:@"%d", _limitCheckCount];
    _btnCheckGrammer.badgeMinSize = 16.0;
    _btnCheckGrammer.badgeBGColor = [UIColor whiteColor];
    _btnCheckGrammer.badgeTextColor = [UIColor colorWithRed:49.0/255.0 green:122.0/255.0 blue:208.0/255.0 alpha:1.0];
    _btnCheckGrammer.badgeFont = [UIFont fontWithName:@"HelveticaNeue" size:12];
    _btnCheckGrammer.badgeOriginX = _btnCheckGrammer.frame.size.width - 30;
    _btnCheckGrammer.badgeOriginY = ((_btnCheckGrammer.frame.size.height/2) - (_btnCheckGrammer.badge.frame.size.height/2));
    
}

- (void) decreaseCount :(NSString*) limitName {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:YES forKey:@"isRunAtOnce"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if([limitName isEqualToString:@"listen"]){
        _limitListenCount--;
        
        if(_limitListenCount < 0)
            _limitListenCount = 0;
        
    } else if([limitName isEqualToString:@"check"]){
        _limitCheckCount--;
        
        if(_limitCheckCount < 0)
            _limitCheckCount = 0;
    }
    
    [[[[_ref child:@"user_limit"] child:_uid] child:_todayString] setValue:@{@"listen_count": [NSString stringWithFormat:@"%d", _limitListenCount], @"check_count": [NSString stringWithFormat:@"%d", _limitCheckCount]}];
    
    [self updateButtonBadge];
}


- (Boolean) checkMicPermission {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    Boolean isMicGranted = [defaults boolForKey:@"isMicGranted"];

    if(!isMicGranted ){
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            [defaults setBool:granted forKey:@"isMicGranted"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }];
    }
    
    isMicGranted = [defaults boolForKey:@"isMicGranted"];
    
    return isMicGranted;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self checkReachability];
    
    _dimmedView.hidden = NO;
    
    // [START get_remote_config_instance]
    self.remoteConfig = [FIRRemoteConfig remoteConfig];
    // [END get_remote_config_instance]
    
    // Create Remote Config Setting to enable developer mode.
    // Fetching configs from the server is normally limited to 5 requests per hour.
    // Enabling developer mode allows many more requests to be made per hour, so developers
    // can test different config values during development.
    // [START enable_dev_mode]
    
    Boolean devMode = NO;
    
#ifdef DEBUG
    devMode = YES;
    NSLog(@"DEBUG devMode : %d", devMode);
#endif
    
    FIRRemoteConfigSettings *remoteConfigSettings = [[FIRRemoteConfigSettings alloc] initWithDeveloperModeEnabled:devMode];
    self.remoteConfig.configSettings = remoteConfigSettings;
    // [END enable_dev_mode]
    
    // Set default Remote Config values. In general you should have in-app defaults for all
    // values that you may configure using Remote Config later on. The idea is that you
    // use the in-app defaults and when you need to adjust those defaults, you set an updated
    // value in the App Manager console. The next time that your application fetches values
    // from the server, the new values you set in the Firebase console are cached. After you
    // activate these values, they are used in your app instead of the in-app defaults. You
    // can set default values using a plist file, as shown here, or you can set defaults
    // inline by using one of the other setDefaults methods.
    // [START set_default_values]
    [self.remoteConfig setDefaultsFromPlistFileName:@"RemoteConfigDefaults"];
    // [END set_default_values]
    
    // init uid
    _uid = @"";
    
    [[FIRAuth auth]
     signInAnonymouslyWithCompletion:^(FIRUser *_Nullable user, NSError *_Nullable error) {
         // ...
         _uid = user.uid;
         NSLog(@"signInAnonymouslyWithCompletion uid : @%@", user.uid);
         
         [self fetchConfig];
     }];
    
    [self checkMicPermission];
    
    
    
    
//    [self createAndLoadInterstitial];
    self.interstitial = [self createAndLoadInterstitial];
    
    _isUpdatedAfterCheck = YES;
    _imgCheckedGrammer.highlighted = NO;
    
    _limitListenCount = 0;
    _limitCheckCount = 0;
    
    // init engish region code
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _englishRegionCode = [defaults objectForKey:@"englishRegionCode"];
    NSLog(@"englishRegionCode : @%@", _englishRegionCode);
    
    if(_englishRegionCode == nil){
        [defaults setObject:DEFAULT_ENGLISH_REGION forKey:@"englishRegionCode"];
        [defaults setBool:YES forKey:@"isVibrationAfterListening"];
        [defaults setBool:YES forKey:@"isVibrationAfterCheking"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    // is purchasing
    _isPurchasing = NO;
    
    // init paid
    _isPaid = [defaults boolForKey:ITEM_1_ID];
    
    if(_isPaid){
        _textLimitCount = PAID_TEXT_LIMIT;
    } else {
        _textLimitCount = FREE_TEXT_LIMIT;
    }
    
    
    // process text from url scheme
    [self processTextfromUrlScheme];
    
    _recordedString = @"";
    _checkedGrammerString = @"";
    
    [self updateLblTextLength:_textView.text.length];
    
    [AudioController sharedInstance].delegate = self;
    _textView.delegate = self;
    _textView.keyboardType = UIKeyboardTypeASCIICapable;
    
    UITapGestureRecognizer *scrollViewTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollTap:)];
    [_scrollView addGestureRecognizer:scrollViewTap];
    [self.view addSubview:_scrollView];
    
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(becomeActive)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
    
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(becomeDeactive)
                                                name:UIApplicationDidEnterBackgroundNotification
                                              object:nil];

    
    _synthesizer = [[AVSpeechSynthesizer alloc] init];
    _synthesizer.delegate = self;
    
    // indicator
    _spinner = [[UIActivityIndicatorView alloc]
                                        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [_spinner setColor:[UIColor grayColor]];
    _spinner.center = CGPointMake((self.navigationController.view.frame.size.width/2), (self.navigationController.view.frame.size.height/2));
    _spinner.hidesWhenStopped = YES;
    [self.navigationController.view addSubview:_spinner];
    
    [_spinner startAnimating];
}


- (void) fetchConfig {
    
    if(![self checkReachability]){
        return;
    }
    
    _uid = [FIRAuth auth].currentUser.uid;
    
    NSLog(@"fetchConfig uid : @%@", _uid);

    long expirationDuration = 3600;
    // If in developer mode cacheExpiration is set to 0 so each fetch will retrieve values from
    // the server.
    if (self.remoteConfig.configSettings.isDeveloperModeEnabled) {
        expirationDuration = 0;
    }
    
    // [START fetch_config_with_callback]
    // cacheExpirationSeconds is set to cacheExpiration here, indicating that any previously
    // fetched and cached config would be considered expired because it would have been fetched
    // more than cacheExpiration seconds ago. Thus the next fetch would go to the server unless
    // throttling is in progress. The default expiration duration is 43200 (12 hours).
    [self.remoteConfig fetchWithExpirationDuration:expirationDuration completionHandler:^(FIRRemoteConfigFetchStatus status, NSError *error) {
        if (status == FIRRemoteConfigFetchStatusSuccess) {
            NSLog(@"Config fetched!");
            [self.remoteConfig activateFetched];
            
            _dailyFreeListenItem = [self.remoteConfig[kDailyFreeListenItemConfigKey].stringValue intValue];
            _dailyFreeCheckItem = [self.remoteConfig[kDailyFreeListenCheckItemConfigKey].stringValue intValue];
            _iApEnabled = self.remoteConfig[kInAppEnabledConfigKey].boolValue;
            _adProtage = [self.remoteConfig[kAdProtageConfigKey].stringValue intValue];
            _isUpdate = self.remoteConfig[kIsUpdateConfigKey].boolValue;
            _textLimitCount = [self.remoteConfig[kFreeCharLengthConfigKey].stringValue intValue];
            
            if(_isPaid){
                _textLimitCount = PAID_TEXT_LIMIT;
                
                _limitListenCount = 0;
                _limitCheckCount = 0;
                
                [self updateButtonBadge];
                
                [_spinner stopAnimating];
                _dimmedView.hidden = YES;
            } else {
                
                [self initUserLimit];
                
                if(!_isPurchasing){
                    
                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    Boolean isRunAtOnce = [defaults boolForKey:@"isRunAtOnce"];
                    
                    NSLog(@"isRunAtOnce : %d", isRunAtOnce);

                    // show ad
                    if(isRunAtOnce){
                        [self showAd];
                    }
                }
            }
            
            NSLog(@"_dailyFreeListenItem : %d, _dailyFreeCheckItem : %d, _iApEnabled : %d, _adProtage : %d, _textLimitCount : %d, _isUpdate : %d", _dailyFreeListenItem, _dailyFreeCheckItem, _iApEnabled, _adProtage, _textLimitCount, _isUpdate);
            
            
            [self updateLblTextLength:_textView.text.length];
            
            if(_isUpdate){
                [self showUpdateAlert];
            }
            
        } else {
            NSLog(@"Config not fetched");
            NSLog(@"Error %@", error.localizedDescription);
            [_spinner stopAnimating];
            _dimmedView.hidden = YES;
            [self showAlertTempError];
        }
        
        
        
    }];
    // [END fetch_config_with_callback]
}

- (void) becomeActive {
    [self processTextfromUrlScheme];
    
    NSLog(@"becomeActive");
    
    // fetch from server
    if((_uid != nil) && ![_uid isEqualToString:@""]){
        [self fetchConfig];
    }
}

- (void) becomeDeactive {
    
    NSLog(@"becomeDective");
    
    [self stopAudio:nil];
    
    if([_synthesizer isSpeaking]){
        [_synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
        _btnListen.selected = NO;
        _btnListen.backgroundColor = [UIColor colorWithRed:60.0/255.0 green:136.0/255.0 blue:223.0/255.0 alpha:1.0];
    }
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setActive:NO error:nil];
    
}

- (void) showAlertTempError {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Temporary failure",nil)
                                                    message:NSLocalizedString(@"Please use after a while.",nil)
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Done",nil) otherButtonTitles:nil];
    [alert show];
}

- (Boolean) checkReachability {
    if ([[Reachability reachabilityForInternetConnection]currentReachabilityStatus]==NotReachable)
    {
        //connection unavailable
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Check Connection",nil)
                                                        message:NSLocalizedString(@"Morpheus should be connected to internet.",nil)
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Done",nil) otherButtonTitles:nil];
        [alert show];
        return NO;
    }
    
    return YES;
}

- (Boolean) checkLimitCount:(NSString*) limitName {
    
    // free 일때만
    if(!_isPaid){
        
        int nowCount = 0;
        
        if([limitName isEqualToString:@"listen"]){
            nowCount = _limitListenCount;
        } else if([limitName isEqualToString:@"check"]){
            nowCount = _limitCheckCount;
        }
        
        if (nowCount == 0)
        {
            
            
            UIAlertController * alert=   [UIAlertController
                                          alertControllerWithTitle:NSLocalizedString(@"Upgrade",nil)
                                          message:NSLocalizedString(@"You've spent today's free quota.\nPlease buy upgrade pack and use continue.\n\nUnlimit uses by a day\nSupport 2,048 chars\nNo Ads",nil)
                                          preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* cancel = [UIAlertAction
                                     actionWithTitle:NSLocalizedString(@"Later",nil)
                                     style:UIAlertActionStyleDefault
                                     handler:^(UIAlertAction * action)
                                     {
                                         [alert dismissViewControllerAnimated:YES completion:nil];
                                     }];
            UIAlertAction* ok = [UIAlertAction
                                 actionWithTitle:NSLocalizedString(@"Buy",nil)
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action)
                                 {
                                     [alert dismissViewControllerAnimated:YES completion:nil];
                                     
                                     NSLog(@"UPGRADE!");
                                     
                                     if ([SKPaymentQueue canMakePayments]) {
                                         [_spinner startAnimating];
                                         _isPurchasing = YES;
                                         
                                         [FIRAnalytics logEventWithName:kFIREventSelectContent parameters:@{
                                                                                                            kFIRParameterContentType:@"home",
                                                                                                            kFIRParameterItemID:@"alert_buy"
                                                                                                            }];
                                         
                                         [[InAppPurchase sharedManager] paymentRequestWithProductIdentifiers:[[NSArray alloc]initWithObjects:ITEM_1_ID, nil]];
                                     } else {
                                         [self alertPaymentError];
                                     }
                                     
                                 }];
            [alert addAction:cancel];
            [alert addAction:ok];
            
            
            [self presentViewController:alert animated:YES completion:nil];
            return NO;
        }
    }
    
    return YES;
}

- (void) alertPaymentError {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Payment Error",nil)
                                                    message:NSLocalizedString(@"You are not authorized to purchase from AppStore.",nil)
                                                   delegate:self
                                          cancelButtonTitle:@"Done" otherButtonTitles:nil];
    [alert show];
}

- (void) processTextfromUrlScheme {
    
    // process text from url scheme
    AppDelegate *appdelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    NSString *textFromUrlScheme = [appdelegate getTextFromUrlScheme];
    if(![textFromUrlScheme isEqualToString:@""]){
        _textView.text = textFromUrlScheme;
        [appdelegate clearTextFromUrlScheme];
    }
}

- (IBAction)recordAudio:(id)sender {
    
    // if listening, return
    if([_synthesizer isSpeaking]){
        NSLog(@"playing...");
        return;
    }
    
    if(![self checkMicPermission]){
        
        //microphone access unavailable
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Microphone Permission",nil)
                                                        message:NSLocalizedString(@"Please allow Microphone access for recording.\nSettings-Privacy-Microphone",nil)
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Done",nil) otherButtonTitles:nil];
        [alert show];
        
        return;
    }
    
    if(![self checkReachability]){
        return;
    }
    
    if([_textView.text length] >= _textLimitCount){
        
        
        UIAlertController * alert=   [UIAlertController
                                      alertControllerWithTitle:NSLocalizedString(@"Text length exceed",nil)
                                      message:NSLocalizedString(@"Please buy upgrade pack and use continue.\n\nUnlimit uses by a day\nSupport 2,048 chars\nNo Ads",nil)
                                      preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* cancel = [UIAlertAction
                                 actionWithTitle:NSLocalizedString(@"Later",nil)
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action)
                                 {
                                     [alert dismissViewControllerAnimated:YES completion:nil];
                                 }];
        UIAlertAction* ok = [UIAlertAction
                             actionWithTitle:NSLocalizedString(@"Buy",nil)
                             style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction * action)
                             {
                                 [alert dismissViewControllerAnimated:YES completion:nil];
                                 NSLog(@"UPGRADE!");
                                 
                                 if ([SKPaymentQueue canMakePayments]) {
                                     [_spinner startAnimating];
                                     
                                     _isPurchasing = YES;
                                     
                                     [FIRAnalytics logEventWithName:kFIREventSelectContent parameters:@{
                                                                                                        kFIRParameterContentType:@"home",
                                                                                                        kFIRParameterItemID:@"alert_buy"
                                                                                                        }];
                                     
                                     [[InAppPurchase sharedManager] paymentRequestWithProductIdentifiers:[[NSArray alloc]initWithObjects:ITEM_1_ID, nil]];
                                 } else {
                                     [self alertPaymentError];
                                 }
                             }];
        
        
        [alert addAction:cancel];
        [alert addAction:ok];
        
        
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    
    
    if(![self checkLimitCount:@"listen"]){
        return;
    }
    
    [FIRAnalytics logEventWithName:kFIREventSelectContent parameters:@{
                                                                       kFIRParameterContentType:@"home",
                                                                       kFIRParameterItemID:@"btn_say"
                                                                       }];
    
    _btnRecordAudio.enabled = NO;
    
    _infoAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Listening...",nil)
                                                 message:NSLocalizedString(@"Morpheus is listening your sentences.",nil)
                                                delegate:self
                                       cancelButtonTitle:NSLocalizedString(@"Stop",nil) otherButtonTitles:nil];
    _infoAlert.tag = ALERT_STOP_RECORDING;
    [_infoAlert show];

    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryRecord error:nil];
    [audioSession setActive:YES error:nil];
    
    _audioData = [[NSMutableData alloc] init];
    [[AudioController sharedInstance] prepareWithSampleRate:SAMPLE_RATE];
    [[SpeechRecognitionService sharedInstance] setSampleRate:SAMPLE_RATE];
    [[AudioController sharedInstance] start];
}

- (IBAction)stopAudio:(id)sender {
    
    [[AudioController sharedInstance] stop];
    [[SpeechRecognitionService sharedInstance] stopStreaming];
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setActive:NO error:nil];
    
    _btnRecordAudio.enabled = YES;
    
    [self hideInfoAlert];
}

- (IBAction)checkGrammer:(id)sender {
    NSLog(@"check grammer");
    
    if(![self checkReachability]){
        return;
    }
    
    if(!_isUpdatedAfterCheck){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Not updated",nil)
                                                        message:NSLocalizedString(@"Sentence is not updated.",nil)
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Done",nil) otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    if(![self checkLimitCount:@"check"]){
        return;
    }
    
    if(![self hasText:NSLocalizedString(@"Say in English\nafter tapping\n'Say' button.",nil)]){
        return;
    }
    
    [self hideInfoAlert];
    
    _infoAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Checking...",nil)
                                            message:NSLocalizedString(@"Morpheus is checking your sentences.",nil)
                                           delegate:self
                                  cancelButtonTitle:NSLocalizedString(@"Cancel",nil) otherButtonTitles:nil];
    _infoAlert.tag = ALERT_STOP_CHECKING;
    [_infoAlert show];
    
    [FIRAnalytics logEventWithName:kFIREventSelectContent parameters:@{
                                                                       kFIRParameterContentType:@"home",
                                                                       kFIRParameterItemID:@"btn_check"
                                                                       }];
    _recordedString = _textView.text;
    
    NSString *txtString = _recordedString;
    _checkedGrammerString = _recordedString;
    
    NSLog(@"%@", txtString);
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    
    
    _task = [manager GET:API_CHECK_GRAMMER_URL
      parameters:@{@"text": txtString,
                   @"key": API_CHECK_GRAMMER_KEY}
        progress:nil
         success:^(NSURLSessionTask *task, id responseObject) {
             
             NSLog(@"%@", responseObject);
             
             NSDictionary *jsonDict = (NSDictionary *) responseObject;
             
             Boolean result = [[jsonDict objectForKey:@"result"] boolValue];
             
             if(!result){
                 [self hideInfoAlert];
                 [self showAlertTempError];
                 return;
             }
             
             
             @try {
             
                 int score = [[jsonDict objectForKey:@"score"] intValue];
                 
                 NSLog(@"result : %d / score : %d", result, score);
                 
                 NSArray *errors = [jsonDict objectForKey:@"errors"];
                 
                 /*
                 NSArray *lawErrors = [jsonDict objectForKey:@"errors"];
                
                 // process law errors
                 NSMutableArray *errors = [NSMutableArray array];
                 
                 for (int i = 0; i < [lawErrors count]; i++) {
                     
                     NSDictionary *error = [lawErrors objectAtIndex: i];
                     NSString *targetWord = [error objectForKey:@"bad"];
                     
                     NSArray *componentsSeparatedByWhiteSpace = [targetWord componentsSeparatedByString:@" "];
                     
                     if([componentsSeparatedByWhiteSpace count] <= 1){
                         [errors addObject:error];
                     }
                 }
                 */
                 
                 NSLog(@"errors : %@", errors);
                 
                 NSDictionary *error = nil;
                 int length = 0;
                 int offset = 0;
                 
                 NSArray *betterWords = nil;
                 NSString *betterWord = @"";
                 NSString *badWord = @"";
                 
                 
                 NSMutableArray *offsets = [NSMutableArray array];
                 
                 for (int i = 0; i < [errors count]; i++) {
                     
                     error = [errors objectAtIndex: i];
                     
                     offset = [[error objectForKey:@"offset"] intValue];
                     [offsets addObject:[NSNumber numberWithInteger:offset]];
                     
                 }
                 
                 NSLog(@"offsets : %@", offsets);
                 
                 NSMutableArray *resultWords = [NSMutableArray array];
                 
                 
                 for (int i = 0; i < [errors count]; i++) {
                     
                     error = [errors objectAtIndex: i];
                     
                     badWord = [error objectForKey:@"bad"];
                     length = [[error objectForKey:@"length"] intValue];
                     
                     // offset
                     offset = [[offsets objectAtIndex:i] intValue];
                     
                     betterWords = [error objectForKey:@"better"];
                     betterWord = [betterWords objectAtIndex: 0];
                     
                     [resultWords addObject:betterWord];
                     
                     NSLog(@"%d - bad : %@ / batter : %@ / length : %d / offset : %d", i, badWord, betterWord, length, offset);
                     
                     NSString *res = [_checkedGrammerString substringWithRange:NSMakeRange(offset, length)];
                     NSLog(@"       %@ = %@", badWord, res);
                     
                     if(![badWord isEqualToString:res]){
                         continue;
                     }
                     
                     _checkedGrammerString = [_checkedGrammerString stringByReplacingOccurrencesOfString:badWord withString:betterWord options:0 range:NSMakeRange(offset, length)];
                     
                     NSLog(@"       %@", _checkedGrammerString);
                     
                     // update offset
                     int betterWordCount = (int)[betterWord length];
                     int badWordCount = (int)[badWord length];
                     int balanceOffset = betterWordCount - badWordCount;
                     
                     NSLog(@"balanceOffset : %d", balanceOffset);
                     
                     for (int j = i+1; j < [offsets count]; j++) {
                         int oldOffset = [[offsets objectAtIndex:j] intValue];
                         int newOffset = oldOffset + balanceOffset;
                         
                         NSLog(@"oldOffset : %d / new Offset : %d", oldOffset, newOffset);
                         
                         [offsets replaceObjectAtIndex:j withObject:[NSNumber numberWithInteger:newOffset]];
                     }
                     
                     NSLog(@"NEW offsets : %@", offsets);
                 }
                 
                 NSMutableAttributedString *stringAttributed = [[NSMutableAttributedString alloc]initWithString:_checkedGrammerString];
                 
                 
                 
                 for (int i = 0; i < [resultWords count]; i++) {
                     
    //                 NSLog(@"resultWords : %@", resultWords);
                     
                     NSInteger length = [(NSString*)[resultWords objectAtIndex:i] length];
                     
                     // offset
                     offset = [[offsets objectAtIndex:i] intValue];
                     
                     [stringAttributed addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:255.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:1.0] range:NSMakeRange(offset, length)];
                     
                     [stringAttributed addAttribute:NSBackgroundColorAttributeName value:[UIColor colorWithRed:60.0/255.0 green:136.0/255.0 blue:223.0/255.0 alpha:1.0] range:NSMakeRange(offset, length)];
                 }
               
                 NSLog(@"RESULT : %@", _checkedGrammerString);
                 
    //             NSString *checkedString = [NSString stringWithFormat:@"score : %d\n\n%@", score, _checkedGrammerString];
    //             _textView.text = checkedString;
                 
                 
                 NSInteger chekedGrammerStingLength = [_checkedGrammerString length];
                 
                 if(chekedGrammerStingLength >= _textLimitCount){
                     chekedGrammerStingLength = _textLimitCount;
                 }
                 
                [self updateLblTextLength:chekedGrammerStingLength];
                 
                 _textView.text = _checkedGrammerString;
                 
                 CGFloat fontSize = _textView.font.pointSize;
                 UIFont *textFont = [UIFont fontWithName:@"HelveticaNeue" size:fontSize];
                 [stringAttributed addAttribute:NSFontAttributeName value:textFont range:NSMakeRange(0, [_checkedGrammerString length])];
                 [_textView setAttributedText:stringAttributed];
                 
                 _isUpdatedAfterCheck = NO;
                 _imgCheckedGrammer.highlighted = YES;
                 
                 /*
                 CGFloat fontSize = _textView.font.pointSize;
                 //UIFont *textFont = [UIFont italicSystemFontOfSize:fontSize];
                 UIFont *textFont = [UIFont fontWithName:@"HelveticaNeue-Italic" size:fontSize];
                 
                 _textView.font = textFont;
                 */
                 
                 // vibrate
                 NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                 if([defaults boolForKey:@"isVibrationAfterCheking"]){
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                 }
                 
                 [self decreaseCount:@"check"];
                 
                 //             NSLog(@"RESULT : %@", _checkedGrammerString);
                 
                 /*
                  NSDictionary *jsonDict = (NSDictionary *) responseObject;
                  NSArray *accounts = [jsonDict objectForKey:@"accounts"];
                  
                  NSDictionary *account = [accounts objectAtIndex: 0];
                  
                  NSString *accountName = [account objectForKey:@"accountName"];
                  NSLog(@"accountName : %@", accountName);
                  */
                 [self hideInfoAlert];
                 
             }
             @catch (NSException *e){
                 [self hideInfoAlert];
                 [self showAlertTempError];
                 return;
             }
             
             
         } failure:^(NSURLSessionTask *operation, NSError *error) {
            NSLog(@"%@", error);
             [self hideInfoAlert];
         }];
    
}


- (void) hideInfoAlert {
    if (_infoAlert) {
        [_infoAlert dismissWithClickedButtonIndex:0 animated:NO];
        _infoAlert = nil;
    }
}


- (void) processSampleData:(NSData *)data
{
    [self.audioData appendData:data];
    NSInteger frameCount = [data length] / 2;
    int16_t *samples = (int16_t *) [data bytes];
    int64_t sum = 0;
    for (int i = 0; i < frameCount; i++) {
        sum += abs(samples[i]);
    }
    NSLog(@"audio %d %d", (int) frameCount, (int) (sum * 1.0 / frameCount));
    
    // We recommend sending samples in 100ms chunks
    int chunk_size = 0.1 /* seconds/chunk */ * SAMPLE_RATE * 2 /* bytes/sample */ ; /* bytes/chunk */
    
    if ([self.audioData length] > chunk_size) {
        NSLog(@"SENDING");
        [[SpeechRecognitionService sharedInstance] streamAudioData:self.audioData
                                                            region:_englishRegionCode
                                                    withCompletion:^(StreamingRecognizeResponse *response, NSError *error) {
                                                        if (error) {
                                                            
                                                            NSLog(@"ERROR : %@", error);
                                                            NSLog(@"ERROR desc : %@", [error localizedDescription]);
                                                            
                                                            [self stopAudio:nil];
                                                            
                                                            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Temporary failure",nil)
                                                                                                            message:NSLocalizedString(@"Please use after a while.",nil)
                                                                                                           delegate:self
                                                                                                  cancelButtonTitle:NSLocalizedString(@"Done",nil) otherButtonTitles:nil];
                                                            [alert show];

                                                        } else if (response) {
                                                            BOOL finished = NO;
                                                            NSLog(@"RESPONSE: %@", response);
                                                            for (StreamingRecognitionResult *result in response.resultsArray) {
                                                                if (result.isFinal) {
                                                                    
                                                                    _recordedString = result.alternativesArray[0].transcript;
                                                                    
                                                                    NSString *allText = @"";
                                                                    
                                                                    if([_textView hasText]){
                                                                        allText = [_textView.text stringByAppendingString:[NSString stringWithFormat:@" %@", _recordedString]];
                                                                    } else {
                                                                        allText = _recordedString;
                                                                    }
                                                                    
                                                                    
                                                                    if([allText length] > _textLimitCount){
                                                                       allText = [allText substringToIndex:_textLimitCount];
                                                                    }
                                                                    
                                                                     [self updateLblTextLength:allText.length];
                                                                    
                                                                    _textView.text = allText;
                                                                    
                                                                    _placeHolderLabel.hidden = YES;
                                                                    [self resetFontStyle];
                                                                    
                                                                    // vibrate
                                                                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                                                                    if([defaults boolForKey:@"isVibrationAfterListening"]){
                                                                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                                                                    }
                                                                    
                                                                    finished = YES;
                                                                }
                                                            }
                                                            
                                                            
                                                            
                                                            if (finished) {
                                                                [self decreaseCount:@"listen"];
                                                                [self stopAudio:nil];
                                                            }
                                                        }
                                                    }
         ];
        self.audioData = [[NSMutableData alloc] init];
    }
}

- (void) updateLblTextLength:(NSInteger) length {
    _lblTextCount.text=[NSString stringWithFormat:@"%ld / %d", length, _textLimitCount];
}

- (IBAction)reset:(id)sender {
    NSLog(@"reset");
    _textView.text = @"";
    
    [self updateLblTextLength:_textView.text.length];
    
    [self resetFontStyle];
    
    _placeHolderLabel.hidden = NO;
    
    [FIRAnalytics logEventWithName:kFIREventSelectContent parameters:@{
                                                                       kFIRParameterContentType:@"home",
                                                                       kFIRParameterItemID:@"btn_reset"
                                                                       }];
    
}

- (IBAction)send:(id)sender {
    NSLog(@"send");
    
    if(![self hasText:NSLocalizedString(@"Say in English\nafter tapping\n'Say' button.",nil)]){
        return;
    }
    
    [FIRAnalytics logEventWithName:kFIREventSelectContent parameters:@{
                                                                       kFIRParameterContentType:@"home",
                                                                       kFIRParameterItemID:@"btn_send"
                                                                       }];
    
    NSString *textToShare = [_textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    NSArray *objectsToShare = @[textToShare];

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:objectsToShare applicationActivities:nil];
    
    NSArray *excludeActivities = @[UIActivityTypeAirDrop,
                                   UIActivityTypePrint,
                                   UIActivityTypeAssignToContact,
                                   UIActivityTypeSaveToCameraRoll,
                                   UIActivityTypeAddToReadingList,
                                   UIActivityTypePostToFlickr,
                                   UIActivityTypePostToVimeo];
    
    activityVC.excludedActivityTypes = excludeActivities;
    
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (Boolean) hasText : (NSString*) message {
    
    // check text
    NSString *text = [_textView.text stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
    
    if(![_textView hasText] || [text isEqualToString:@""] ){
        NSLog(@"no text");
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No sentences",nil)
                                                        message:message
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Done",nil) otherButtonTitles:nil];
        
        [alert show];
        
        return NO;
    } else {
        return YES;
    }
    
    
}

- (void) resetFontStyle {
    
    NSMutableAttributedString *stringAttributed = [[NSMutableAttributedString alloc]initWithString:_textView.text];
    CGFloat fontSize = _textView.font.pointSize;
    UIFont *textFont = [UIFont fontWithName:@"HelveticaNeue" size:fontSize];
    [stringAttributed addAttribute:NSFontAttributeName value:textFont range:NSMakeRange(0, [_textView.text length])];
    [stringAttributed addAttribute:NSBackgroundColorAttributeName value:[UIColor clearColor] range:NSMakeRange(0, [_textView.text length])];
    [_textView setAttributedText:stringAttributed];
    
    _isUpdatedAfterCheck = YES;
    _imgCheckedGrammer.highlighted = NO;
}

// hide keyboard
- (void)scrollTap:(UIGestureRecognizer*)gestureRecognizer {
    
    //make keyboard disappear , you can use resignFirstResponder too, it's depend.
    [self.scrollView endEditing:YES];
}

- (NSString*) processTextLimit:(NSString*) text {
    
    NSInteger len = [text length];
    if(len > _textLimitCount){
        text = [text substringToIndex:_textLimitCount];
    }

    return text;
}

// show / hide placehoder
- (void)textViewDidEndEditing:(UITextView *)textView
{
    if (![_textView hasText]) {
        _placeHolderLabel.hidden = NO;
    }
    
    [self resetFontStyle];
}

- (void) textViewDidChange:(UITextView *)textView
{
    if(![_textView hasText]) {
        _placeHolderLabel.hidden = NO;
    } else {
        _placeHolderLabel.hidden = YES;
    }
    
    [self resetFontStyle];
    
    [self updateLblTextLength:textView.text.length];
}


- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    
    // process copy and paste
//    if ([text isEqualToString:[UIPasteboard generalPasteboard].string]) {
//    }
    
    if([text length] == 0)
    {
        if([textView.text length] != 0)
        {
            return YES;
        }
    }
    else if([[textView text] length] > (_textLimitCount - 1))
    {
        
        // process text limit
        _textView.text = [self processTextLimit:textView.text];
        [self updateLblTextLength:_textView.text.length];
        
        return NO;
    }
    return YES;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(alertView.tag == ALERT_STOP_RECORDING)
    {
        NSLog(@"stop recording");
        [self stopAudio:nil];
    } else if(alertView.tag == ALERT_STOP_CHECKING) {
        NSLog(@"stop checking");
        [_task cancel];
    }

}

- (void) showUpdateAlert {
    UIAlertController * alert =   [UIAlertController
                                  alertControllerWithTitle:NSLocalizedString(@"Check for Update",nil)
                                  message:NSLocalizedString(@"Please update to the latest version.",nil)
                                  preferredStyle:UIAlertControllerStyleAlert];
    
    
    UIAlertAction* later = [UIAlertAction
                             actionWithTitle:NSLocalizedString(@"Later",nil)
                             style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction * action)
                             {
                                 [alert dismissViewControllerAnimated:YES completion:nil];
                             }];
    UIAlertAction* update = [UIAlertAction
                              actionWithTitle:NSLocalizedString(@"Update",nil)
                              style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction * action)
                              {
                                  [alert dismissViewControllerAnimated:YES completion:nil];
                                  
                                  [FIRAnalytics logEventWithName:kFIREventSelectContent parameters:@{
                                                                                                     kFIRParameterContentType:@"home",
                                                                                                     kFIRParameterItemID:@"alert_app_update"
                                                                                                     }];
                                  
                                  NSString *iTunesLink = @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=1200692859&mt=8";
                                  [[UIApplication sharedApplication] openURL:[NSURL URLWithString:iTunesLink]];
                                  
                              }];
    [alert addAction:later];
    [alert addAction:update];
    
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)listenText:(id)sender {
    NSLog(@"listenText");
    
    if(![self hasText:NSLocalizedString(@"Say in English\nafter tapping\n'Say' button.",nil)]){
        return;
    }
    
    if([_synthesizer isSpeaking]){
        [_synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setActive:NO error:nil];
        
        _btnListen.selected = NO;
        _btnListen.backgroundColor = [UIColor colorWithRed:60.0/255.0 green:136.0/255.0 blue:223.0/255.0 alpha:1.0];
        
    } else {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        _englishRegionCode = [defaults objectForKey:@"englishRegionCode"];
        NSLog(@"englishRegionCode : @%@", _englishRegionCode);
        
        
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        
        NSError *setCategoryError = nil;
        NSError *activationError = nil;
        
        BOOL success = [audioSession setCategory:AVAudioSessionCategoryPlayback
                                     withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&setCategoryError];
        
//        BOOL success = [audioSession setCategory:AVAudioSessionCategoryPlayback error:&setCategoryError];
        
        [audioSession setActive:YES error:&activationError];
        NSLog(@"Success %d", success);
        
//        [NSThread sleepForTimeInterval:.2];

        AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:_textView.text];
        utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:_englishRegionCode];
        utterance.rate = 0.4f;
        [_synthesizer speakUtterance:utterance];
        
        
        _btnListen.selected = YES;
        _btnListen.backgroundColor = [UIColor whiteColor];
    }
}

-(void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setActive:NO error:nil];
    
    _btnListen.selected = NO;
    _btnListen.backgroundColor = [UIColor colorWithRed:60.0/255.0 green:136.0/255.0 blue:223.0/255.0 alpha:1.0];
    
    _synthesizer.delegate = self;
}
@end

