//
//  UIColor+MyApp.m
//  Speech
//
//  Created by Rock Kang on 2020/04/07.
//  Copyright © 2020 Google. All rights reserved.
//
#import "UIColor+MyApp.h"

@implementation UIColor (MyApp)

+ (UIColor *) setMyForegroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark ?
                [UIColor colorWithRed:255.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:1.0] :
                [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1.0];
        }];
    } else {
        return [UIColor colorWithRed:255.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:1.0];
    }
}

+ (UIColor *) setMyBackgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark ?
                [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1.0] :
                [UIColor colorWithRed:255.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:1.0];
        }];
    } else {
        return [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1.0];
    }
}

+ (UIColor *) setMySettingBackgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark ?
            [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1.0] :
            [UIColor colorWithRed:243.0/255.0 green:249.0/255.0 blue:255.0/255.0 alpha:1.0];
        }];
    } else {
        return [UIColor colorWithRed:243.0/255.0 green:249.0/255.0 blue:255.0/255.0 alpha:1.0];
    }
}
@end
