//
//  locationVideoViewController.m
//  SameFunctionModules
//
//  Created by jian zhang on 2016/12/6.
//  Copyright © 2016年 jian zhang. All rights reserved.
//

#import "locationVideoViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "GPUImage.h"
#import "FilterChooseView.h"

#define FilterViewHeight 95

@interface locationVideoViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@end

@implementation locationVideoViewController
{
    GPUImageView *m_FilterView;
    GPUImageMovie *m_ImageMovie;
    GPUImageOutput<GPUImageInput> * m_Filter;
    GPUImageMovieWriter *m_Writer;
    NSURL *m_FileUrl;
    UIButton *m_SaveButton;
    NSString *m_PathToMovie;
}

- (void)viewDidLoad
{
    [super viewDidLoad];    
    
    UIButton *locVideo =[UIButton buttonWithType:UIButtonTypeCustom];
    [locVideo setFrame:CGRectMake(20, 20, self.view.frame.size.width/3, 40)];
    locVideo.layer.borderWidth  = 2;
    locVideo.layer.borderColor = [UIColor blackColor].CGColor;
    [locVideo setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [locVideo setTitle:@"本地视频" forState:UIControlStateNormal];
    [locVideo addTarget:self action:@selector(startLocation) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *rightBarBtn = [[UIBarButtonItem alloc] initWithCustomView:locVideo];
    [self.navigationItem setRightBarButtonItem:rightBarBtn];
    
    m_FilterView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width,
                                                                  self.view.frame.size.height-FilterViewHeight-60)];
    m_FilterView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:m_FilterView];
    
    __weak typeof(self) weakSelf = self;
    FilterChooseView * chooseView = [[FilterChooseView alloc] initWithFrame:CGRectMake(0, m_FilterView.frame.size.height,
                                                                                       self.view.frame.size.width, FilterViewHeight)];
    chooseView.backback = ^(GPUImageOutput<GPUImageInput> * filter){
        [weakSelf setInputFilter:filter];
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

- (void)playLocationVideo
{
    if (m_ImageMovie)
    {
        [m_ImageMovie cancelProcessing];
    }
    m_ImageMovie = [[GPUImageMovie alloc] initWithURL:m_FileUrl];
    if (m_Filter)
    {
        [m_ImageMovie addTarget:m_Filter];
        [m_Filter addTarget:m_FilterView];
    }
    else
    {
        [m_ImageMovie addTarget:m_FilterView];
    }
    [m_ImageMovie startProcessing];
}

#pragma mark - Actions

- (void)setInputFilter:(GPUImageOutput<GPUImageInput> *)filter
{
    m_Filter = filter;
    if (!m_FileUrl)
    {
        return;
    }
    [m_ImageMovie cancelProcessing];
    [m_ImageMovie removeAllTargets];
    [self playLocationVideo];
}

- (void)startLocation
{
    ALAuthorizationStatus authState = [ALAssetsLibrary authorizationStatus];
    if (authState != ALAuthorizationStatusAuthorized)
    {
        UIAlertController *alertCon = [UIAlertController alertControllerWithTitle:@"未开启权限" message:@"是否开启相册权限"
                                                                   preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *alertActionSuc = [UIAlertAction actionWithTitle:@"开启" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL * url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            
            if([[UIApplication sharedApplication] canOpenURL:url])
            {
                NSURL*url =[NSURL URLWithString:UIApplicationOpenSettingsURLString];
                [[UIApplication sharedApplication] openURL:url];
            }
        }];
        [alertCon addAction:alertActionSuc];
        UIAlertAction *alertActionCal = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alertCon addAction:alertActionCal];
        [self presentViewController:alertCon animated:YES completion:nil];
        return;
    }
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum])
    {
        UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
        [imagePicker setDelegate:self];
        [imagePicker setSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
        [imagePicker setMediaTypes:@[(NSString *)kUTTypeMovie]];
        [self presentViewController:imagePicker animated:YES completion:nil];
    }
}

- (void)start_stop
{
    BOOL isSelected = m_SaveButton.isSelected;
    [m_SaveButton setSelected:!isSelected];
    if (isSelected)
    {
        [m_FilterView endProcessing];
        UIAlertController *alertCon = [UIAlertController alertControllerWithTitle:@"是否保存到相册"
                                                                          message:nil
                                                                   preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *alertActionSuc = [UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self saveFilterMovieToLocation];
        }];
        [alertCon addAction:alertActionSuc];
        UIAlertAction *alertActionCal = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alertCon addAction:alertActionCal];
        [self presentViewController:alertCon animated:YES completion:nil];
    }
    else
    {
        [m_ImageMovie startProcessing];
    }
}

- (void)saveFilterMovieToLocation
{
    dispatch_async(dispatch_queue_create("com.LocationGPU.saveToLocation", 0), ^{
        NSString *fileName = [@"Documents/" stringByAppendingFormat:@"Movie_%d.m4v",(int)[[NSDate date] timeIntervalSince1970]];
        m_PathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:fileName];
        
        NSURL *movieURL = [NSURL fileURLWithPath:m_PathToMovie];
        
        AVURLAsset * asss = [AVURLAsset URLAssetWithURL:m_FileUrl options:nil];
        CGSize videoSize = [[[asss tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize];
        m_Writer = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:videoSize];
        if (m_Filter)
        {
            [m_Filter addTarget:m_Writer];
        }
        m_Writer.shouldPassthroughAudio = YES;
        [m_ImageMovie enableSynchronizedEncodingUsingMovieWriter:m_Writer];
        [m_Writer startRecording];
        __weak typeof(self) weakSelf = self;
        [m_Writer setCompletionBlock:^{
            [weakSelf movieRecordingCompleted];
        }];
    });
}

#pragma mark - GPUImageMovieWrite Delegate

- (void)movieRecordingCompleted
{
    NSLog(@"视频合成结束");
    [m_Filter removeTarget:m_Writer];
    [m_Writer finishRecording];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(m_PathToMovie)) {
            UISaveVideoAtPathToSavedPhotosAlbum(m_PathToMovie, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
        }
    });

}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextIn
{
    if (error)
    {
        NSLog(@"保存视频过程中发生错误，错误信息:%@",error.localizedDescription);
    }
    else
    {
        NSLog(@"视频保存成功.");
    }
}

#pragma mark - ImagePicker Delegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    NSString *mediaType=[info objectForKey:UIImagePickerControllerMediaType];
    
    if ([mediaType isEqualToString:(NSString *)kUTTypeMovie])
    {
        m_FileUrl = info[UIImagePickerControllerMediaURL];
        [self dismissViewControllerAnimated:YES completion:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self playLocationVideo];
            });
        }];
    }
}

@end
