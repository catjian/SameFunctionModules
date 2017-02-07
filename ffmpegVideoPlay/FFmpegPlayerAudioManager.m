//
//  FFmpegPlayerAudioManager.m
//  SameFunctionModules
//
//  Created by jian zhang on 2017/1/6.
//  Copyright © 2017年 jian zhang. All rights reserved.
//

#import "FFmpegPlayerAudioManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>

#define MAX_FRAME_SIZE 4096
#define MAX_CHAN       2

#define MAX_SAMPLE_DUMPED 5

static OSStatus renderCallback (void *inRefCon, AudioUnitRenderActionFlags	*ioActionFlags, const AudioTimeStamp * inTimeStamp, UInt32 inOutputBusNumber, UInt32 inNumberFrames, AudioBufferList* ioData);

@interface FFmpegPlayerAudioManagerImp : FFmpegPlayerAudioManager <FFmpegPlayerAudioManager>
{
    AudioUnit                   _audioUnit;
    AudioStreamBasicDescription _outputFormat;
}

@property (nonatomic) UInt32 numOutputChannels;
@property (nonatomic) Float64 samplingRate;
@property (nonatomic) UInt32 numBytesPerSample;
@property (nonatomic) BOOL isPlaying;
@property (nonatomic, strong) NSString *audioRoute;
@property (nonatomic) NSTimeInterval tickCorrectionTime;
@property (nonatomic) CGFloat playedPostion;

- (BOOL)activateAudioSession;
- (void)deactivateAudioSession;
- (BOOL)play;
- (void)pause:(BOOL)isClear;

- (void)appendAudioFrameModel:(FFmpegAudioFrameModel *)model;

- (BOOL) checkAudioRoute;
- (BOOL) setupAudioSession;
- (BOOL) renderFrames: (UInt32) numFrames
               ioData: (AudioBufferList *) ioData;

@end

static FFmpegPlayerAudioManagerImp *classObject = nil;
static dispatch_once_t onceToken;

@implementation FFmpegPlayerAudioManager

+ (id<FFmpegPlayerAudioManager>)sharedAudioManager
{
    dispatch_once(&onceToken, ^{
        classObject = [[FFmpegPlayerAudioManagerImp alloc] init];
    });
    return classObject;
}

@end

@implementation FFmpegPlayerAudioManagerImp
{
    NSMutableArray *m_FrameArray;
    NSRecursiveLock *m_Lock;
    BOOL m_isBuffered;
    NSData *m_CurrentAudioFrame;
    CGFloat m_MoviePosition;
    NSUInteger m_CurrentAudioFramePos;
    Float32 m_OutputVolume;
    BOOL m_Activated;
}

- (instancetype) init
{
    self = [super init];
    if (self)
    {
        m_Activated = NO;
        m_Lock = [[NSRecursiveLock alloc] init];
        m_OutputVolume = 0.5;
        m_FrameArray = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Private

- (BOOL)checkAudioRoute
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSLog(@"audio Route portName = %@",[session.currentRoute.outputs firstObject].portName);
    NSLog(@"audio Route portType = %@",[session.currentRoute.outputs firstObject].portType);
    NSLog(@"audio Route UID = %@",[session.currentRoute.outputs firstObject].UID);
    _audioRoute = [session.currentRoute.outputs firstObject].portType;
    return YES;
}

- (BOOL)setupAudioSession
{
    [self checkAudioRoute];
    NSError *error= nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategorySoloAmbient
                   error:&error];
    if(error)
    {
        NSLog(@"Error creating session: %@", [error description]);
        return NO;
    }
    
    [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
    if(error)
    {
        NSLog(@"Error creating session: %@", [error description]);
        return NO;
    }
    
    Float32 preferredBufferSize = 0.0232;  // == 1024/44100;
    [session setPreferredIOBufferDuration:preferredBufferSize error:&error];
    if(error)
    {
        NSLog(@"Error creating session: %@", [error description]);
        return NO;
    }
    
    [session setActive:YES error:&error];
    if(error)
    {
        NSLog(@"Error setActive session: %@", [error description]);
        return NO;
    }
    
    NSLog(@"device channels number = %d", session.outputNumberOfChannels);
    _samplingRate = session.sampleRate;
    m_OutputVolume = session.outputVolume;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notificationAudioRouteChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    
    [session addObserver:self forKeyPath:@"outputVolume" options:NSKeyValueObservingOptionNew context:nil];
    
    if(![self setupAudioUnit])
    {
        NSLog(@"Error setupAudioUnit");
        return NO;
    }
    return YES;
}

- (BOOL)setupAudioUnit
{
    OSStatus error;
    AudioComponentDescription description = {0};
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = kAudioUnitSubType_RemoteIO;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    // Get component
    AudioComponent component = AudioComponentFindNext(NULL, &description);
    error = AudioComponentInstanceNew(component, &_audioUnit);
    if (error != noErr)
        return NO;
    
    // Check the output stream format
    UInt32 size;
    size = sizeof(AudioStreamBasicDescription);
    error = AudioUnitGetProperty(_audioUnit,
                                 kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Input,
                                 0,
                                 &_outputFormat,
                                 &size);
    if (error != noErr)
        return NO;
    
    _outputFormat.mSampleRate = _samplingRate;
    error = AudioUnitSetProperty(_audioUnit,
                                 kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Input,
                                 0,
                                 &_outputFormat,
                                 size);
    if (error != noErr)
        return NO;
    
    _numBytesPerSample = _outputFormat.mBitsPerChannel / 8;
    _numOutputChannels = _outputFormat.mChannelsPerFrame;
    
    NSLog(@"Current output bytes per sample: %ld", _numBytesPerSample);
    NSLog(@"Current output num channels: %ld", _numOutputChannels);
    
    // Slap a render callback on the unit
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = renderCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    
    error = AudioUnitSetProperty(_audioUnit,
                                 kAudioUnitProperty_SetRenderCallback,
                                 kAudioUnitScope_Input,
                                 0,
                                 &callbackStruct,
                                 sizeof(callbackStruct));
    if (error != noErr)
        return NO;
    
    error = AudioUnitInitialize(_audioUnit);
    if (error != noErr)
        return NO;
    
    return YES;
}

- (BOOL) renderFrames: (UInt32) numFrames
               ioData: (AudioBufferList *) ioData
{
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer)
    {
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    
    UInt32  framesNum = numFrames;
    if (_isPlaying)
    {
        NSUInteger count = m_FrameArray.count;
        if (count > 0)
        {
//                    @synchronized(m_FrameArray)
            if ([m_Lock tryLock])
            {
                printf("1 Audio   +++++> %d\n", m_FrameArray.count);
                FFmpegAudioFrameModel *frame = m_FrameArray[0];
                CGFloat delta = self.playedPostion - frame.position;
                printf("2 Audio   ++++++++++> %d, self.playedPostion = %f, frame.position = %f\n",
                       m_FrameArray.count, self.playedPostion, frame.position);
                
                if (delta >= -0.1 && count >= 1)
                {
                    [m_FrameArray removeObjectAtIndex:0];
                    printf("3 Audio   ++++++++++> %d, frame.position = %f, frame.duration = %f\n",
                           m_FrameArray.count, frame.position, frame.duration);
                }
                m_CurrentAudioFramePos = 0;
                m_CurrentAudioFrame = frame.samples;
                if (fabs(delta) >= 1)
                {
                    [m_FrameArray removeObjectAtIndex:0];
                    m_CurrentAudioFrame = nil;
                }
            }
            [m_Lock unlock];
            
            if (m_CurrentAudioFrame)
            {
                void *bytes = (Byte *)m_CurrentAudioFrame.bytes + m_CurrentAudioFramePos;
                const NSUInteger bytesLeft = (m_CurrentAudioFrame.length - m_CurrentAudioFramePos);
                const NSUInteger frameSizeOf = _numOutputChannels * sizeof(float);
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                float *outData = (float *)calloc(bytesToCopy, sizeof(float));
                memcpy(outData, bytes, bytesToCopy);
                
                framesNum -= framesToCopy;
                if (framesNum > 0)
                {
                    outData += framesToCopy * _numOutputChannels;
                }
                printf("4 Audio   +++++> framesNum = %ld, framesToCopy= %d\n", framesNum, framesToCopy);
                
                if (bytesToCopy < bytesLeft)
                    m_CurrentAudioFramePos += bytesToCopy;
                else if (m_CurrentAudioFrame != nil)
                {
                    m_CurrentAudioFrame = nil;
                }
            
                // Put the rendered data into the output buffer
                if (_numBytesPerSample == 4) // then we've already got floats
                {
                    float zero = 0.0;
                    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer)
                    {
                        int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
                        
                        for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel)
                        {
                            vDSP_vsadd(outData+iChannel, _numOutputChannels,
                                       &zero, (float *)ioData->mBuffers[iBuffer].mData,
                                       thisNumChannels, numFrames);
                        }
                    }
                }
                else if (_numBytesPerSample == 2) // then we need to convert SInt16 -> Float (and also scale)
                {
                    float scale = (float)INT16_MAX;
                    vDSP_vsmul(outData, 1, &scale, outData, 1, numFrames*_numOutputChannels);
                    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer)
                    {
                        int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
                        for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel)
                        {
                            vDSP_vfix16(outData+iChannel, _numOutputChannels,
                                        (SInt16 *)ioData->mBuffers[iBuffer].mData+iChannel,
                                        thisNumChannels, numFrames);
                        }
                    }
                }
                free(outData);
                outData = nil;
            }
        }
    }
    return noErr;
}

#pragma mark - property listener audio change

- (void)notificationAudioRouteChange:(NSNotification *)notify
{
    NSLog(@"notificationAudioRouteChange = %@", notify);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"outputVolume"])
    {
        NSLog(@"volume = %f", [AVAudioSession sharedInstance].outputVolume);
    }
}

#pragma mark - public

- (BOOL)activateAudioSession
{
    if (!m_Activated)
    {
        m_Activated = [self setupAudioSession];
    }
    return m_Activated;
}

- (void)deactivateAudioSession
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    AudioUnitUninitialize(_audioUnit);
    AudioComponentInstanceDispose(_audioUnit);
    onceToken = 0;
    classObject = nil;
}

- (BOOL)play
{
    if (!_isPlaying)
    {        
        if ([self activateAudioSession])
        {
            _isPlaying = YES;
            OSStatus error = AudioOutputUnitStart(_audioUnit);
            if (error != noErr)
                _isPlaying = NO;
        }
    }
    
    return _isPlaying;
}

- (void)pause:(BOOL)isClear
{
    if (_isPlaying)
    {
        AudioOutputUnitStop(_audioUnit);
        _isPlaying = NO;
    }
    if (isClear)
    {
        if ([m_Lock tryLock])
        {
            [m_FrameArray removeAllObjects];
        }
        [m_Lock unlock];
    }
}

- (void)appendAudioFrameModel:(FFmpegAudioFrameModel *)model
{
    m_isBuffered = NO;
//    @synchronized(m_FrameArray)
    if ([m_Lock tryLock])
    {
        [m_FrameArray addObject:model];
    }
    [m_Lock unlock];
}

@end

static OSStatus renderCallback (void						*inRefCon,
                                AudioUnitRenderActionFlags	* ioActionFlags,
                                const AudioTimeStamp 		* inTimeStamp,
                                UInt32						inOutputBusNumber,
                                UInt32						inNumberFrames,
                                AudioBufferList				* ioData)
{
    printf("\n0 Audio   +++++> %ld\n", inNumberFrames);
    FFmpegPlayerAudioManagerImp *sm = (__bridge FFmpegPlayerAudioManagerImp *)inRefCon;
    OSStatus error = [sm renderFrames:inNumberFrames ioData:ioData];
    return error;
}
