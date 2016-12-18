//
//  UIViewController+BRDrawerViewController.m
//  LoafWallet
//
//  Created by Yifei Zhou on 7/21/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

#import "UIViewController+BRDrawerViewController.h"

@implementation UIViewController (BRDrawerViewController)

- (BRDrawerViewController *)drawerViewController
{
    UIViewController *viewController =
        self.parentViewController ? self.parentViewController : self.presentingViewController;
    while (!(viewController == nil || [viewController isKindOfClass:[BRDrawerViewController class]])) {
        viewController = viewController.parentViewController ? viewController.parentViewController
                                                             : viewController.presentingViewController;
    }

    return (BRDrawerViewController *)viewController;
}

@end
