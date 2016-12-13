//
//  GPUImageModuleView.m
//  SameFunctionModules
//
//  Created by jian zhang on 2016/12/6.
//  Copyright © 2016年 jian zhang. All rights reserved.
//

#import "GPUImageModuleView.h"
#import "FilterArray.h"

@interface GPUImageModuleView ()

@property (nonatomic, copy) GPUImageModuleSaveVideoRespose saveBlock;

@end

@implementation GPUImageModuleView
{
    GPUImageVideoCamera *m_ViewCamera;
    GPUImageOutput<GPUImageInput> *m_Filter;
    GPUImageMovieWriter *m_Writer;
    NSString *m_PathToMovie;
    BOOL m_isStartRecord;
}

- (NSString *)GetSessionPreset:(ENUM_SESSION_PRESET)sessionPreset
{
    switch (sessionPreset)
    {
        case ENUM_SESSION_PRESET_3GP:
            return AVCaptureSessionPresetLow;
        case ENUM_SESSION_PRESET_352x288:
            return AVCaptureSessionPreset352x288;
        case ENUM_SESSION_PRESET_640x480:
            return AVCaptureSessionPreset640x480;
        case ENUM_SESSION_PRESET_1280x720:
            return AVCaptureSessionPreset1280x720;
        case ENUM_SESSION_PRESET_1920x1080:
            return AVCaptureSessionPreset1920x1080;
        case ENUM_SESSION_PRESET_3840x2160:
            return AVCaptureSessionPreset3840x2160;
    }
    return AVCaptureSessionPreset640x480;
}

- (instancetype) initWithFrame:(CGRect)frame
                 sessionPreset:(ENUM_SESSION_PRESET)sessionPreset
                cameraPosition:(ENUM_CAMERA_POSITION)cameraPosition
{
    self = [super initWithFrame:frame];
    if (self)
    {
        m_isStartRecord = NO;
        m_ViewCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:[self GetSessionPreset:sessionPreset]
                                                           cameraPosition:(AVCaptureDevicePosition)cameraPosition];
        
        m_ViewCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
        m_ViewCamera.horizontallyMirrorFrontFacingCamera = NO;
        m_ViewCamera.horizontallyMirrorRearFacingCamera = NO;
        if (m_Filter)
        {
            [m_ViewCamera addTarget:m_Filter];
            [m_Filter addTarget:self];
        }
        else
        {
            [m_ViewCamera addTarget:self];
        }
        [m_ViewCamera startCameraCapture];
    }
    return self;
}

- (void)setImageInputFilter:(GPUImageOutput<GPUImageInput> *)filter
{
    if ([m_Filter isEqual:filter] || m_isStartRecord)
    {
        return;
    }
    m_Filter = filter;
    [m_ViewCamera removeAllTargets];
    [m_ViewCamera addTarget:m_Filter];
    [m_Filter addTarget:self];
}

- (void)startAction
{
    m_isStartRecord = YES;
    NSString *fileName = [@"Documents/" stringByAppendingFormat:@"Movie_%d.m4v",(int)[[NSDate date] timeIntervalSince1970]];
    m_PathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:fileName];
    
    NSURL *movieURL = [NSURL fileURLWithPath:m_PathToMovie];
    m_Writer = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(480.0, 640.0)];
    [m_Filter addTarget:m_Writer];
    m_ViewCamera.audioEncodingTarget = m_Writer;
    [m_Writer startRecording];
}

- (void)stopAction
{
    m_isStartRecord = NO;
    [m_Filter removeTarget:m_Writer];
    m_ViewCamera.audioEncodingTarget = nil;
    [m_Writer finishRecording];
}

- (void)saveVideoToLocationWithBlock:(GPUImageModuleSaveVideoRespose)block
{
    self.saveBlock = block;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(m_PathToMovie)) {
            UISaveVideoAtPathToSavedPhotosAlbum(m_PathToMovie, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
        }
    });
}

// 视频保存回调
- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo: (void *)contextInfo
{
    if (self.saveBlock)
    {
        self.saveBlock((error?NO:YES),error);
    }
}

- (NSArray <GPUImageOutput<GPUImageInput> *>*)getFilterArray
{
    return [FilterArray creatFilterArray];
}

@end
