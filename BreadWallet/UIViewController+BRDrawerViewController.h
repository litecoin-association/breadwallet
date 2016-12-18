//
//  UIViewController+BRDrawerViewController.h
//  LoafWallet
//
//  Created by Yifei Zhou on 7/21/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

#import "BRDrawerViewController.h"
#import <UIKit/UIKit.h>

/**
 This category adds a convience method on `UIViewController` for accessing a sliding view controller from one of its
 child view controllers.
 */
@interface UIViewController (BRDrawerViewController)

/**
 The nearest ancestor in the view controller hierarchy that is a sliding view controller, or nil if the view controller
 is not a descendant of a sliding view controller's hierarchy.
 */
- (BRDrawerViewController *)drawerViewController;

@end
