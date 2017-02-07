//
//  RootViewController.m
//  SameFunctionModules
//
//  Created by jian zhang on 2016/12/23.
//  Copyright © 2016年 jian zhang. All rights reserved.
//

#import "RootViewController.h"

#define DIF_RootTableViewDataSource @[@"镜头滤镜",@"本地视频滤镜", @"图片生成视频",@"视频中插入图片",@"视频解码"]
#define DIF_ViewControllerNames     @[@"FilterViewController", @"locationVideoViewController",\
                                        @"CreateMovieWithImageArray", @"InsertImageToMovieViewController",\
                                        @"FFmpegPlayerController"]

@interface RootViewController () <UITableViewDelegate, UITableViewDataSource>

@end

@implementation RootViewController
{
    UITableView *m_TableView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)loadView
{
    [super loadView];
    m_TableView = [[UITableView alloc] initWithFrame:self.view.frame style:UITableViewStylePlain];
    [m_TableView setDataSource:self];
    [m_TableView setDelegate:self];
    [self.view addSubview:m_TableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return DIF_RootTableViewDataSource.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifer = @"CELLIDENTIFIER";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifer];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifer];
    }
    [cell.textLabel setText:DIF_RootTableViewDataSource[indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    Class vclass = NSClassFromString(DIF_ViewControllerNames[indexPath.row]);
    UIViewController *viewCon = (UIViewController *)[[vclass alloc] init];
    [self.navigationController pushViewController:viewCon animated:YES];
}

@end
