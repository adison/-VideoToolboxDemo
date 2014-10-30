//
//  SuperVideoFrameExtractor.h
//  testFrameExtractor
//
//  Created by htaiwan on 10/24/14.
//  Copyright (c) 2014 appteam. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "libavformat/avformat.h"
#include "libswscale/swscale.h"
#include "libavcodec/avcodec.h"
#include "libavformat/avio.h"


@import AudioToolbox;
@import VideoToolbox;
@import CoreGraphics;
@import UIKit;
@import Foundation;

@protocol SuperVideoFrameExtractorDelegate <NSObject>
@optional

-(void) startDecodeData;
-(void) getDecodeImageData:(CVImageBufferRef) imageBuffer;

@end

@interface SuperVideoFrameExtractor : NSObject {
    AVFormatContext *pFormatCtx;
    AVCodecContext *pCodecCtx;
    AVFrame *pFrame;
    AVPacket packet;
    AVPicture picture;
    int videoStream;
    int audioStream;
    struct SwsContext *img_convert_ctx;
    int sourceWidth, sourceHeight;
    int outputWidth, outputHeight;
    UIImage *currentImage;
    double duration;
    double currentTime;
    
    NSLock *audioPacketQueueLock;
    AVCodecContext *_audioCodecContext;
    int16_t *_audioBuffer;
    int audioPacketQueueSize;
    NSMutableArray *audioPacketQueue;
    AVStream *_audioStream;
    NSUInteger _audioBufferSize;
    BOOL _inBuffer;
    AVPacket *_packet, _currentPacket;
    BOOL primed;
    
    int frameIndex;
}

@property (nonatomic, strong) id <SuperVideoFrameExtractorDelegate> delegate;

// 目前decode出來的圖片
@property (nonatomic, readonly) UIImage *currentImage;

// 影片frame的size
@property (nonatomic, readonly) int sourceWidth, sourceHeight;

// 輸出影片frame的size
@property (nonatomic) int outputWidth, outputHeight;

// 影片長度
@property (nonatomic, readonly) double duration;

// 目前所播放的時間
@property (nonatomic, readonly) double currentTime;

// 取得要播放的影片檔位置
-(id)initWithVideo:(NSString *)moviePath;
- (id)initWithVideo:(NSString *)moviePath usesTcp:(BOOL)usesTcp;

// 判斷在video stream中是否還有下一個fram可以讀取
// 回傳false，表示影片已經播放完畢
-(BOOL)stepFrame;

// 根據指定時間去找尋最近的keyframe
-(void)seekTime:(double)seconds;

- (AVPacket*)readPacket;
-(void)closeAudio;

@property (nonatomic, retain) NSMutableArray *audioPacketQueue;
@property (nonatomic, assign) AVCodecContext *_audioCodecContext;
@property (nonatomic, assign) AudioQueueBufferRef emptyAudioBuffer;
@property (nonatomic, assign) int audioPacketQueueSize;
@property (nonatomic, assign) AVStream *_audioStream;

@end
