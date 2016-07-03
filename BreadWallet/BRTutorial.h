//
//  BRTutorial.h
//  LoafWallet
//
//  Created by Sun Peng on 16/7/3.
//  Copyright © 2016年 Aaron Voisine. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BRTutorial : NSObject

- (instancetype)initWithViewController:(UIViewController *)vc;
- (void)playTutorial:(NSString *)tutorialName;

@end
