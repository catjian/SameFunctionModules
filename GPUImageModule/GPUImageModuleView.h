//
//  GPUImageModuleView.h
//  SameFunctionModules
//
//  Created by jian zhang on 2016/12/6.
//  Copyright © 2016年 jian zhang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureSession.h>

#import "GPUImage.h"

typedef NS_ENUM(NSUInteger, ENUM_SESSION_PRESET) {
    ENUM_SESSION_PRESET_3GP,
    ENUM_SESSION_PRESET_352x288,
    ENUM_SESSION_PRESET_640x480,
    ENUM_SESSION_PRESET_1280x720,
    ENUM_SESSION_PRESET_1920x1080,
    ENUM_SESSION_PRESET_3840x2160,
};

typedef NS_ENUM(NSInteger, ENUM_CAMERA_POSITION) {
    ENUM_CAMERA_POSITION_Unspecified = AVCaptureDevicePositionUnspecified,
    ENUM_CAMERA_POSITION_Back = AVCaptureDevicePositionBack,
    ENUM_CAMERA_POSITION_Front = AVCaptureDevicePositionFront,
};

typedef void(^GPUImageModuleSaveVideoRespose)(BOOL isSuccess, NSError *error);

@interface GPUImageModuleView : GPUImageView

- (instancetype) initWithFrame:(CGRect)frame
                 sessionPreset:(ENUM_SESSION_PRESET)sessionPreset
                cameraPosition:(ENUM_CAMERA_POSITION)cameraPosition;

- (void)setImageInputFilter:(GPUImageOutput<GPUImageInput> *)filter;

- (void)startAction;

- (void)stopAction;

- (void)saveVideoToLocationWithBlock:(GPUImageModuleSaveVideoRespose)block;

- (NSArray <GPUImageOutput<GPUImageInput> *>*)getFilterArray;
@end
