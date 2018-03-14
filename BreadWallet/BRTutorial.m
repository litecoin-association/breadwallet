//
//  BRTutorial.m
//  LoafWallet
//
//  Created by Sun Peng on 16/7/3.
//  Copyright © 2016年 Aaron Voisine. All rights reserved.
//

#import "BRTutorial.h"
#import <MediaPlayer/MediaPlayer.h>

@interface BRTutorial()

@property (nonatomic, strong) MPMoviePlayerViewController *moviePlayer;
@property (nonatomic, weak) UIViewController *containerVC;

@end

@implementation BRTutorial

- (instancetype)initWithViewController:(UIViewController *)vc {
    if (self = [super init]) {
        self.containerVC = vc;
    }

    return self;
}

- (void)playTutorial:(NSString *)tutorialName {
    NSString *tutorialFilePath = [[NSBundle mainBundle] pathForResource:tutorialName ofType:@"mp4"];
    NSURL *url = [NSURL fileURLWithPath:tutorialFilePath];
    self.moviePlayer = [[MPMoviePlayerViewController alloc] initWithContentURL:url];

    [self.containerVC presentViewController:self.moviePlayer animated:YES completion:nil];

    [self.moviePlayer.moviePlayer prepareToPlay];
    [self.moviePlayer.moviePlayer play];
}

//- (void)onFinishPlay {
//    [self.moviePlayer stop];
//    [self.moviePlayer.view removeFromSuperview];
//    self.moviePlayer = nil;
//}

@end
