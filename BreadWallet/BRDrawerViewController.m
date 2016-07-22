//
//  BRDrawerViewController.m
//  LoafWallet
//
//  Created by Yifei Zhou on 7/21/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

#import "BRDrawerViewController.h"
#import "BRMenuViewController.h"
#import "BRRootViewController.h"

#define SLIDE_TIMING 0.25f

@interface BRDrawerViewController ()

@property (assign, nonatomic, getter=isPanelShowing) BOOL panelShowing;

@property (strong, nonatomic) NSLayoutConstraint *drawerWidthConstraint;

@property (strong, nonatomic) UIView *containerView;

@property (strong, nonatomic) UITapGestureRecognizer *tapRecognizer;

@end

@implementation BRDrawerViewController

@synthesize panelShowing = _panelShowing;

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupInterfaces];
}

- (void)setupInterfaces
{
    NSDictionary *viewDictionary = @{ @"_containerView": self.containerView };

    [self.view addGestureRecognizer:self.tapRecognizer];

    [self.view addSubview:self.containerView];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[_containerView]-0-|"
                                                                      options:kNilOptions
                                                                      metrics:nil
                                                                        views:viewDictionary]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[_containerView]-0-|"
                                                                      options:kNilOptions
                                                                      metrics:nil
                                                                        views:viewDictionary]];

    self.containerView.hidden = YES;
}

- (UIView *)containerView
{
    if (!_containerView) {
        UIView *containerView = [[UIView alloc] initWithFrame:self.view.frame];
        containerView.backgroundColor = [UIColor clearColor];
        _containerView = containerView;
    }
    return _containerView;
}

- (UITapGestureRecognizer *)tapRecognizer
{
    if (!_tapRecognizer) {
        UITapGestureRecognizer *tapRecognizer =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(userDidTappedContainerView:)];
        _tapRecognizer = tapRecognizer;
    }
    return _tapRecognizer;
}

- (IBAction)userDidTappedContainerView:(id)sender
{
    if (![sender isKindOfClass:[UITapGestureRecognizer class]]) return;

    if (!self.isPanelShowing) return;

    UITapGestureRecognizer *tapRecognizer = (UITapGestureRecognizer *)sender;
    CGPoint loc = [tapRecognizer locationInView:self.view];
    if (CGRectContainsPoint(self.mainViewController.view.frame, loc)) {
        [self setPanelShowing:NO animated:YES];
    }
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

    [self.view insertSubview:_mainViewController.view atIndex:0];
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

    [self.view insertSubview:_leftDrawerViewController.view atIndex:0];
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
    if (_panelShowing == panelShowing) return;

    _panelShowing = panelShowing;

    if (_panelShowing) {
        [self openLeftPanelWithAnimated:animated];
    }
    else {
        [self closePanelWithAnimated:animated];
    }
}

- (void)openLeftPanelWithAnimated:(BOOL)animated
{
    [UIView animateWithDuration:animated ? SLIDE_TIMING : 0.0f
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{
            _mainViewController.view.frame =
                CGRectMake(self.drawerWidth, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
            _leftDrawerViewController.view.frame = CGRectMake(0, 0, self.drawerWidth, CGRectGetHeight(self.view.frame));

        }
        completion:^(BOOL finished) {
            if (finished && [self.delegate respondsToSelector:@selector(drawerViewController:panelDidShowing:)]) {
                [self.delegate drawerViewController:self panelDidShowing:YES];
            }
            self.containerView.hidden = NO;
        }];
}

- (void)closePanelWithAnimated:(BOOL)animated
{
    [UIView animateWithDuration:animated ? SLIDE_TIMING : 0.0f
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{ [self resetViews]; }
        completion:^(BOOL finished) {
            if (finished && [self.delegate respondsToSelector:@selector(drawerViewController:panelDidShowing:)]) {
                [self.delegate drawerViewController:self panelDidShowing:NO];
            }
            self.containerView.hidden = YES;
        }];
}

- (void)resetViews
{
    _mainViewController.view.frame =
        CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
    _leftDrawerViewController.view.frame =
        CGRectMake(-self.drawerWidth, 0, self.drawerWidth, CGRectGetHeight(self.view.frame));
}

@end
