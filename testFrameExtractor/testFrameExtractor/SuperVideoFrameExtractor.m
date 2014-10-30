//
//  SuperVideoFrameExtractor.m
//  testFrameExtractor
//
//  Created by htaiwan on 10/24/14.
//  Copyright (c) 2014 appteam. All rights reserved.
//

#import "SuperVideoFrameExtractor.h"
#import "AudioStreamer.h"
#import "Utilities.h"

#include "libavutil/intreadwrite.h"
#include "avcodec.h"


@interface SuperVideoFrameExtractor ()
{
    CMVideoFormatDescriptionRef videoFormatDescr;
    VTDecompressionSessionRef session;
    OSStatus status;
    NSData *spsData;
    NSData *ppsData;
}
@property (nonatomic, retain) AudioStreamer *audioController;
-(void)convertFrameToRGB;
-(UIImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height;
-(void)savePicture:(AVPicture)pict width:(int)width height:(int)height index:(int)iFrame;
-(void)setupScaler;

@end

@implementation SuperVideoFrameExtractor
@synthesize outputWidth, outputHeight;

@synthesize audioPacketQueue,audioPacketQueueSize;
@synthesize _audioStream,_audioCodecContext;
@synthesize emptyAudioBuffer;

#pragma mark - property method

-(void)setOutputWidth:(int)newValue
{
    if (outputWidth == newValue) return;
    outputWidth = newValue;
    [self setupScaler];
}

-(void)setOutputHeight:(int)newValue
{
    if (outputHeight == newValue) return;
    outputHeight = newValue;
    [self setupScaler];
}

-(int)sourceWidth
{
    return pCodecCtx->width;
}

-(int)sourceHeight
{
    return pCodecCtx->height;
}

-(UIImage *)currentImage
{
    if (!pFrame->data[0]) return nil;
    [self convertFrameToRGB];
    
    [self savePicture:picture width:outputWidth height:outputWidth index:frameIndex];
    frameIndex ++;
    
    return [self imageFromAVPicture:picture width:outputWidth height:outputHeight];
}

-(double)duration
{
    return (double)pFormatCtx->duration / AV_TIME_BASE;
}

-(double)currentTime
{
    AVRational timeBase = pFormatCtx->streams[videoStream]->time_base;
    return packet.pts * (double)timeBase.num / timeBase.den;
}



#pragma mark - Object method

// For stream server test
- (id)initWithVideo:(NSString *)moviePath usesTcp:(BOOL)usesTcp
{
    if (!(self=[super init])) return nil;
    
    AVCodec         *pCodec;
    
    // 註冊所有format和codecs
    avcodec_register_all();
    av_register_all();
    avformat_network_init();

    // Set the RTSP Options
    AVDictionary *opts = 0;
    if (usesTcp) {
        av_dict_set(&opts, "rtsp_transport", "tcp", 0);
    }
    
    // 打開影片檔案
    if (avformat_open_input(&pFormatCtx, [moviePath UTF8String], NULL, &opts) != 0) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't open file\n");
        goto initError;
    }
    
    // 取得影片串流資訊
    if (avformat_find_stream_info(pFormatCtx,NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't find stream information\n");
        goto initError;
    }
    
    // Find the first video stream
    videoStream=-1;
    audioStream=-1;
    
    for (int i=0; i<pFormatCtx->nb_streams; i++) {
        if (pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            NSLog(@"found video stream");
            videoStream=i;
        }
        if (pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
            NSLog(@"found audio stream");
            audioStream=i;
        }
    }
    
    if (videoStream==-1 && audioStream==-1) {
        goto initError;
    }
    
    // Get a pointer to the codec context for the video stream
    pCodecCtx = pFormatCtx->streams[videoStream]->codec;
    
    // Alex: Data init
    spsData = nil;
    ppsData = nil;
    videoFormatDescr = NULL;
    session = NULL;
    
    // Find the decoder for the video stream
    pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
    if (pCodec == NULL) {
        av_log(NULL, AV_LOG_ERROR, "Unsupported codec!\n");
        goto initError;
    }
    
    // Open codec
    if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot open video decoder\n");
        goto initError;
    }
    
    if (audioStream > -1 ) {
        NSLog(@"set up audiodecoder");
        [self setupAudioDecoder];
    }
    
    // Allocate video frame
    pFrame = avcodec_alloc_frame();
    
    outputWidth = pCodecCtx->width;
    self.outputHeight = pCodecCtx->height;
    
    return self;

initError:
    [self release];
    return nil;
}

// For local File test
-(id)initWithVideo:(NSString *)moviePath
{
    if (!(self=[super init])) return nil;
    
    AVCodec         *pCodec;

    frameIndex = 0;
    
    // 註冊所有format和codecs
    avcodec_register_all();
    av_register_all();
    
    // 打開影片檔案
    if (avformat_open_input(&pFormatCtx,[moviePath cStringUsingEncoding:NSASCIIStringEncoding], NULL, NULL) != 0) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't open file\n");
        goto initError;
    }
    
    // 取得影片串流資訊
    if (avformat_find_stream_info(pFormatCtx, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't find stream information\n");
        goto initError;
    }
    
    // 取得第一個影片串流
    if ((videoStream = av_find_best_stream(pFormatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &pCodec, 0)) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot find a video stream in the input file\n");
        goto initError;
    }
    
    // 取得影片串流的codec context的指標
    pCodecCtx = pFormatCtx->streams[videoStream]->codec;
    
    // 找出此影片串流的decoder
    pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
    
    // 開啟 codec
    if(avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot open video decoder\n");
        goto initError;
    }
    
    // Allocate video frame
    pFrame = avcodec_alloc_frame();
    
    outputWidth = pCodecCtx->width;
    self.outputHeight = pCodecCtx->height;
    
    return self;

initError:
    [self release];
    return nil;    
}


- (CMSampleBufferRef)  cmSampleBufferFromCGImage: (CGImageRef) image size:(CGSize) size
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size.width,
                                          size.height, kCVPixelFormatType_32ARGB, (CFDictionaryRef) options,
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
    CMVideoFormatDescriptionRef videoInfo = NULL;
    CMSampleBufferRef sampleBuffer = NULL;
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                       pxbuffer, true, NULL, NULL, videoInfo, NULL, &sampleBuffer);
    return sampleBuffer;
}

-(CGImageRef)CGImageRefFromAVPicture:(AVPicture)pict width:(int)width height:(int)height
{
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, pict.data[0], pict.linesize[0]*height,kCFAllocatorNull);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(width,
                                       height,
                                       8,
                                       24,
                                       pict.linesize[0],
                                       colorSpace,
                                       bitmapInfo, 
                                       provider, 
                                       NULL, 
                                       NO, 
                                       kCGRenderingIntentDefault);
    return cgImage;
}

// 根據指定時間去找尋最近的keyframe
-(void)seekTime:(double)seconds
{
    AVRational timeBase = pFormatCtx->streams[videoStream]->time_base;
    int64_t targetFrame = (int64_t)((double)timeBase.den / timeBase.num * seconds);
    avformat_seek_file(pFormatCtx, videoStream, targetFrame, targetFrame, targetFrame, AVSEEK_FLAG_FRAME);
    avcodec_flush_buffers(pCodecCtx);
}

#pragma mark - private method 

- (void)setupAudioDecoder
{
    if (audioStream >= 0) {
        _audioBufferSize = 192000;
        _audioBuffer = av_malloc(_audioBufferSize);
        _inBuffer = NO;
        
        _audioCodecContext = pFormatCtx->streams[audioStream]->codec;
        _audioStream = pFormatCtx->streams[audioStream];
        
        AVCodec *codec = avcodec_find_decoder(_audioCodecContext->codec_id);
        if (codec == NULL) {
            NSLog(@"Not found audio codec.");
            return;
        }
        
        if (avcodec_open2(_audioCodecContext, codec, NULL) < 0) {
            NSLog(@"Could not open audio codec.");
            return;
        }
        
        if (audioPacketQueue) {
            [audioPacketQueue release];
            audioPacketQueue = nil;
        }
        audioPacketQueue = [[NSMutableArray alloc] init];
        
        if (audioPacketQueueLock) {
            [audioPacketQueueLock release];
            audioPacketQueueLock = nil;
        }
        audioPacketQueueLock = [[NSLock alloc] init];

        if (_audioController) {
            [_audioController _stopAudio];
            [_audioController release];
            _audioController = nil;
        }
        _audioController = [[AudioStreamer alloc] initWithStreamer:self];
    } else {
        pFormatCtx->streams[audioStream]->discard = AVDISCARD_ALL;
        audioStream = -1;
    }
}

- (void)nextPacket
{
    _inBuffer = NO;
}

- (AVPacket*)readPacket
{
    if (_currentPacket.size > 0 || _inBuffer) return &_currentPacket;
    
    NSMutableData *packetData = [audioPacketQueue objectAtIndex:0];
    _packet = [packetData mutableBytes];
    
    if (_packet) {
        if (_packet->dts != AV_NOPTS_VALUE) {
            _packet->dts += av_rescale_q(0, AV_TIME_BASE_Q, _audioStream->time_base);
        }
        
        if (_packet->pts != AV_NOPTS_VALUE) {
            _packet->pts += av_rescale_q(0, AV_TIME_BASE_Q, _audioStream->time_base);
        }
        
        [audioPacketQueueLock lock];
        audioPacketQueueSize -= _packet->size;
        if ([audioPacketQueue count] > 0) {
            [audioPacketQueue removeObjectAtIndex:0];
        }
        [audioPacketQueueLock unlock];
        
        _currentPacket = *(_packet);
    }
    
    return &_currentPacket;
}

- (void)closeAudio
{
    [_audioController _stopAudio];
    primed=NO;
}


-(void)setupScaler
{
    // release old pricture 和 scaler
    avpicture_free(&picture);
    sws_freeContext(img_convert_ctx);
    
    // Allocate RGB picture
    avpicture_alloc(&picture, AV_PIX_FMT_RGB24, outputWidth, outputHeight);
    
    // 建立scaler
    static int sws_flags =  SWS_FAST_BILINEAR;
    img_convert_ctx = sws_getContext(pCodecCtx->width,
                                     pCodecCtx->height,
                                     pCodecCtx->pix_fmt,
                                     outputWidth,
                                     outputHeight,
                                     AV_PIX_FMT_RGB24,
                                     sws_flags, NULL, NULL, NULL);
}

-(void)convertFrameToRGB
{
    sws_scale(img_convert_ctx, pFrame->data, pFrame->linesize, 0, pCodecCtx->height, picture.data, picture.linesize);
}

-(UIImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height
{
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, pict.data[0], pict.linesize[0]*height, kCFAllocatorNull);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(width,
                                       height,
                                       8,
                                       24,
                                       pict.linesize[0],
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    return image;
}

-(void)savePicture:(AVPicture)pict width:(int)width height:(int)height index:(int)iFrame
{
    FILE *pFile;
    NSString *fileName;
    int  y;
    
    fileName = [Utilities documentsPath:[NSString stringWithFormat:@"image%04d.ppm",iFrame]];
    // Open file
    NSLog(@"write image file: %@",fileName);
    pFile=fopen([fileName cStringUsingEncoding:NSASCIIStringEncoding], "wb");
    if(pFile==NULL)
        return;
    
    // Write header
    fprintf(pFile, "P6\n%d %d\n255\n", width, height);
    
    // Write pixel data
    for(y=0; y<height; y++)
        fwrite(pict.data[0]+y*pict.linesize[0], 1, width*3, pFile);
    
    // Close file
    fclose(pFile);
}

-(void)dealloc {
    // Free scaler
    sws_freeContext(img_convert_ctx);
    
    // Free RGB picture
    avpicture_free(&picture);
    
    // Free the packet that was allocated by av_read_frame
    av_free_packet(&packet);
    
    // Free the YUV frame
    av_free(pFrame);
    
    // Close the codec
    if (pCodecCtx) avcodec_close(pCodecCtx);
    
    // Close the video file
    if (pFormatCtx) avformat_close_input(&pFormatCtx);
    
    [super dealloc];
}


#pragma mark - iOS8 HW decode 相關method

- (void) iOS8HWDecode
{
    // 1. get SPS,PPS form stream data, and create CMFormatDescription 和 VTDecompressionSession
    if (spsData == nil && ppsData == nil) {
        uint8_t *data = pCodecCtx -> extradata;
        int size = pCodecCtx -> extradata_size;
        NSString *tmp3 = [NSString new];
        for(int i = 0; i < size; i++) {
            NSString *str = [NSString stringWithFormat:@" %.2X",data[i]];
            tmp3 = [tmp3 stringByAppendingString:str];
        }
        
//        NSLog(@"size ---->>%i",size);
//        NSLog(@"%@",tmp3);

        int startCodeSPSIndex = 0;
        int startCodePPSIndex = 0;
        int spsLength = 0;
        int ppsLength = 0;

        for (int i = 0; i < size; i++) {
            if (i >= 3) {
                if (data[i] == 0x01 && data[i-1] == 0x00 && data[i-2] == 0x00 && data[i-3] == 0x00) {
                    if (startCodeSPSIndex == 0) {
                        startCodeSPSIndex = i;
                    }
                    if (i > startCodeSPSIndex) {
                        startCodePPSIndex = i;
                    }
                }
            }
        }
        
        spsLength = startCodePPSIndex - startCodeSPSIndex - 4;
        ppsLength = size - (startCodePPSIndex + 1);
        
//        NSLog(@"startCodeSPSIndex --> %i",startCodeSPSIndex);
//        NSLog(@"startCodePPSIndex --> %i",startCodePPSIndex);
//        NSLog(@"spsLength --> %i",spsLength);
//        NSLog(@"ppsLength --> %i",ppsLength);

        int nalu_type;
        nalu_type = ((uint8_t) data[startCodeSPSIndex + 1] & 0x1F);
//        NSLog(@"NALU with Type \"%@\" received.", naluTypesStrings[nalu_type]);
        if (nalu_type == 7) {
            spsData = [NSData dataWithBytes:&(data[startCodeSPSIndex + 1]) length: spsLength];
        }
        
        nalu_type = ((uint8_t) data[startCodePPSIndex + 1] & 0x1F);
//        NSLog(@"NALU with Type \"%@\" received.", naluTypesStrings[nalu_type]);
        if (nalu_type == 8) {
            ppsData = [NSData dataWithBytes:&(data[startCodePPSIndex + 1]) length: ppsLength];
        }
        
        // 2. create  CMFormatDescription
        if (spsData != nil && ppsData != nil) {
            const uint8_t* const parameterSetPointers[2] = { (const uint8_t*)[spsData bytes], (const uint8_t*)[ppsData bytes] };
            const size_t parameterSetSizes[2] = { [spsData length], [ppsData length] };
            status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, &videoFormatDescr);
//            NSLog(@"Found all data for CMVideoFormatDescription. Creation: %@.", (status == noErr) ? @"successfully." : @"failed.");
        }
        
        // 3. create VTDecompressionSession
        VTDecompressionOutputCallbackRecord callback;
        callback.decompressionOutputCallback = didDecompress;
        callback.decompressionOutputRefCon = (__bridge void *)self;
          NSDictionary *destinationImageBufferAttributes =[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],(id)kCVPixelBufferOpenGLESCompatibilityKey,[NSNumber numberWithInt:kCVPixelFormatType_32BGRA],(id)kCVPixelBufferPixelFormatTypeKey,nil];
//        NSDictionary *destinationImageBufferAttributes =[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],(id)kCVPixelBufferOpenGLESCompatibilityKey,nil];
//        NSDictionary *destinationImageBufferAttributes = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey: (id)kCVPixelBufferPixelFormatTypeKey];
        status = VTDecompressionSessionCreate(kCFAllocatorDefault, videoFormatDescr, NULL, (CFDictionaryRef)destinationImageBufferAttributes, &callback, &session);
//        status = VTDecompressionSessionCreate(kCFAllocatorDefault, videoFormatDescr, NULL, NULL, &callback, &session);
//        NSLog(@"Creating Video Decompression Session: %@.", (status == noErr) ? @"successfully." : @"failed.");
        
        
        int32_t timeSpan = 90000;
        CMSampleTimingInfo timingInfo;
        timingInfo.presentationTimeStamp = CMTimeMake(0, timeSpan);
        timingInfo.duration =  CMTimeMake(3000, timeSpan);
        timingInfo.decodeTimeStamp = kCMTimeInvalid;
    }
    
    int startCodeIndex = 0;
    for (int i = 0; i < 5; i++) {
        if (packet.data[i] == 0x01) {
            startCodeIndex = i;
            break;
        }
    }
    int nalu_type = ((uint8_t)packet.data[startCodeIndex + 1] & 0x1F);
//    NSLog(@"NALU with Type \"%@\" received.", naluTypesStrings[nalu_type]);
    
    if (nalu_type == 1 || nalu_type == 5) {
        // 4. get NALUnit payload into a CMBlockBuffer,
        CMBlockBufferRef videoBlock = NULL;
        status = CMBlockBufferCreateWithMemoryBlock(NULL, packet.data, packet.size, kCFAllocatorNull, NULL, 0, packet.size, 0, &videoBlock);
//        NSLog(@"BlockBufferCreation: %@", (status == kCMBlockBufferNoErr) ? @"successfully." : @"failed.");
       
        // 5.  making sure to replace the separator code with a 4 byte length code (the length of the NalUnit including the unit code)
        int reomveHeaderSize = packet.size - 4;
        const uint8_t sourceBytes[] = {(uint8_t)(reomveHeaderSize >> 24), (uint8_t)(reomveHeaderSize >> 16), (uint8_t)(reomveHeaderSize >> 8), (uint8_t)reomveHeaderSize};
        status = CMBlockBufferReplaceDataBytes(sourceBytes, videoBlock, 0, 4);
//        NSLog(@"BlockBufferReplace: %@", (status == kCMBlockBufferNoErr) ? @"successfully." : @"failed.");
        
        NSString *tmp3 = [NSString new];
        for(int i = 0; i < sizeof(sourceBytes); i++) {
            NSString *str = [NSString stringWithFormat:@" %.2X",sourceBytes[i]];
            tmp3 = [tmp3 stringByAppendingString:str];
        }
//        NSLog(@"size = %i , 16Byte = %@",reomveHeaderSize,tmp3);

        // 6. create a CMSampleBuffer.
        CMSampleBufferRef sbRef = NULL;
//        int32_t timeSpan = 90000;
//        CMSampleTimingInfo timingInfo;
//        timingInfo.presentationTimeStamp = CMTimeMake(0, timeSpan);
//        timingInfo.duration =  CMTimeMake(3000, timeSpan);
//        timingInfo.decodeTimeStamp = kCMTimeInvalid;
        const size_t sampleSizeArray[] = {packet.size};
//        status = CMSampleBufferCreate(kCFAllocatorDefault, videoBlock, true, NULL, NULL, videoFormatDescr, 1, 1, &timingInfo, 1, sampleSizeArray, &sbRef);
        status = CMSampleBufferCreate(kCFAllocatorDefault, videoBlock, true, NULL, NULL, videoFormatDescr, 1, 0, NULL, 1, sampleSizeArray, &sbRef);

//        NSLog(@"SampleBufferCreate: %@", (status == noErr) ? @"successfully." : @"failed.");
        
        // 7. use VTDecompressionSessionDecodeFrame
        VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
        VTDecodeInfoFlags flagOut;
        status = VTDecompressionSessionDecodeFrame(session, sbRef, flags, &sbRef, &flagOut);
//        NSLog(@"VTDecompressionSessionDecodeFrame: %@", (status == noErr) ? @"successfully." : @"failed.");
        CFRelease(sbRef);
        
        [self.delegate startDecodeData];

//        /* Flush in-process frames. */
//        VTDecompressionSessionFinishDelayedFrames(session);
//        /* Block until our callback has been called with the last frame. */
//        VTDecompressionSessionWaitForAsynchronousFrames(session);
//        
//        /* Clean up. */
//        VTDecompressionSessionInvalidate(session);
//        CFRelease(session);
//        CFRelease(videoFormatDescr);


//        NSLog(@"========================================================================");
//        NSLog(@"========================================================================");
    }
}



// 判斷在video stream中是否還有下一個fram可以讀取，回傳false，表示影片已經播放完畢
-(BOOL)stepFrame
{
    // AVPacket packet;
    int frameFinished=0;
    
    while (!frameFinished && av_read_frame(pFormatCtx, &packet)>= 0) {
        // 確認packet 是否是屬於此video stream
        if (packet.stream_index == videoStream) {
            
#warning  important: choose new iOS8 API start to decode
            // FFMPEG decode
//             avcodec_decode_video2(pCodecCtx, pFrame, &frameFinished, &packet);

            // ios8 HW decode
            [self iOS8HWDecode];
        }
    }
    
    return frameFinished != 0;
}



#pragma mark - VideoToolBox Decompress Frame CallBack
/*
 This callback gets called everytime the decompresssion session decodes a frame
 */
void didDecompress( void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration )
{
    if (status != noErr || !imageBuffer) {
        // error -8969 codecBadDataErr
        // -12909 The operation couldn’t be completed. (OSStatus error -12909.)
        NSLog(@"Error decompresssing frame at time: %.3f error: %d infoFlags: %u", (float)presentationTimeStamp.value/presentationTimeStamp.timescale, (int)status, (unsigned int)infoFlags);
        return;
    }
    
//    NSLog(@"Got frame data.\n");
//    NSLog(@"Success decompresssing frame at time: %.3f error: %d infoFlags: %u", (float)presentationTimeStamp.value/presentationTimeStamp.timescale, (int)status, (unsigned int)infoFlags);
    __weak __block SuperVideoFrameExtractor *weakSelf = (__bridge SuperVideoFrameExtractor *)decompressionOutputRefCon;
    [weakSelf.delegate getDecodeImageData:imageBuffer];
}


- (void) dumpPacketData
{
    // Log dump
    int index = 0;
    NSString *tmp = [NSString new];
    for(int i = 0; i < packet.size; i++) {
        NSString *str = [NSString stringWithFormat:@" %.2X",packet.data[i]];
        if (i == 4) {
            NSString *header = [NSString stringWithFormat:@"%.2X",packet.data[i]];
            NSLog(@" header ====>> %@",header);
            if ([header isEqualToString:@"41"]) {
                NSLog(@"P Frame");
            }
            if ([header isEqualToString:@"65"]) {
                NSLog(@"I Frame");
            }
        }
        tmp = [tmp stringByAppendingString:str];
        index++;
        if (index == 16) {
            NSLog(@"%@",tmp);
            tmp = @"";
            index = 0;
        }
    }
}

NSString * const naluTypesStrings[] = {
    @"Unspecified (non-VCL)",
    @"Coded slice of a non-IDR picture (VCL)",
    @"Coded slice data partition A (VCL)",
    @"Coded slice data partition B (VCL)",
    @"Coded slice data partition C (VCL)",
    @"Coded slice of an IDR picture (VCL)",
    @"Supplemental enhancement information (SEI) (non-VCL)",
    @"Sequence parameter set (non-VCL)",
    @"Picture parameter set (non-VCL)",
    @"Access unit delimiter (non-VCL)",
    @"End of sequence (non-VCL)",
    @"End of stream (non-VCL)",
    @"Filler data (non-VCL)",
    @"Sequence parameter set extension (non-VCL)",
    @"Prefix NAL unit (non-VCL)",
    @"Subset sequence parameter set (non-VCL)",
    @"Reserved (non-VCL)",
    @"Reserved (non-VCL)",
    @"Reserved (non-VCL)",
    @"Coded slice of an auxiliary coded picture without partitioning (non-VCL)",
    @"Coded slice extension (non-VCL)",
    @"Coded slice extension for depth view components (non-VCL)",
    @"Reserved (non-VCL)",
    @"Reserved (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
};




@end
