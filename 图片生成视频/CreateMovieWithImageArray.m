//
//  InsertImageToMovieViewController.m
//  SameFunctionModules
//
//  Created by jian zhang on 2016/12/23.
//  Copyright © 2016年 jian zhang. All rights reserved.
//

#import "CreateMovieWithImageArray.h"
#import "ImageArrayBuildMovie.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface CreateMovieWithImageArray () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@end

@implementation CreateMovieWithImageArray
{
    NSURL *m_FileUrl;
    NSMutableArray *m_ImageArray;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    m_ImageArray = [NSMutableArray array];
    
    
    UIButton *locVideo =[UIButton buttonWithType:UIButtonTypeCustom];
    [locVideo setFrame:CGRectMake(20, 20, self.view.frame.size.width/3, 40)];
    locVideo.layer.borderWidth  = 2;
    locVideo.layer.borderColor = [UIColor blackColor].CGColor;
    [locVideo setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [locVideo setTitle:@"本地视频" forState:UIControlStateNormal];
    [locVideo addTarget:self action:@selector(startLocation) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *rightBarBtn = [[UIBarButtonItem alloc] initWithCustomView:locVideo];
    [self.navigationItem setRightBarButtonItem:rightBarBtn];
    

}

#pragma mark - actions
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
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
    {
        UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
        [imagePicker setDelegate:self];
        [imagePicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
//        [imagePicker setMediaTypes:@[(NSString *)kUTTypeMovie, (NSString *)kUTTypeImage]];
        [self presentViewController:imagePicker animated:YES completion:nil];
    }
}

#pragma mark - ImagePicker Delegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    
    if ([mediaType isEqualToString:(NSString *)kUTTypeMovie])
    {
        m_FileUrl = info[UIImagePickerControllerMediaURL];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    else
    {
        UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
        [m_ImageArray addObject:image];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
    dispatch_async(dispatch_queue_create("com.ImageArrayBuildMovie.thread", 0), ^{
        [[ImageArrayBuildMovie sharedImageArrayBuildMovie] BuildMovieWithImages:m_ImageArray
                                                                      videoSize:CGSizeMake(320, 480)
                                                                  videoDuration:10
                                                                   successBlock:^(NSURL *assetURL) {
                                                                      
                                                                  }];
    });
}

@end
