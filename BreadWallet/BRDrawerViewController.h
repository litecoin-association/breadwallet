//
//  BRDrawerViewController.h
//  LoafWallet
//
//  Created by Yifei Zhou on 7/21/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BRDrawerViewController;

@protocol BRDrawerViewControllerDelegate <NSObject>

@optional
- (void)drawerViewController:(BRDrawerViewController *)drawerViewController panelDidShowing:(BOOL)panelShowing;

@end

@interface BRDrawerViewController : UIViewController

@property (strong, nonatomic) UIViewController *mainViewController;

@property (strong, nonatomic) UIViewController *leftDrawerViewController;

@property (readonly, nonatomic) BOOL isPanelShowing;

@property (assign, nonatomic) CGFloat drawerWidth;

@property (weak, nonatomic) id<BRDrawerViewControllerDelegate> delegate;

- (void)setPanelShowing:(BOOL)panelShowing animated:(BOOL)animated;

@end
