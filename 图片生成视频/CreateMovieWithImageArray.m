//
//  InsertImageToMovieViewController.m
//  SameFunctionModules
//
//  Created by jian zhang on 2016/12/23.
//  Copyright © 2016年 jian zhang. All rights reserved.
//

#import "CreateMovieWithImageArray.h"
#import <AVFoundation/AVAssetWriter.h>
#import <AVFoundation/AVAssetWriterInput.h>
#import <AVFoundation/AVMediaFormat.h>
#import <AVFoundation/AVVideoSettings.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AssetsLibrary/AssetsLibrary.h>

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
    NSString *fileName = [@"Documents/" stringByAppendingFormat:@"Movie_%d.m4v",(int)[[NSDate date] timeIntervalSince1970]];
    NSString *m_PathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:fileName];
    m_FileUrl = [[NSURL alloc] initWithString:m_PathToMovie];
    [self dismissViewControllerAnimated:YES completion:nil];
    dispatch_async(dispatch_queue_create("", 0), ^{
        [self writeImages:m_ImageArray
            ToMovieAtPath:m_FileUrl.absoluteString
                 withSize:CGSizeMake(320, 480)
               inDuration:10
                    byFPS:24];
    });
}

#pragma mark - Write Image Action

- (void) writeImages:(NSArray *)imagesArray
       ToMovieAtPath:(NSString *)path
            withSize:(CGSize) size
          inDuration:(float)duration
               byFPS:(int32_t)fps
{
    //Wire the writer:
    NSError *error = nil;
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:path]
                                                           fileType:AVFileTypeQuickTimeMovie
                                                              error:&error];
    NSParameterAssert(videoWriter);
    
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:size.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:size.height], AVVideoHeightKey,
                                   nil];
    
    AVAssetWriterInput* videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                              outputSettings:videoSettings];
    
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
                                                     assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput
                                                     sourcePixelBufferAttributes:nil];
    NSParameterAssert(videoWriterInput);
    NSParameterAssert([videoWriter canAddInput:videoWriterInput]);
    [videoWriter addInput:videoWriterInput];
    
    //Start a session:
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    //Write some samples:
    CVPixelBufferRef buffer = NULL;
    
    int frameCount = 0;
    
    NSInteger imagesCount = [imagesArray count];
    float averageTime = duration/imagesCount;
    int averageFrame = (int)(averageTime * fps);
    
    for(UIImage * img in imagesArray)
    {
        buffer = [self pixelBufferFromCGImage:[img CGImage] andSize:size];
        
        BOOL append_ok = NO;
        int j = 0;
        while (!append_ok && j < 30)
        {
            if (adaptor.assetWriterInput.readyForMoreMediaData)
            {
                printf("appending %d attemp %d\n", frameCount, j);
                
                CMTime frameTime = CMTimeMake(frameCount,(int32_t) fps);
                float frameSeconds = CMTimeGetSeconds(frameTime);
                NSLog(@"frameCount:%d,kRecordingFPS:%d,frameSeconds:%f",frameCount,fps,frameSeconds);
                append_ok = [adaptor appendPixelBuffer:buffer withPresentationTime:frameTime];
                
                if(buffer)
                    [NSThread sleepForTimeInterval:0.05];
            }
            else
            {
                printf("adaptor not ready %d, %d\n", frameCount, j);
                [NSThread sleepForTimeInterval:0.1];
            }
            j++;
        }
        if (!append_ok) {
            printf("error appending image %d times %d\n", frameCount, j);
        }
        
        frameCount = frameCount + averageFrame;
    }
    
    //Finish the session:
    [videoWriterInput markAsFinished];
    [videoWriter finishWritingWithCompletionHandler:^{
        NSLog(@"finishWriting");
    }];
}

- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image andSize:(CGSize) size
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size.width,
                                          size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, size.width,
                                                 size.height, 8, 4*size.width, rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

@end
