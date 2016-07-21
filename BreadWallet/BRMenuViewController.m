//
//  BRMenuViewController.m
//  LoafWallet
//
//  Created by Yifei Zhou on 7/21/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

#import "BRMenuViewController.h"

@interface BRMenuViewController () <UITableViewDelegate, UITableViewDataSource>

@property (readonly, nonatomic) NSArray *menuTitles;

@end

@implementation BRMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

#pragma mark - Table View Delegate & DataSources

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 8;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 35.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *menuIdent = @"MenuCell";
    UITableViewCell *cell = nil;
    UILabel *textLabel;
    cell = [tableView dequeueReusableCellWithIdentifier:menuIdent];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:menuIdent];
    }
    
    textLabel = (id)[cell viewWithTag:1];
    textLabel.text = self.menuTitles[indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark -

- (NSArray *)menuTitles
{
    return @[
             @"Import Private Key",
             @"Export Private Key",
             @"Recovery Phrase",
             @"Local Currency",
             @"Change Passcode",
             @"Start / Recover another wallet",
             @"Re-scan Blockchain",
             @"About"
             ];
}

@end
