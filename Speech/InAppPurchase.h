//
//  InAppPurchase.h
//  Speech
//
//  Created by 1100003 on 2017. 1. 31..
//  Copyright © 2017년 Google. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@protocol InAppPurchaseDelegate <NSObject>
- (void) cbSuccess:(NSData *) receipt;
- (void) cbFail:(NSString *) reason;
@end

@interface InAppPurchase : NSObject<SKProductsRequestDelegate, SKPaymentTransactionObserver>
{
}
@property (nonatomic, assign) id <InAppPurchaseDelegate> delegate;

+ (id) sharedManager;

- (void) paymentRequestWithProductIdentifiers:(NSArray *)productIdentifiers;
- (void) paymentRequest:(SKProduct *) product;
- (void) restoreProduct;
@end
