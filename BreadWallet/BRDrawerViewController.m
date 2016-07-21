//
//  BRDrawerViewController.m
//  LoafWallet
//
//  Created by Yifei Zhou on 7/21/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

#import "BRDrawerViewController.h"
#import "BRRootViewController.h"
#import "BRMenuViewController.h"

#define SLIDE_TIMING 0.25f

@interface BRDrawerViewController ()

@property (assign, nonatomic, getter=isPanelShowing) BOOL panelShowing;

@property (strong, nonatomic) NSLayoutConstraint *drawerWidthConstraint;

@end

@implementation BRDrawerViewController

@synthesize panelShowing = _panelShowing;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupInterfaces];
}

- (void)setupInterfaces {
    
}

- (void)setMainViewController:(UIViewController *)mainViewController
{
    UIViewController *oldController = _mainViewController;
    
    {
        [oldController willMoveToParentViewController:nil];
        [oldController.view removeFromSuperview];
        [oldController removeFromParentViewController];
    }
    
    _mainViewController = mainViewController;
    
    if (!_mainViewController) {
        return;
    }
    
    [self.view addSubview:_mainViewController.view];
    [self addChildViewController:_mainViewController];
    [_mainViewController didMoveToParentViewController:self];
    
    [self resetViews];
}

- (void)setLeftDrawerViewController:(UIViewController *)leftDrawerViewController
{
    UIViewController *oldController = _leftDrawerViewController;
    
    {
        [oldController.view removeConstraint:self.drawerWidthConstraint];
        [oldController willMoveToParentViewController:nil];
        [oldController.view removeFromSuperview];
        [oldController removeFromParentViewController];
    }
    
    _leftDrawerViewController = leftDrawerViewController;
    
    if (!_leftDrawerViewController) {
        return;
    }
    
    [self.view addSubview:_leftDrawerViewController.view];
    [self addChildViewController:_leftDrawerViewController];
    [_leftDrawerViewController didMoveToParentViewController:self];
    
    self.drawerWidthConstraint = [NSLayoutConstraint constraintWithItem:_leftDrawerViewController.view
                                                              attribute:NSLayoutAttributeWidth
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:nil
                                                              attribute:NSLayoutAttributeWidth
                                                             multiplier:1
                                                               constant:self.drawerWidth];
    
    [self resetViews];
}

- (void)setDrawerWidth:(CGFloat)drawerWidth
{
    _drawerWidth = drawerWidth;
    self.drawerWidthConstraint.constant = drawerWidth;
}

- (void)setPanelShowing:(BOOL)panelShowing animated:(BOOL)animated
{
    if (_panelShowing == panelShowing)
        return;
    
    _panelShowing = panelShowing;
    
    if (_panelShowing) {
        [self openLeftPanelWithAnimated:animated];
    } else {
        [self closePanelWithAnimated:animated];
    }
}

- (void)openLeftPanelWithAnimated:(BOOL)animated {
    [UIView animateWithDuration:animated ? SLIDE_TIMING : 0.0f delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        _mainViewController.view.frame = CGRectMake(self.drawerWidth, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
        _leftDrawerViewController.view.frame = CGRectMake(0, 0, self.drawerWidth, CGRectGetHeight(self.view.frame));
        
    }
                     completion:^(BOOL finished) {
                         if (finished && [self.delegate respondsToSelector:@selector(drawerViewController:panelDidShowing:)]) {
                             [self.delegate drawerViewController:self panelDidShowing:YES];
                         }
                     }];
}

- (void)closePanelWithAnimated:(BOOL)animated {
    [UIView animateWithDuration:animated ? SLIDE_TIMING : 0.0f delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        [self resetViews];
    }
                     completion:^(BOOL finished) {
                         if (finished && [self.delegate respondsToSelector:@selector(drawerViewController:panelDidShowing:)]) {
                             [self.delegate drawerViewController:self panelDidShowing:NO];
                         }
                     }];
}

- (void)resetViews
{
    _mainViewController.view.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
    _leftDrawerViewController.view.frame = CGRectMake(-self.drawerWidth, 0, self.drawerWidth, CGRectGetHeight(self.view.frame));
}

@end
