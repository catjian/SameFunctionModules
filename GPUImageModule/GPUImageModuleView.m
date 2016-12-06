//
//  GPUImageModuleView.m
//  SameFunctionModules
//
//  Created by jian zhang on 2016/12/6.
//  Copyright © 2016年 jian zhang. All rights reserved.
//

#import "GPUImageModuleView.h"

@implementation GPUImageModuleView
{
    GPUImageVideoCamera *m_ViewCamera;
    GPUImageOutput<GPUImageInput> *m_Filter;
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
            return AVAssetExportPreset1280x720;
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



@end
