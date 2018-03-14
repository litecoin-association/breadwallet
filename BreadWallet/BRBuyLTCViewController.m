//
//  BRBuyLTCViewController.m
//  LoafWallet
//
//  Created by Litecoin Foundation on 05/05/2017.
//  Copyright © 2017 Litecoin Foundation. All rights reserved.
//

#import "BRBuyLTCViewController.h"
#import "BRWalletManager.h"

@interface BRBuyLTCViewController ()
@property (strong, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation BRBuyLTCViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.tosblock.com"]];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    [_webView loadRequest:urlRequest];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (NSString *)paymentAddress
{
    return [BRWalletManager sharedInstance].wallet.receiveAddress;
}

- (IBAction)backButton:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
