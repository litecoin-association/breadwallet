//
//  BRTutorial.m
//  LoafWallet
//
//  Created by Sun Peng on 16/7/3.
//  Copyright © 2016年 Aaron Voisine. All rights reserved.
//

#import "BRTutorial.h"

#define WEBVIEW_TAG 9999
#define ASPECT_RATIO (1440.0/1960)

@interface BRTutorial ()

@property (nonatomic, weak) UIViewController *containerVC;
@property (nonatomic, strong) UIWebView *playerView;

@end

@implementation BRTutorial

- (instancetype)initWithViewController:(UIViewController *)vc {
    if (self = [super init]) {
        self.containerVC = vc;
    }

    return self;
}

- (void)playWithYoutubeVideoID:(NSString *)videoID {
    [self removePlayerView];
    self.playerView = [self playerViewWithVideoID:videoID];
    [self prepareExitButton];
}

#pragma mark - Helper methods
- (NSString *)youtubeUrlWithVideoID:(NSString *)videoID {
    return [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@", videoID];
}

- (NSString *)videoPlayerHTML:(NSString *)videoID size:(CGSize)size {
    NSString *embedHTML = @"\
    <html><head>\
    <style type=\"text/css\">\
    body {\
    background-color: black;\
    color: white;\
    text-align: center;\
    }\
    </style>\
    </head><body style=\"margin:0\">\
    <embed id=\"yt\" src=\"%@\" type=\"application/x-shockwave-flash\" \
    width=\"%0.0f\" height=\"%0.0f\"></embed>\
    </body></html>";

    NSString *html = [NSString stringWithFormat:embedHTML,
                      [self youtubeUrlWithVideoID:videoID],
                      size.width,
                      size.height];
    return html;
}

- (UIWebView *)playerViewWithVideoID:(NSString *)videoID {
    UIView *containerView = self.containerVC.view;

    CGFloat targetWidth, targetHeight;
    if (containerView.frame.size.width > containerView.frame.size.height) {
        targetHeight = containerView.frame.size.height;
        targetWidth = targetHeight * ASPECT_RATIO;
    } else {
        targetWidth = containerView.frame.size.width;
        targetHeight = targetWidth / ASPECT_RATIO;
    }

    CGRect frame = CGRectMake((containerView.frame.size.width - targetWidth) * 0.5,
                              (containerView.frame.size.height - targetHeight) * 0.5,
                              targetWidth,
                              targetHeight);
    UIWebView *webView = [[UIWebView alloc] initWithFrame:frame];
    [webView loadHTMLString:[self videoPlayerHTML:videoID size:CGSizeMake(targetWidth, targetHeight)] baseURL:nil];
    [containerView addSubview:webView];
    webView.frame = frame;
    return webView;
}

- (void)removePlayerView {
    [self.playerView removeFromSuperview];
}

- (void)prepareExitButton
{
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [cancelButton addTarget:self action:@selector(handleExit) forControlEvents:UIControlEventTouchUpInside];
    [cancelButton setFrame:CGRectMake(0, self.containerVC.topLayoutGuide.length, 64, 64)];
    [cancelButton setTitle:@"X" forState:UIControlStateNormal];
    [cancelButton setTag:WEBVIEW_TAG];

    [self.containerVC.view addSubview:cancelButton];
}

- (void)handleExit
{
    UIView * subview = [self.containerVC.view viewWithTag:WEBVIEW_TAG];
    [subview removeFromSuperview];

    [self removePlayerView];
}

@end
