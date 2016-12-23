//
//  ViewController.m
//  SameFunctionModules
//
//  Created by jian zhang on 2016/12/6.
//  Copyright © 2016年 jian zhang. All rights reserved.
//

#import "FilterViewController.h"

#import "GPUImageModuleView.h"
#import "FilterChooseView.h"

#define FilterViewHeight 95

@interface FilterViewController () <UIAlertViewDelegate>
@end

@implementation FilterViewController
{
    GPUImageModuleView *m_BaseView;
    UIButton *m_SaveButton;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)loadView
{
    [super loadView];
    
    m_BaseView = [[GPUImageModuleView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width,
                                                                      self.view.frame.size.height-FilterViewHeight-60)
                                             sessionPreset:ENUM_SESSION_PRESET_1280x720
                                            cameraPosition:ENUM_CAMERA_POSITION_Back];
    [self.view addSubview:m_BaseView];
    
    FilterChooseView * chooseView = [[FilterChooseView alloc] initWithFrame:CGRectMake(0, m_BaseView.frame.size.height,
                                                                                       self.view.frame.size.width, FilterViewHeight)];
    chooseView.backback = ^(GPUImageOutput<GPUImageInput> * filter){
        [m_BaseView setImageInputFilter:filter];
    };
    [self.view addSubview:chooseView];
    
    m_SaveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [m_SaveButton setFrame:CGRectMake(0, 0, self.view.frame.size.width/3, 40)];
    m_SaveButton.center = CGPointMake(self.view.frame.size.width/2, self.view.frame.size.height-30);
    m_SaveButton.layer.borderWidth  = 2;
    m_SaveButton.layer.borderColor = [UIColor blackColor].CGColor;
    [m_SaveButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [m_SaveButton setTitle:@"start" forState:UIControlStateNormal];
    [m_SaveButton setTitle:@"stop" forState:UIControlStateSelected];
    [m_SaveButton addTarget:self action:@selector(start_stop) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:m_SaveButton];
}

- (void)start_stop
{
    BOOL isSelected = m_SaveButton.isSelected;
    [m_SaveButton setSelected:!isSelected];
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

@end
