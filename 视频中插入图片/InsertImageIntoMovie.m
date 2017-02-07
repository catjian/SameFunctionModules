//
//  InsertImageIntoMovie.m
//  SameFunctionModules
//
//  Created by jian zhang on 2016/12/26.
//  Copyright © 2016年 jian zhang. All rights reserved.
//

#import "InsertImageIntoMovie.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVMediaFormat.h>
#import <AVFoundation/AVComposition.h>
#import <AVFoundation/AVVideoComposition.h>
#import <AVFoundation/AVAssetExportSession.h>

@implementation InsertImageIntoMovie
{
    InsertImageIntoMovieSuccessBlock m_Block;
    AVMutableComposition *m_Composition;
    AVMutableVideoComposition *m_VideoComposition;
}

+ (InsertImageIntoMovie *)sharedInsertImageIntoMovie
{
    static InsertImageIntoMovie *objectClass = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        objectClass = [[InsertImageIntoMovie alloc] init];
    });
    return objectClass;
}

- (void)insertIntoMovieWithUrl:(NSURL *)url Image:(UIImage *)image ImageSize:(CGSize)size ImageAlpha:(CGFloat)alpha successBlock:(InsertImageIntoMovieSuccessBlock)block
{
    image = [self changeAlphaOfImageWith:image Alpha:alpha];
    
    [self initAVObjectsWithUrl:url];
    
    CALayer *backGroundLayer = [CALayer layer];
    [backGroundLayer setContents:(id)image.CGImage];
    [backGroundLayer setFrame:CGRectMake(0, 0, size.width, size.height)];
    [backGroundLayer setShadowOpacity:0.5];
    [backGroundLayer setMasksToBounds:YES];
    
    CALayer *parentLayer = [CALayer layer];
    CALayer *videoLayer = [CALayer layer];
    parentLayer.frame = CGRectMake(0, 0, m_VideoComposition.renderSize.width, m_VideoComposition.renderSize.height);
    videoLayer.frame = CGRectMake(0, 0, m_VideoComposition.renderSize.width, m_VideoComposition.renderSize.height);
    [parentLayer addSublayer:videoLayer];
    backGroundLayer.position = CGPointMake(m_VideoComposition.renderSize.width/2, m_VideoComposition.renderSize.height/4);
    [parentLayer addSublayer:backGroundLayer];
    m_VideoComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    
    [self writeCompositionVideoToLoaction];
}


/**
 设置图片的透明度

 @param image 原图片
 @param alpha 透明度
 @return 修改后的图片
 */
- (UIImage *)changeAlphaOfImageWith:(UIImage *)image Alpha:(CGFloat)alpha
{
    UIGraphicsBeginImageContextWithOptions(image.size, NO, 0.0f);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect area = CGRectMake(0, 0, image.size.width, image.size.height);
    
    CGContextScaleCTM(ctx, 1, -1);
    CGContextTranslateCTM(ctx, 0, -area.size.height);
    
    CGContextSetBlendMode(ctx, kCGBlendModeMultiply);
    
    CGContextSetAlpha(ctx, alpha);
    
    CGContextDrawImage(ctx, area, image.CGImage);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();

    return newImage;
}

/**
 初始化AVFoundation 相关视频处理的类对象

 @param url 待处理视频的路径
 */
- (void)initAVObjectsWithUrl:(NSURL *)url
{
    if (!url)
    {
        return;
    }
    //处理视频的官方套路
    //1.创建一个AVMutableComposition对象，添加多个AVMutableCompositionTrack对象
    //2.根据元素类型将时间区间加入到容器
    //3.通过检查视频的preferredTransform对象，来确定视频内容显示的方向。
    //4.使用AVMutableVideoCompositionLayerInstruction对象将转换到视频的内容中
    //5.设置合适的renderSize和frameDuration值来进行视频合成，再对合成后的视频进行导出
    //6.保存导出后的文件
    
    //从指定的视频创建一个AVAsset对象
    AVAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
    AVAssetTrack *assetVideoTrack = nil;
    AVAssetTrack *assetAudioTrack = nil;
    // 检查视频内容是否包含视频元素和音频元素
    if ([[asset tracksWithMediaType:AVMediaTypeVideo] count] != 0) {
        assetVideoTrack = [asset tracksWithMediaType:AVMediaTypeVideo][0];
    }
    if ([[asset tracksWithMediaType:AVMediaTypeAudio] count] != 0) {
        assetAudioTrack = [asset tracksWithMediaType:AVMediaTypeAudio][0];
    }
    //编辑视频的起始位置时间
    CMTime insertionPoint = kCMTimeZero;
    
    m_Composition = [AVMutableComposition composition];
    
    if (assetVideoTrack != nil)
    {
        //创建一个可加载视频的容器
        AVMutableCompositionTrack *compositionVideoTrack = [m_Composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                                      preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration])
                                       ofTrack:assetVideoTrack
                                        atTime:insertionPoint
                                         error:nil];
    }
    if (assetAudioTrack != nil)
    {
        //创建一个可加载音频的容器
        AVMutableCompositionTrack *compositionAudioTrack = [m_Composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                                      preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration])
                                       ofTrack:assetAudioTrack
                                        atTime:insertionPoint
                                         error:nil];
    }
    
    CMTime compositionDuration = m_Composition.duration;
    NSLog(@"%lld,%d,%d,%lld",compositionDuration.value, compositionDuration.timescale, compositionDuration.flags, compositionDuration.epoch);
    
    if ([[m_Composition tracksWithMediaType:AVMediaTypeVideo] count] != 0)
    {
        //创建一个视频操作指令的对象，可设置方向，透明度，剪辑等。
        AVAssetTrack *videoTrack = [m_Composition tracksWithMediaType:AVMediaTypeVideo][0];
        AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        
        //创建一个维护合成视频指令数组的对象，设置对象比较多，这里只设置时间区间。
        AVMutableVideoCompositionInstruction *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        [passThroughInstruction setTimeRange:CMTimeRangeMake(kCMTimeZero, m_Composition.duration)];
        passThroughInstruction.layerInstructions = @[passThroughLayer];
        
        m_VideoComposition = [AVMutableVideoComposition videoComposition];
        m_VideoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
        m_VideoComposition.renderSize = assetVideoTrack.naturalSize;
        m_VideoComposition.instructions = @[passThroughInstruction];
    }
}


/**
 导出并写入相册
 */
- (void)writeCompositionVideoToLoaction
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *outputURL = paths[0];
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtPath:outputURL withIntermediateDirectories:YES attributes:nil error:nil];
    outputURL = [outputURL stringByAppendingPathComponent:@"output.mp4"];
    // Remove Existing File
    [manager removeItemAtPath:outputURL error:nil];
    
    
    // Step 2
    // Create an export session with the composition and write the exported movie to the photo library
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:[m_Composition copy] presetName:AVAssetExportPreset1280x720];
    
    exportSession.videoComposition = m_VideoComposition;
    exportSession.outputURL = [NSURL fileURLWithPath:outputURL];
    exportSession.outputFileType = AVFileTypeQuickTimeMovie;
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^(void){
        switch (exportSession.status) {
            case AVAssetExportSessionStatusCompleted:
                [self writeVideoToPhotoLibrary:[NSURL fileURLWithPath:outputURL]];
                break;
            case AVAssetExportSessionStatusFailed:
                NSLog(@"Failed:%@",exportSession.error);
                break;
            case AVAssetExportSessionStatusCancelled:
                NSLog(@"Canceled:%@",exportSession.error);
                break;
            default:
                break;
        }
    }];
}

- (void)writeVideoToPhotoLibrary:(NSURL *)url
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];    
    [library writeVideoAtPathToSavedPhotosAlbum:url completionBlock:^(NSURL *assetURL, NSError *error){
        if (error)
        {
            NSLog(@"Video could not be saved");
        }
        else
        {
            NSLog(@"Video save success assetURL = %@",assetURL);
            if (m_Block)
            {
                m_Block(assetURL);
            }
        }
    }];
}

@end
