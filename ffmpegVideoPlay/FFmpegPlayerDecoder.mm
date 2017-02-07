//
//  FFmpegPlayerDecoder.m
//  SameFunctionModules
//
//  Created by jian zhang on 2017/1/3.
//  Copyright © 2017年 jian zhang. All rights reserved.
//

#import "FFmpegPlayerDecoder.h"
#import <stdio.h>
#import <Accelerate/Accelerate.h>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>
#include <libswresample/swresample.h>
}

@interface FFmpegPlayerDecoder ()
{
    float _position;
}

@end

@implementation FFmpegPlayerDecoder
{
    AVCodec *m_Codec;
    AVFormatContext *m_FormatCtx;
    AVCodecContext *m_CodecCtxOrig;
    AVCodecContext *m_CodecCtx;
    AVFrame *m_Frame;
    AVFrame *m_FrameRGB;
    AVFrame *m_FrameYUV;
    int m_VideoStream;
    float m_VideoTimeBase;
    
    AVCodec *m_AudioCodec;
    AVCodecContext *m_AudioCodecCtx;
    AVFrame *m_AudioFrame;
    SwrContext *m_SwrContext;
    void *m_SwrBuffer;
    NSUInteger m_SwrBufferSize;
    int m_AudioStream;
    float m_AudioTimeBase;
    
    NSString *m_FilePath;
    
    BOOL m_IsNetWork;
}
@dynamic position;

static BOOL isNetworkPath (NSString *path)
{
    NSRange r = [path rangeOfString:@"://"];
    if (r.location == NSNotFound)
        return NO;
    NSString *scheme = [path substringToIndex:r.length];
    if ([scheme isEqualToString:@"file"])
        return NO;
    return YES;
}

- (void)FFmpegDecodeWithFilePath:(NSString *)path
{
    m_FilePath = path;
    [self openInputWithPath:path];
    
    [self findStreamInfoWithPath:path];
    
    if (self.getVideoInfoBlock)
    {
        self.getVideoInfoBlock(YES);
    }
    
    [self codecFindDecoder];
    
    [self codecAllocContext3];
    
    [self codecOpen2];
    
    [self allocPicturefillArrays];
    
    [self DecodeFromStream:1];
}

#pragma mark - 打开视频文件
- (BOOL)openInputWithPath:(NSString *)path
{
    m_IsNetWork = isNetworkPath(path);
    
    char *filePath = (char *)[path UTF8String];
    av_register_all();
    if (m_IsNetWork)
    {
        avformat_network_init();
    }
    
    if (avformat_open_input(&m_FormatCtx, filePath, NULL, NULL) != 0)
    {
        NSLog(@"打开文件失败");
        return NO;
    }
    return YES;
}

#pragma mark - 查找流中的数据通道
- (BOOL)findStreamInfoWithPath:(NSString *)path
{
    if (avformat_find_stream_info(m_FormatCtx, NULL) < 0)
    {
        NSLog(@"检查数据流失败");
        return NO;
    }
    if (![self findVideoStreamWithPath:path])
    {
        return NO;
    }
    if (![self findAudioStreamWithPath:path])
    {
        return NO;
    }
    return YES;
}

//查找视频流
- (BOOL)findVideoStreamWithPath:(NSString *)path
{
    m_VideoStream = -1;
    // 根据数据流,找到第一个视频流
    if ((m_VideoStream =  av_find_best_stream(m_FormatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &m_Codec, 0)) < 0)
    {
        NSLog(@"没有找到第一个视频流");
        return NO;
    }
    // 获取视频流的编解码上下文的指针
    m_CodecCtx = avcodec_alloc_context3(NULL);
    if (m_CodecCtx == NULL)
    {
        NSLog(@"Could not allocate Video AVCodecContext\n");
        return NO;
    }
    avcodec_parameters_to_context(m_CodecCtx, m_FormatCtx->streams[m_VideoStream]->codecpar);
    
    AVStream *st = m_FormatCtx->streams[m_VideoStream];
    avStreamFPSTimeBase(st, m_CodecCtx, 0.04, &_videoFPS, &m_VideoTimeBase);
    
    // 打印视频流的详细信息
    char *filePath = (char *)[path UTF8String];
    av_dump_format(m_FormatCtx, 0, filePath, 0);
    
    
    if (!m_FormatCtx)
        _duration = 0;
    else if (m_FormatCtx->duration == AV_NOPTS_VALUE)
        _duration = 0;
    if (m_FormatCtx)
        _duration = (float)m_FormatCtx->duration / AV_TIME_BASE;
    
    return YES;
}

//查找音频流
- (BOOL)findAudioStreamWithPath:(NSString *)path
{
    m_AudioStream = -1;
    if ((m_AudioStream = av_find_best_stream(m_FormatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, &m_Codec, 0)) < 0)
    {
        NSLog(@"没有找到第一个音频流");
        return NO;
    }
    // 获取视频流的编解码上下文的指针
    m_AudioCodecCtx = avcodec_alloc_context3(NULL);
    if (m_AudioCodecCtx == NULL)
    {
        NSLog(@"Could not allocate Audio AVCodecContext\n");
        return NO;
    }
    avcodec_parameters_to_context(m_AudioCodecCtx, m_FormatCtx->streams[m_AudioStream]->codecpar);
    
    AVStream *st = m_FormatCtx->streams[m_AudioStream];
    avStreamFPSTimeBase(st, m_AudioCodecCtx, 0.025, 0, &m_AudioTimeBase);
    return YES;
}

#pragma mark - 根据通道查找对应的编码
- (BOOL)codecFindDecoder
{
    if (![self codecFindVideoDecoder])
    {
        return NO;
    }
    if (m_AudioStream >0 && ![self codecFindAudioDecoder])
    {
        m_AudioStream = -1;
        return NO;
    }
    return YES;
}

- (BOOL)codecFindVideoDecoder
{
    m_Codec = avcodec_find_decoder(m_CodecCtx->codec_id);
    if (m_Codec == NULL)
    {
        NSLog(@"没有找到解码器");
        return NO;
    }
    return YES;
}

- (BOOL)codecFindAudioDecoder
{
    m_AudioCodec = avcodec_find_decoder(m_AudioCodecCtx->codec_id);
    if (m_AudioCodec == NULL)
    {
        NSLog(@"没有找到解码器");
        return NO;
    }
    return YES;
}

#pragma mark - 根据编码填充默认值
- (BOOL)codecAllocContext3
{
    m_CodecCtxOrig = avcodec_alloc_context3(m_Codec);
    AVCodecParameters *pCodePar = avcodec_parameters_alloc();
    if (avcodec_parameters_from_context(pCodePar, m_CodecCtx) < 0)
    {
        NSLog(@"From 复制 codec 内容失败 ");
        return NO;
    }
    if (avcodec_parameters_to_context(m_CodecCtxOrig, pCodePar) < 0)
    {
        NSLog(@"To 复制 codec 内容失败");
        return NO;
    }
    return YES;
}

#pragma mark - 根据编码初始化内容
- (BOOL)codecOpen2
{
    if (![self codecVideoOpen2])
    {
        return NO;
    }
    if (m_AudioStream > 0 && ![self codecAudioOpen2])
    {
        m_AudioStream = -1;
        return NO;
    }
    return YES;
}

- (BOOL)codecVideoOpen2
{
    if (avcodec_open2(m_CodecCtx, m_Codec, NULL) < 0)
    {
        NSLog(@"打开解码器失败");
        return NO;
    }
    return YES;
}

- (BOOL)codecAudioOpen2
{
    if (avcodec_open2(m_AudioCodecCtx, m_AudioCodec, NULL) < 0)
    {
        NSLog(@"打开解码器失败");
        return NO;
    }
    return YES;
}

#pragma mark - 初始化帧容器
- (BOOL)allocPicturefillArrays
{
    if (![self allocVideoPicturefillArrays])
    {
        return NO;
    }
    if (m_AudioStream >0 && ![self allocAudiofillArrays])
    {
        m_AudioStream = -1;
        return NO;
    }
    return YES;
}

- (BOOL)allocVideoPicturefillArrays
{
    m_Frame = av_frame_alloc();
    m_FrameRGB = av_frame_alloc();
    if (m_Frame == NULL || m_FrameRGB == NULL)
    {
        NSLog(@"初始化video帧容器失败");
        return NO;
    }
    
    uint8_t *buffer = NULL;
    int numBytes;
    numBytes = av_image_get_buffer_size(AV_PIX_FMT_RGB24, self.frameWidth, self.frameHeight,1);
    buffer = (uint8_t *)av_malloc(numBytes*sizeof(uint8_t));
    avpicture_fill((AVPicture *)m_FrameRGB, buffer, AV_PIX_FMT_RGB24, self.frameWidth, self.frameHeight);
    av_free(buffer);
    return YES;
}

- (BOOL)allocAudiofillArrays
{
    BOOL isSupport = NO;
    m_SwrContext = NULL;
    id<FFmpegPlayerAudioManager>  m_AudioManager = [FFmpegPlayerAudioManager sharedAudioManager];
    if (m_AudioCodecCtx->sample_fmt == AV_SAMPLE_FMT_S16)
    {
        isSupport = (m_AudioManager.samplingRate == m_AudioCodecCtx->sample_rate &&
                     m_AudioManager.numOutputChannels == m_AudioCodecCtx->channels);
    }
    if (!isSupport)
    {
        m_SwrContext = swr_alloc_set_opts(NULL,
                                          av_get_default_channel_layout(m_AudioManager.numOutputChannels),
                                          AV_SAMPLE_FMT_S16,
                                          m_AudioManager.samplingRate,
                                          av_get_default_channel_layout(m_AudioCodecCtx->channels),
                                          m_AudioCodecCtx->sample_fmt,
                                          m_AudioCodecCtx->sample_rate,
                                          0,
                                          NULL);
        
        if (!m_SwrContext || swr_init(m_SwrContext))
        {
            if (m_SwrContext)
            {
                swr_free(&m_SwrContext);
            }
            avcodec_close(m_AudioCodecCtx);
            NSLog(@"初始化audio帧容器失败");
            return NO;
        }
    }
    m_AudioFrame = av_frame_alloc();
    if (m_AudioFrame == NULL)
    {
        NSLog(@"初始化audio帧容器失败");
        return NO;
    }
    return YES;
}

- (void)deallocParameter
{
    //释放RGB image
//    av_free(m_FrameRGB);
    //释放YUV frame
//    av_free(m_Frame);
    
    avcodec_close(m_CodecCtx);
    avcodec_close(m_CodecCtxOrig);
    
    avformat_close_input(&m_FormatCtx);
}

#pragma mark - class parameter

- (int)frameWidth
{
    return m_CodecCtx?m_CodecCtx->width:0;
}

- (int)frameHeight
{
    return m_CodecCtx?m_CodecCtx->height:0;
}

- (float)duration
{
    return _duration;
}

- (float)position
{
    return _position;
}

- (void)setPosition:(float)seconds
{
    _position = seconds;
	   
    if (m_VideoStream != -1)
    {
        int64_t ts = (int64_t)(seconds / m_VideoTimeBase);
        if (ts == 0 && m_FormatCtx == NULL)
        {
            [self FFmpegDecodeWithFilePath:m_FilePath];
        }
        else if (m_FormatCtx != NULL)
        {
            avformat_seek_file(m_FormatCtx, m_VideoStream, ts, ts, ts, AVSEEK_FLAG_FRAME);
            avcodec_flush_buffers(m_CodecCtx);
            if (m_AudioStream != -1)
            {
                int64_t ts = (int64_t)(seconds / m_AudioTimeBase);
                avformat_seek_file(m_FormatCtx, m_AudioStream, ts, ts, ts, AVSEEK_FLAG_FRAME);
                avcodec_flush_buffers(m_AudioCodecCtx);
            }
        }
    }
}

#pragma mark - Decode Video Stream

- (void)DecodeFromStream:(CGFloat)minDuration
{
    AVPacket packet;    //保存的是解码前的数据，也就是压缩后的数据。该结构本身不直接包含数据，其有一个指向数据域的指针。
    int ret;
    CGFloat decodedDuration = 0;
    BOOL finished = NO;
    while (!finished)
    {
        if(!m_FormatCtx || av_read_frame(m_FormatCtx, &packet) < 0)
        {
            [self deallocParameter];
            return ;
        }
        //判断数据包是否来自视频流
        if (packet.stream_index == m_VideoStream)
        {
            ret = avcodec_send_packet(m_CodecCtx, &packet);
            if(ret < 0 && ret != AVERROR(EAGAIN) && ret != AVERROR_EOF)
            {
                NSLog(@"Decode Video Error send packet.\n");
                continue;
            }
            ret = avcodec_receive_frame(m_CodecCtx, m_Frame); //这里的m_Frame就是解码出来的AVFrame
            if(ret < 0 && ret != AVERROR_EOF)
            {
                NSLog(@"Decode Video Error receive frame.\n");
                continue;
            }
            decodedDuration += [self handleVideoFrame];
            if (decodedDuration > minDuration)
                finished = YES;
        }
        else if (packet.stream_index == m_AudioStream)
        {
            ret = avcodec_send_packet(m_AudioCodecCtx, &packet);
            if(ret < 0 && ret != AVERROR(EAGAIN) && ret != AVERROR_EOF)
            {
                NSLog(@"Decode Audio Error send packet.\n");
                continue;
            }
            ret = avcodec_receive_frame(m_AudioCodecCtx, m_AudioFrame); //这里的m_Frame就是解码出来的AVFrame
            if(ret < 0 && ret != AVERROR_EOF)
            {
                NSLog(@"Decode Audio Error receive frame.\n");
                continue;
            }
            decodedDuration += [self handleAudioFrame];
            if (decodedDuration > minDuration)
                finished = YES;
        }
        av_packet_unref(&packet);
    }
}

static void copyFrameData(UInt8 *src, int linesize, int width, int height, NSData **outData)
{
    width = MIN(linesize, width);
    NSMutableData *md = [NSMutableData dataWithLength: width * height];
    Byte *dst = (Byte *)md.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i) {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    *outData = md;
    md = nil;
}

- (CGFloat)handleVideoFrame
{
    if (!m_Frame->data[0])
        return 0;
    
    FFmpegFrameModel *frameModel;
    if (/* DISABLES CODE */ (1))
    {
        FFmpegVideoFrameModelYUV * yuvFrameModel = [[FFmpegVideoFrameModelYUV alloc] init];
        NSData * data = nil;
        copyFrameData(m_Frame->data[0],
                      m_Frame->linesize[0],
                      self.frameWidth,
                      self.frameHeight,
                      &data);
        yuvFrameModel.luma = data;
        data = nil;
        copyFrameData(m_Frame->data[1],
                      m_Frame->linesize[1],
                      self.frameWidth/2,
                      self.frameHeight/2,
                      &data);
        yuvFrameModel.chromaB = data;
        data = nil;
        copyFrameData(m_Frame->data[2],
                      m_Frame->linesize[2],
                      self.frameWidth/2,
                      self.frameHeight/2,
                      &data);
        yuvFrameModel.chromaR = data;
        data = nil;
        frameModel = yuvFrameModel;
    }
    else
    {
        struct SwsContext *sws_ctx = sws_getContext(self.frameWidth,
                                                    self.frameHeight,
                                                    m_CodecCtx->pix_fmt,
                                                    self.frameWidth,
                                                    self.frameHeight,
                                                    AV_PIX_FMT_RGB24,
                                                    SWS_BILINEAR, NULL, NULL, NULL);
        //转换图像格式为RGB
        sws_scale(sws_ctx, (uint8_t const* const*)m_Frame->data, m_Frame->linesize, 0, self.frameHeight, m_FrameRGB->data, m_FrameRGB->linesize);
        sws_freeContext(sws_ctx);
            
        FFmpegVideoFrameModelRGB *rgbFrameModel = [[FFmpegVideoFrameModelRGB alloc] init];
        rgbFrameModel.linesize = m_FrameRGB->linesize[0];
        NSData *data = [NSData dataWithBytes:m_FrameRGB->data[0] length:rgbFrameModel.linesize*m_CodecCtx->height];
        rgbFrameModel.rgb = data;
        data = nil;
        UInt8 * rgbdata = (UInt8 *)malloc(sizeof(UInt8) * rgbFrameModel.linesize*m_CodecCtx->height);
        memcpy(rgbdata, m_FrameRGB->data[0], rgbFrameModel.linesize*m_CodecCtx->height);
        
//        rgbFrameModel.rgbData = (UInt8 *)malloc(sizeof(UInt8) * rgbFrameModel.linesize*m_CodecCtx->height);
        memcpy(rgbFrameModel.rgbData, rgbdata, rgbFrameModel.linesize*m_CodecCtx->height);
        frameModel = rgbFrameModel;
        free(rgbdata);
    }
    frameModel.type = FFmpegFrameTypeVideo;
    frameModel.width = self.frameWidth;
    frameModel.height = self.frameHeight;
    frameModel.position = av_frame_get_best_effort_timestamp(m_Frame)*m_VideoTimeBase;
    const int64_t frameDuration = av_frame_get_pkt_duration(m_Frame);
    if (frameDuration)
    {
        frameModel.duration = frameDuration * m_VideoTimeBase;
        frameModel.duration += m_Frame->repeat_pict * m_VideoTimeBase * 0.5;
    }
    else
    {
        // sometimes, ffmpeg unable to determine a frame duration
        // as example yuvj420p stream from web camera
        frameModel.duration = 1.0 / _videoFPS;
    }
    _position = frameModel.position;
    
    if (self.decodeVideoBlock)
    {
        self.decodeVideoBlock(frameModel);
    }
    return frameModel.duration;
}

- (CGFloat) handleAudioFrame
{
    if (!m_AudioFrame->data[0])
        return 0;
    
    id<FFmpegPlayerAudioManager> m_AudioManager = [FFmpegPlayerAudioManager sharedAudioManager];
    const NSUInteger numChannels = m_AudioManager.numOutputChannels;
    NSInteger numFrames;
    void *audioData;
    if (m_SwrContext)
    {
        const NSUInteger ratio = MAX(1, m_AudioManager.samplingRate / m_AudioCodecCtx->sample_rate) *
        MAX(1, m_AudioManager.numOutputChannels / m_AudioCodecCtx->channels) * 2;
        const int bufSize = av_samples_get_buffer_size(NULL,
                                                       m_AudioManager.numOutputChannels,
                                                       m_AudioFrame->nb_samples * ratio,
                                                       AV_SAMPLE_FMT_S16,
                                                       1);
        if (!m_SwrBuffer || m_SwrBufferSize < bufSize)
        {
            m_SwrBufferSize = bufSize;
            m_SwrBuffer = realloc(m_SwrBuffer, m_SwrBufferSize);
        }
        Byte *outbuf[2] = { (Byte *)m_SwrBuffer, 0 };
        numFrames = swr_convert(m_SwrContext,
                                outbuf,
                                m_AudioFrame->nb_samples * ratio,
                                (const uint8_t **)m_AudioFrame->data,
                                m_AudioFrame->nb_samples);
        if (numFrames < 0)
        {
            NSLog( @"fail resample audio");
            return 0;
        }
        audioData = m_SwrBuffer;
    }
    else
    {
        if (m_AudioCodecCtx->sample_fmt != AV_SAMPLE_FMT_S16)
        {
            NSLog(@"bucheck, audio format is invalid");
            return 0;
        }
        audioData = m_AudioFrame->data[0];
        numFrames = m_AudioFrame->nb_samples;
    }
    
    const NSUInteger numElements = numFrames * numChannels;
    NSMutableData *data = [NSMutableData dataWithLength:numElements * sizeof(float)];
    vDSP_vflt16((SInt16 *)audioData, 1, (Float32 *)data.mutableBytes, 1, numElements);
    float scale = 1.0 / (float)INT16_MAX ;
    vDSP_vsmul((Float32 *)data.mutableBytes, 1, &scale, (Float32 *)data.mutableBytes, 1, numElements);
    
    __block FFmpegAudioFrameModel *frame = [[FFmpegAudioFrameModel alloc] init];
    frame.position = av_frame_get_best_effort_timestamp(m_AudioFrame) * m_AudioTimeBase;
    frame.duration = av_frame_get_pkt_duration(m_AudioFrame) * m_AudioTimeBase;
    frame.samples = data;
    data = nil;
    frame.type = FFmpegFrameTypeAudio;
    
    if (frame.duration == 0)
    {
        // sometimes ffmpeg can't determine the duration of audio frame
        // especially of wma/wmv format
        // so in this case must compute duration
        frame.duration = frame.samples.length / (sizeof(float) * numChannels * m_AudioManager.samplingRate);
    }
    _position = frame.position;
    
    if (self.decodeAudioBlock)
    {
        self.decodeAudioBlock(frame);
    }
    return frame.duration;
}
/*
#pragma mark - Save Decode Video Stream

- (void)SaveFrameFromStream
{
    struct SwsContext *sws_ctx = NULL;
    sws_ctx = sws_getContext(self.frameWidth, self.frameHeight, m_CodecCtx->pix_fmt, self.frameWidth, self.frameHeight, AV_PIX_FMT_RGB24, SWS_BILINEAR, NULL, NULL, NULL);
    AVPacket packet;    //保存的是解码前的数据，也就是压缩后的数据。该结构本身不直接包含数据，其有一个指向数据域的指针。
    int i = 0, ret;
    while (av_read_frame(m_FormatCtx, &packet) >= 0)
    {
        //判断数据包是否来自视频流
        if (packet.stream_index == m_VideoStream)
            
        {
            //            avcodec_decode_video2(m_CodecCtx, m_Frame, &frameFinished, &packet);    弃用
            ret = avcodec_send_packet(m_CodecCtx, &packet);
            if(ret < 0 && ret != AVERROR(EAGAIN) && ret != AVERROR_EOF)
            {
                printf("Decode Error send packet.\n");
                continue;
            }
            ret = avcodec_receive_frame(m_CodecCtx, m_Frame); //这里的m_Frame就是解码出来的AVFrame
            if(ret < 0 && ret != AVERROR_EOF)
            {
                printf("Decode Error receive frame.\n");
                continue;
            }
            
            //转换图像格式为RGB
            sws_scale(sws_ctx, (uint8_t const* const*)m_Frame->data, m_Frame->linesize, 0, self.frameHeight, m_FrameRGB->data, m_FrameRGB->linesize);
            ++i;
            [self SaveFrame:self.frameWidth :self.frameHeight :i];
        }
        av_packet_unref(&packet);
    }
}
*/
/**
 保存解码后的帧到本地
 @param width 宽
 @param height 高
 @param iFrame 帧数
 */
/*
- (void)SaveFrame:(int)width :(int)height :(int)iFrame
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *outputURL = paths[0];
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtPath:outputURL withIntermediateDirectories:YES attributes:nil error:nil];
    outputURL = [outputURL stringByAppendingPathComponent:@"frame"];
    FILE *pFile;
    char *szFilename = (char *)malloc(sizeof(char)*(outputURL.length+32));
    sprintf(szFilename, "%s%d.ppm", outputURL.UTF8String, iFrame);
    NSLog(@"文件名 %s",szFilename);
    pFile = fopen(szFilename, "wb");
    if (pFile == NULL)
    {
        NSLog(@"打开文件失败");
        return;
    }
    fprintf(pFile, "P6\n%d %d\n255\n",width, height);
    for (int y = 0; y < height; y++)
    {
        fwrite(m_Frame->data[0]+y*m_Frame->linesize[0], 1, width*3, pFile);
    }
    fclose(pFile);
}
 */

#pragma mark - static function

static void avStreamFPSTimeBase(AVStream *st, AVCodecContext *cc, float defaultTimeBase, float *pFPS, float *pTimeBase)
{
    float fps, timebase;
    
    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else if(cc->time_base.den && cc->time_base.num)
        timebase = av_q2d(cc->time_base);
    else
        timebase = defaultTimeBase;
    
    if (cc->ticks_per_frame != 1)
    {
        NSLog(@"WARNING: st.codec.ticks_per_frame=%d", cc->ticks_per_frame);
    }
    
    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
        fps = av_q2d(st->avg_frame_rate);
    else if (st->r_frame_rate.den && st->r_frame_rate.num)
        fps = av_q2d(st->r_frame_rate);
    else
        fps = 1.0 / timebase;
    
    if (pFPS)
        *pFPS = fps;
    if (pTimeBase)
        *pTimeBase = timebase;
}

@end
