//
//  InAppPurchase.m
//  Speech
//
//  Created by 1100003 on 2017. 1. 31..
//  Copyright © 2017년 Google. All rights reserved.
//

#import "InAppPurchase.h"


@implementation InAppPurchase

NSString *const InAppPurchasedNotification = @"InAppPurchasedNotification";

+ (id) sharedManager
{
    static InAppPurchase * sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (id) init {
    if( self == [super init] ) {
        self.delegate = nil;
    }
    
    return self;
}

- (void)dealloc {
    // Should never be called, but just here for clarity really.
}

- (void) callDelegateSuccess:(NSData *)receipt {
    if( self.delegate != nil ) {
        [self.delegate cbSuccess:receipt];
    }
}

- (void) callDelegateFail:(NSString *) reason {
    if( self.delegate != nil ) {
        [self.delegate cbFail:reason];
    }
    
    [self provideContentForProductIdentifier:@"" transactionIdentifier:@"" transactionDate:@"" mode:@"error"];
    
    if([reason isEqualToString:@"no_receipt"]){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Payment Error",nil)
                                                    message:NSLocalizedString(@"There isn't exist receipt.",nil)
                                                   delegate:self
                                          cancelButtonTitle:@"Done" otherButtonTitles:nil];
        [alert show];
    }
}

- (void) paymentRequestWithProductIdentifiers:(NSArray *)productIdentifiers
{
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc]
                                          initWithProductIdentifiers:[NSSet setWithArray:productIdentifiers]];
    productsRequest.delegate = self;
    [productsRequest start];
}

- (void) restoreProduct {
     [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}


// SKProductsRequestDelegate protocol method
- (void) productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    if( [response.products count] > 0 ) {
        [self paymentRequest:[response.products objectAtIndex:0]];
    } else {
        NSLog(@"In-App Purchase Fail");
        [self callDelegateFail:@"response.products count <= 0"];
    }
}

- (void) paymentRequest:(SKProduct *) product
{
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
    payment.quantity = 1;
    
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    
}

// Sent when the transaction array has changed (additions or state changes).  Client should check state of transactions and finish as appropriate.
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
                // Call the appropriate custom method for the transaction state.
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"SKPaymentTransactionStatePurchasing");
                [self showTransactionAsInProgress:transaction deferred:NO];
                break;
            case SKPaymentTransactionStateDeferred:
                NSLog(@"SKPaymentTransactionStateDeferred");
                [self showTransactionAsInProgress:transaction deferred:YES];
                break;
            case SKPaymentTransactionStateFailed:
                NSLog(@"SKPaymentTransactionStateFailed");
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStatePurchased:
                // Load the receipt from the app bundle.
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                NSLog(@"SKPaymentTransactionStateRestored");
                [self restoreTransaction:transaction];
                break;
            default:
                // For debugging
                NSLog(@"Unexpected transaction state %@", @(transaction.transactionState));
                [self callDelegateFail:@"transactionState is default"];
                break;
        }
    }
}

- (void) showTransactionAsInProgress:(SKPaymentTransaction *)transaction deferred:(BOOL)isDeferred {
}

- (void) failedTransaction:(SKPaymentTransaction *)transaction {
    [self callDelegateFail:@"failedTransaction"];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (NSString*) makeDateFormat:(NSDate *) date {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    return [dateFormatter stringFromDate:date];
}

- (void) completeTransaction:(SKPaymentTransaction *)transaction{
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
    if (!receipt) {
        /* No local receipt -- handle the error. */
        [self callDelegateFail:@"no_receipt"];
    } else {
        NSLog(@"completeTransaction");
        
        // restore
        if(transaction.originalTransaction.transactionIdentifier){
            NSString *transactionDate = [self makeDateFormat:transaction.originalTransaction.transactionDate];
            [self provideContentForProductIdentifier:transaction.originalTransaction.payment.productIdentifier transactionIdentifier:transaction.originalTransaction.transactionIdentifier transactionDate:transactionDate mode:@"buy"];
        // buy
        } else {
            NSString *transactionDate = [self makeDateFormat:transaction.transactionDate];
            [self provideContentForProductIdentifier:transaction.payment.productIdentifier transactionIdentifier:transaction.transactionIdentifier transactionDate:transactionDate mode:@"buy"];
        }
        
    }
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void) restoreTransaction:(SKPaymentTransaction *)transaction {
    
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
    if (!receipt) {
        /* No local receipt -- handle the error. */
        [self callDelegateFail:@"no_receipt"];
    } else {
        
        NSLog(@"restoreTransaction");
        
        NSString *transactionDate = [self makeDateFormat:transaction.originalTransaction.transactionDate];
        [self provideContentForProductIdentifier:transaction.originalTransaction.payment.productIdentifier transactionIdentifier:transaction.originalTransaction.transactionIdentifier transactionDate:transactionDate mode:@"restore"];
    }
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)provideContentForProductIdentifier:(NSString *)productIdentifier transactionIdentifier:(NSString *) transactionIdentifier transactionDate:(NSString *) transactionDate mode:(NSString *) mode{
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:productIdentifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSArray *result = [[NSArray alloc]initWithObjects:productIdentifier, mode, transactionIdentifier, transactionDate, nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:InAppPurchasedNotification object:result userInfo:nil];
}

// Sent when transactions are removed from the queue (via finishTransaction:).
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions {
    NSLog(@"removedTransactions");
}

// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    NSLog(@"restoreCompletedTransactionsFailedWithError");
    [self callDelegateFail:@"restoreCompletedTransactionsFailedWithError"];
}

// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    NSLog(@"paymentQueueRestoreCompletedTransactionsFinished");
}

// Sent when the download state has changed.
- (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads {
    NSLog(@"updatedDownloads");
}


@end
