//
//  ViewController.m
//  SameFunctionModules
//
//  Created by jian zhang on 2016/12/6.
//  Copyright © 2016年 jian zhang. All rights reserved.
//

#import "ViewController.h"

#import "GPUImageModuleView.h"
#import "FilterChooseView.h"

#define FilterViewHeight 95

@interface ViewController () <UIAlertViewDelegate>

@property (nonatomic,retain) UIButton *movieButton;
@end

@implementation ViewController
{
    GPUImageModuleView *m_BaseView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)loadView
{
    [super loadView];
    
    UIButton *locVideo =[UIButton buttonWithType:UIButtonTypeCustom];
    [locVideo setFrame:CGRectMake(20, 20, self.view.frame.size.width/3, 40)];
    locVideo.layer.borderWidth  = 2;
    locVideo.layer.borderColor = [UIColor blackColor].CGColor;
    [locVideo setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [locVideo setTitle:@"本地视频" forState:UIControlStateNormal];
    [locVideo addTarget:self action:@selector(startLocation) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:locVideo];
    
    m_BaseView = [[GPUImageModuleView alloc] initWithFrame:CGRectMake(0, 100, self.view.frame.size.width, 300)
                                             sessionPreset:ENUM_SESSION_PRESET_1280x720
                                            cameraPosition:ENUM_CAMERA_POSITION_Back];
    [self.view addSubview:m_BaseView];
    
    FilterChooseView * chooseView = [[FilterChooseView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height-FilterViewHeight-60, self.view.frame.size.width, FilterViewHeight)];
    chooseView.backback = ^(GPUImageOutput<GPUImageInput> * filter){
        [m_BaseView setImageInputFilter:filter];
    };
    [self.view addSubview:chooseView];
    
    self.movieButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.movieButton setFrame:CGRectMake(0, 0, self.view.frame.size.width/3, 40)];
    self.movieButton.center = CGPointMake(self.view.frame.size.width/2, self.view.frame.size.height-30);
    self.movieButton.layer.borderWidth  = 2;
    self.movieButton.layer.borderColor = [UIColor blackColor].CGColor;
    [self.movieButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.movieButton setTitle:@"start" forState:UIControlStateNormal];
    [self.movieButton setTitle:@"stop" forState:UIControlStateSelected];
    [self.movieButton addTarget:self action:@selector(start_stop) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.movieButton];
}

- (void)start_stop
{
    BOOL isSelected = self.movieButton.isSelected;
    [self.movieButton setSelected:!isSelected];
    if (isSelected)
    {
        [m_BaseView stopAction];
        UIAlertView * alertview = [[UIAlertView alloc] initWithTitle:@"是否保存到相册" message:nil delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"保存", nil];
        [alertview show];
    }
    else
    {
        [m_BaseView startAction];
    }
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1)
    {
        NSLog(@"baocun");
        [m_BaseView saveVideoToLocationWithBlock:^(BOOL isSuccess, NSError *error) {
            if (error)
            {
                NSLog(@"保存视频过程中发生错误，错误信息:%@",error.localizedDescription);
            }
            else
            {
                NSLog(@"视频保存成功.");
            }
        }];
    }
}


- (void)startLocation
{
    
}

@end
