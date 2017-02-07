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

#import "SettingController.h"
#import <MessageUI/MessageUI.h>
#include <sys/sysctl.h>
#import "InAppPurchase.h"

@import Firebase;

#define MENU_SUPPORT_BUY_UPGRADE 10
#define MENU_SUPPORT_RESTORE_UPGRADE 11
#define MENU_SUPPORT_FEEDBACK 20
#define MENU_SUPPORT_INVITE_FRIENDS 21
#define MENU_SUPPORT_REVIEWS 22

#define MENU_VIBRATION_AFTER_LISTENING 30
#define MENU_VIBRATION_AFTER_CHECKING 31

#define ITEM_1_ID @"me.neosave.morpheus.item01"

@interface SettingController () <UITextViewDelegate, UIAlertViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *settingTableView;
@property (weak, nonatomic) IBOutlet UITableViewCell *buyCell;

@property (nonatomic, strong) UIPickerView *regionPickerView;
@property (nonatomic, strong) NSArray *regionData;
@property (weak, nonatomic) IBOutlet UITextField *englishRegionTextField;

@property (nonatomic, strong) NSString *englishRegionCode;
@property (nonatomic, strong) NSString *englishRegionName;
@property (assign) int englishRegionIndex;
@property (weak, nonatomic) IBOutlet UISwitch *afterListeningSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *afterCheckingSwitch;

@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (assign) Boolean isPaid;

@property (nonatomic, strong) FIRDatabaseReference *ref;

@end

@implementation SettingController


- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // hide buy cell
    if (indexPath.section == 0 && indexPath.row == 0) {
        // Show or hide cell
        if (!_isPaid) {
            return 44;
        } else {
            return 0;
        }
    }
    return 44;
}

- (void)viewWillAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(productPurchased:) name:@"InAppPurchasedNotification" object:nil];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _isPaid = [defaults boolForKey:ITEM_1_ID];
    
    if(_isPaid){
         [self.tableView reloadData];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    
    if([mode isEqualToString:@"error"]){
        return;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _isPaid = [defaults boolForKey:ITEM_1_ID];
    
    if(_isPaid){
        [self.tableView reloadData];
    }
    
    
    if([productIdentifier isEqualToString:ITEM_1_ID]){
        NSLog(@"productIdentifier : %@", productIdentifier);
        NSLog(@"transactionIdentifier : %@", transactionIdentifier);
        
        // update purchase info
        _ref = [[FIRDatabase database] reference];
        NSDictionary *purchase = @{@"uid": uId,
                                   @"pid": productIdentifier,
                                   @"tid": transactionIdentifier,
                                   @"date": transactionDate};
        
        NSDictionary *updates = @{[@"/purchases/" stringByAppendingString:transactionIdentifier]: purchase};
        [_ref updateChildValues:updates];
        
        
        if([mode isEqualToString:@"restore"]){
        
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Payment",nil)
                                                            message:NSLocalizedString(@"Retore is completed.\nThank you.",nil)
                                                           delegate:self
                                                  cancelButtonTitle:@"Done" otherButtonTitles:nil];
            [alert show];
        }
    }
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"SettingController viewDidLoad");
    _settingTableView.delegate = self;
    
    // Initialize picker view
    _regionPickerView = [[UIPickerView alloc] init];
    _regionData = @[@{@"en-US" : @"English (United States)"},
                    @{@"en-AU" : @"English (Australia)"},
                    @{@"en-CA" : @"English (Canada)"},
                    @{@"en-GB" : @"English (United Kingdom)"},
                    @{@"en-IN" : @"English (India)"},
                    @{@"en-IE" : @"English (Ireland)"},
                    @{@"en-NZ" : @"English (New Zealand)"},
                    @{@"en-PH" : @"English (Philippines)"},
                    @{@"en-ZA" : @"English (South Africa)"}
                    ];

    _regionPickerView.dataSource = self;
    _regionPickerView.delegate = self;
    
    _englishRegionTextField.inputView = _regionPickerView;
    
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // init paid
    _isPaid = [defaults boolForKey:ITEM_1_ID];
    
    _englishRegionCode = [defaults objectForKey:@"englishRegionCode"];
    NSLog(@"englishRegionCode : @%@", _englishRegionCode);

    
    _englishRegionName = @"";
    _englishRegionIndex = 0;
    
    for (int i = 0; i < [_regionData count]; i++) {
        
        NSDictionary *dict = [_regionData objectAtIndex:i];
        NSArray *key = [dict allKeys];
        NSArray *value = [dict allValues];
        
        if([key[0] isEqualToString:_englishRegionCode]){
            _englishRegionName = value[0];
            _englishRegionIndex = i;
            break;
        }
    }
    
    _englishRegionTextField.text = _englishRegionName;
    [_regionPickerView selectRow:_englishRegionIndex inComponent:0 animated:YES];
    
    
    [_afterListeningSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    
    [_afterCheckingSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    
    if([defaults boolForKey:@"isVibrationAfterListening"]){
        [_afterListeningSwitch setOn:YES];
    } else {
        [_afterListeningSwitch setOn:NO];
    }
    
    if([defaults boolForKey:@"isVibrationAfterCheking"]){
        [_afterCheckingSwitch setOn:YES];
    } else {
        [_afterCheckingSwitch setOn:NO];
    }
    
    // indicator
    _spinner = [[UIActivityIndicatorView alloc]
                initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [_spinner setColor:[UIColor grayColor]];
    _spinner.center = CGPointMake((self.navigationController.view.frame.size.width/2), (self.navigationController.view.frame.size.height/2));
    _spinner.hidesWhenStopped = YES;
    [self.navigationController.view addSubview:_spinner];
}


- (void)switchChanged:(UISwitch *)sender
{
    
    NSInteger tag = [sender tag];
    BOOL state = [sender isOn];
    NSLog(@"tag : %ld / state : %d", tag, state);
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if(tag == MENU_VIBRATION_AFTER_LISTENING){
        [defaults setBool:state forKey:@"isVibrationAfterListening"];
    } else if(tag == MENU_VIBRATION_AFTER_CHECKING){
        [defaults setBool:state forKey:@"isVibrationAfterCheking"];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSLog(@"isVibrationAfterListening : %d / isVibrationAfterCheking : %d", [defaults boolForKey:@"isVibrationAfterListening"], [defaults boolForKey:@"isVibrationAfterCheking"]);
    
}

// The number of columns of data
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// The number of rows of data
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return _regionData.count;
}

// The data to return for the row and component (column) that's being passed in
- (NSString*)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    
    NSDictionary *dict = [_regionData objectAtIndex:row];
    NSArray *value = [dict allValues];
    return value[0];
}

// Catpure the picker view selection
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    // This method is triggered whenever the user makes a change to the picker selection.
    // The parameter named row and component represents what was selected.
    
    
    NSDictionary *dict = [_regionData objectAtIndex:row];
    NSArray *key = [dict allKeys];
    NSArray *value = [dict allValues];
    
    NSLog(@"%@", key[0]);
    
    _englishRegionTextField.text = value[0];
    
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:key[0] forKey:@"englishRegionCode"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
     [_englishRegionTextField resignFirstResponder];
}


-(void)dismissPicker:(id)sender{
    [_englishRegionTextField resignFirstResponder];
}


-(void) inviteFriend {
    NSString *textToShare = NSLocalizedString(@"Download the Morpheus",nil);

    NSURL *myWebsite = [NSURL URLWithString:@"https://itunes.apple.com/app/id1200692859?mt=8"];
    
    NSArray *objectsToShare = @[textToShare, myWebsite];
    
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

- (void) alertPaymentError {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Payment Error",nil)
                                                    message:NSLocalizedString(@"You are not authorized to purchase from AppStore.",nil)
                                                   delegate:self
                                          cancelButtonTitle:@"Done" otherButtonTitles:nil];
    [alert show];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    NSLog(@"%ld", cell.tag);
    
    switch (cell.tag) {
        
        case MENU_SUPPORT_BUY_UPGRADE:
            
            if ([SKPaymentQueue canMakePayments]) {
                [_spinner startAnimating];
                
                [FIRAnalytics logEventWithName:kFIREventSelectContent parameters:@{
                                                                                   kFIRParameterContentType:@"settings",
                                                                                   kFIRParameterItemID:@"btn_buy"
                                                                                   }];
                
                [[InAppPurchase sharedManager] paymentRequestWithProductIdentifiers:[[NSArray alloc]initWithObjects:ITEM_1_ID, nil]];
            } else {
                [self alertPaymentError];
            }
            break;
        case MENU_SUPPORT_RESTORE_UPGRADE:
            
            if ([SKPaymentQueue canMakePayments]) {
                [_spinner startAnimating];
                
                [FIRAnalytics logEventWithName:kFIREventSelectContent parameters:@{
                                                                                   kFIRParameterContentType:@"settings",
                                                                                   kFIRParameterItemID:@"btn_restore"
                                                                                   }];
                
                [[InAppPurchase sharedManager] restoreProduct];
            } else {
                [self alertPaymentError];
            }
            break;
        case MENU_SUPPORT_FEEDBACK:
            [self feedback];
            [FIRAnalytics logEventWithName:kFIREventSelectContent parameters:@{
                                                                               kFIRParameterContentType:@"settings",
                                                                               kFIRParameterItemID:@"btn_feedback"
                                                                               }];
            break;
        case MENU_SUPPORT_INVITE_FRIENDS:
            [self inviteFriend];
            [FIRAnalytics logEventWithName:kFIREventSelectContent parameters:@{
                                                                               kFIRParameterContentType:@"settings",
                                                                               kFIRParameterItemID:@"btn_invite_friend"
                                                                               }];
            break;
        case MENU_SUPPORT_REVIEWS:
            [self goReview];
            [FIRAnalytics logEventWithName:kFIREventSelectContent parameters:@{
                                                                               kFIRParameterContentType:@"settings",
                                                                               kFIRParameterItemID:@"btn_go_review"
                                                                               }];

            break;
        default:
            break;
    }
}

- (void) feedback {
    
    if ([MFMailComposeViewController canSendMail]) {
        
        MFMailComposeViewController *composeViewController = [[MFMailComposeViewController alloc] initWithNibName:nil bundle:nil];
        [composeViewController setMailComposeDelegate:self];
        
        UIDevice *device = [UIDevice currentDevice];
        
        NSString *deviceName = [self platform];
        NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        NSString *systemVersion = device.systemVersion;
        
        NSString *emailSubject = [NSString stringWithFormat:@"[%@] %@", [[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleDisplayName"], NSLocalizedString(@"Support & Feedback",nil)];
        NSString *emailBody = [NSString stringWithFormat:@"\n\n------------\n%@\n- App Version : %@\n- Device : %@\n- OS : %@\n- UID : %@", NSLocalizedString(@"don't delete following information for supporting.",nil), appVersion, deviceName, systemVersion, [FIRAuth auth].currentUser.uid];
        
        [composeViewController setToRecipients:@[@"help@neosave.me"]];
        [composeViewController setSubject:emailSubject];
        [composeViewController setMessageBody:emailBody isHTML:NO];
        
        [self presentViewController:composeViewController animated:YES completion:nil];
    }
}


- (NSString *) platform{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    return platform;
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    UIAlertView *alert;
    
    switch (result)
    {
        case MFMailComposeResultCancelled:
            break;
        case MFMailComposeResultSent:
            alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Feedback",nil)
                                                            message:NSLocalizedString(@"Thank you for your feedback.",nil)
                                                           delegate:self
                                                  cancelButtonTitle:@"Done" otherButtonTitles:nil];
            
            [alert show];
            
            NSLog(@"Mail sent");
            break;
        case MFMailComposeResultFailed:
            
            alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Feedback",nil)
                                                            message:NSLocalizedString(@"failed sending feeback",nil)
                                                           delegate:self
                                                  cancelButtonTitle:@"Done" otherButtonTitles:nil];
            
            [alert show];
            break;
        default:
            break;
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) goReview {
    UIAlertController * alert =   [UIAlertController
                                   alertControllerWithTitle:NSLocalizedString(@"Reviews",nil)
                                   message:NSLocalizedString(@"Please review this app in the Appstore.",nil)
                                   preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* later = [UIAlertAction
                            actionWithTitle:NSLocalizedString(@"Later",nil)
                            style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction * action)
                            {
                                [alert dismissViewControllerAnimated:YES completion:nil];
                            }];
    
    UIAlertAction* confirm = [UIAlertAction
                              actionWithTitle:NSLocalizedString(@"Review",nil)
                              style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction * action)
                              {
                                  [alert dismissViewControllerAnimated:YES completion:nil];
                                  NSURL *url = [NSURL URLWithString:@"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=1200692859&onlyLatestVersion=true&pageNumber=0&sortOrdering=1&type=Purple+Software"];
                                  [[UIApplication sharedApplication] openURL:url];
                                  
                              }];
    
    [alert addAction:later];
    [alert addAction:confirm];
    
    [self presentViewController:alert animated:YES completion:nil];
}
@end

