//
//  ViewController.m
//  testFrameExtractor
//
//  Created by htaiwan on 10/24/14.
//  Copyright (c) 2014 appteam. All rights reserved.
//

#import "ViewController.h"
#import "SuperVideoFrameExtractor.h"
#import "Utilities.h"
#import "AAPLEAGLLayer.h"

@interface ViewController ()
{
    int tmp;
}

@property CADisplayLink *displayLink;
@property NSMutableArray *outputFrames;
@property NSMutableArray *presentationTimes;
@property dispatch_semaphore_t bufferSemaphore;
@property dispatch_queue_t backgroundQueue;


@end

@implementation ViewController

#pragma mark - CADisplayLink Callback



- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
//    self.video = [[SuperVideoFrameExtractor alloc] initWithVideo:[Utilities bundlePath:@"1080p30FPS.mp4"]];
    self.video = [[SuperVideoFrameExtractor alloc] initWithVideo:@"rtsp://192.168.2.73:1935/vod/sample.mp4" usesTcp:NO];
    self.video.delegate = self;
    tmp = 0;
    self.outputFrames = [NSMutableArray new];
    self.presentationTimes = [NSMutableArray new];
    
    self.backgroundQueue = dispatch_queue_create("com.htaiwan.backgroundqueue", NULL);
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.displayLink setPaused:YES];
    self.bufferSemaphore = dispatch_semaphore_create(0);
    
    // set output image size
//    self.video.outputWidth = 426;
//    self.video.outputHeight = 320;
    
//    self.video.outputWidth = 1920;
//    self.video.outputHeight = 1080;
    
    // print some info about the video
    NSLog(@"video duration: %f",self.video.duration);
    NSLog(@"video size: %d x %d", self.video.sourceWidth, self.video.sourceHeight);
    
    self.imageView.image = [UIImage imageNamed:@"image3"];
    [self.imageView setContentMode:UIViewContentModeScaleAspectFit];

    // video images are landscape, so rotate image view 90 degrees
//    [self.imageView setTransform:CGAffineTransformMakeRotation(M_PI/2)];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - button method

- (IBAction)play:(UIButton *)sender {
    BOOL isPlaying = self.displayLink.isPaused;
    
    if (isPlaying == NO) {
        [self.displayLink setPaused:YES];
    } else{
        [self.displayLink setPaused:NO];
        dispatch_async(self.backgroundQueue, ^{
            [self.video stepFrame];
        });
    }
    
    
//    lastFrameTime = -1;
//    
//    // seek to 0.0 seconds
//    [self.video seekTime:0.0];
//
//    
//    [NSTimer scheduledTimerWithTimeInterval:1.0/30
//                                     target:self
//                                   selector:@selector(displayNextFrame:)
//                                   userInfo:nil
//                                    repeats:YES];
}

- (IBAction)showTime:(UIButton *)sender
{
    NSLog(@"current time: %f s",self.video.currentTime);
}
//
//-(void) getDecodeImageData:(CVImageBufferRef) imageBuffer
//{
//    CVImageBufferRef buffer = imageBuffer;
//    
//    CVPixelBufferLockBaseAddress(buffer, 0);
//    
//    //從 CVImageBufferRef 取得影像的細部資訊
//    uint8_t *base;
//    size_t width, height, bytesPerRow;
//    base = CVPixelBufferGetBaseAddress(buffer);
//    width = CVPixelBufferGetWidth(buffer);
//    height = CVPixelBufferGetHeight(buffer);
//    bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
//    
//    //利用取得影像細部資訊格式化 CGContextRef
//    CGColorSpaceRef colorSpace;
//    CGContextRef cgContext;
//    colorSpace = CGColorSpaceCreateDeviceRGB();
//    cgContext = CGBitmapContextCreate (base, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
//
//    CGColorSpaceRelease(colorSpace);
//    
//    //透過 CGImageRef 將 CGContextRef 轉換成 UIImage
//    CGImageRef cgImage;
//    UIImage *image;
//    cgImage = CGBitmapContextCreateImage(cgContext);
//    image = [UIImage imageWithCGImage:cgImage];
//    CGImageRelease(cgImage);
//    CGContextRelease(cgContext);
//    
//    CVPixelBufferUnlockBaseAddress(buffer, 0);
//    
////    NSString *fileName = [Utilities documentsPath:[NSString stringWithFormat:@"image%i.png",tmp]];
////    tmp ++;
////    [UIImagePNGRepresentation(image) writeToFile:fileName atomically:YES];
////    NSError *error;
////    NSFileManager *fileMgr = [NSFileManager defaultManager];
////    NSLog(@"Documents directory: %@", [fileMgr contentsOfDirectoryAtPath:fileName error:&error]);
//    
//    //成功轉換成 UIImage
////    self.imageView.image = [UIImage imageNamed:@"image3"];
//    [self.imageView setImage:image];
//    [self.imageView setNeedsDisplay];
//}


- (void) displayImage:(CVImageBufferRef)imageBuffer
{
    CVImageBufferRef buffer = imageBuffer;
    
    CVPixelBufferLockBaseAddress(buffer, 0);
    
    //從 CVImageBufferRef 取得影像的細部資訊
    uint8_t *base;
    size_t width, height, bytesPerRow;
    base = CVPixelBufferGetBaseAddress(buffer);
    width = CVPixelBufferGetWidth(buffer);
    height = CVPixelBufferGetHeight(buffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    
    //利用取得影像細部資訊格式化 CGContextRef
    CGColorSpaceRef colorSpace;
    CGContextRef cgContext;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    cgContext = CGBitmapContextCreate (base, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    CGColorSpaceRelease(colorSpace);
    
    //透過 CGImageRef 將 CGContextRef 轉換成 UIImage
    CGImageRef cgImage;
    UIImage *image;
    cgImage = CGBitmapContextCreateImage(cgContext);
    image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);
    
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    
    //    NSString *fileName = [Utilities documentsPath:[NSString stringWithFormat:@"image%i.png",tmp]];
    //    tmp ++;
    //    [UIImagePNGRepresentation(image) writeToFile:fileName atomically:YES];
    //    NSError *error;
    //    NSFileManager *fileMgr = [NSFileManager defaultManager];
    //    NSLog(@"Documents directory: %@", [fileMgr contentsOfDirectoryAtPath:fileName error:&error]);
    
    //成功轉換成 UIImage
    //    self.imageView.image = [UIImage imageNamed:@"image3"];
    [self.imageView setImage:image];
}

-(void) startDecodeData
{
    if ([self.presentationTimes count] >= 5) {
        [self.displayLink setPaused:NO];
        NSLog(@"====== wait ======");
        dispatch_semaphore_wait(self.bufferSemaphore, DISPATCH_TIME_FOREVER);
    }
}

-(void) getDecodeImageData:(CVImageBufferRef) imageBuffer
{
    id imageBufferObject = (__bridge id)imageBuffer;
    NSUInteger insertionIndex = self.presentationTimes.count + 1;
    
    [self.outputFrames addObject:imageBufferObject];
    [self.presentationTimes addObject:[NSNumber numberWithInteger:insertionIndex]];
    
    NSLog(@"====== callback ====== %lu", (unsigned long)self.presentationTimes.count);
    
//    id imageBufferObject = (__bridge id)imageBuffer;
//    [self.outputFrames addObject:imageBufferObject];
//    NSLog(@"===>>%lu",(unsigned long)self.outputFrames.count);
//    if (self.outputFrames.count >= 5) {
//        dispatch_semaphore_wait(self.bufferSemaphore, DISPATCH_TIME_FOREVER);
//    }
}


- (void)displayLinkCallback:(CADisplayLink *)sender
{
    if ([self.outputFrames count] && [self.presentationTimes count]) {
        CVImageBufferRef imageBuffer = NULL;
        NSNumber *insertionIndex = nil;
        id imageBufferObject = nil;
        @synchronized(self){
            insertionIndex = [self.presentationTimes firstObject];
            imageBufferObject = [self.outputFrames firstObject];
            imageBuffer = (__bridge CVImageBufferRef)imageBufferObject;
        }
        
        @synchronized(self){
            if (imageBufferObject) {
                [self.outputFrames removeObjectAtIndex:0];
            }
            if (insertionIndex) {
                [self.presentationTimes removeObjectAtIndex:0];
                if ([self.presentationTimes count] == 3) {
                    NSLog(@"====== start ======");
                    dispatch_semaphore_signal(self.bufferSemaphore);
                }
            }
        }
        
        if (imageBuffer) {
            NSLog(@"====== show ====== %lu", (unsigned long)self.presentationTimes.count);
//            [self displayPixelBuffer:imageBuffer];
            [self displayImage:imageBuffer];
        }
        
    }
    
    
    /////////////////////////////////////////////////////////
//    if (self.outputFrames.count >= 5) {
//        id imageBufferObject = nil;
//        CVImageBufferRef imageBuffer = NULL;
//        @synchronized(self){
//            imageBufferObject = [self.outputFrames firstObject];
//            imageBuffer = (__bridge CVImageBufferRef)imageBufferObject;
//        }
//        @synchronized(self){
//            if (imageBufferObject) {
//                [self.outputFrames removeObjectAtIndex:0];
//                if (self.outputFrames.count == 0) {
//                     dispatch_semaphore_signal(self.bufferSemaphore);
//                }
//            }
//        }
//        if (imageBuffer) {
//            [self displayPixelBuffer:imageBuffer];
//        }
//    }
}

- (void)displayPixelBuffer:(CVImageBufferRef)imageBuffer
{
    int width = (int)CVPixelBufferGetWidth(imageBuffer);
    int height = (int)CVPixelBufferGetHeight(imageBuffer);
    CGFloat halfWidth = self.view.frame.size.width;
    CGFloat halfheight = self.view.frame.size.height;
    if (width > halfWidth || height > halfheight) {
        width /= 2;
        height /= 2;
    }
    
    AAPLEAGLLayer *layer = [[AAPLEAGLLayer alloc] init];
//    if (self.videoPreferredTransform.a == -1.0f) {
//        [layer setAffineTransform:CGAffineTransformRotate(layer.affineTransform, (180.0f * M_PI) / 180.0f)];
//    } else if (self.videoPreferredTransform.a == 0.0f){
//        [layer setAffineTransform:CGAffineTransformRotate(layer.affineTransform, (90.0f * M_PI) / 180.0f)];
//    }
    [layer setFrame:CGRectMake(0.0f, self.view.frame.size.height - 50.0f - height, width, height)];
    layer.presentationRect = CGSizeMake(width, height);
    
//    layer.timeCode = [NSString stringWithFormat:@"%.3f", [framePTS floatValue]];
    [layer setupGL];
    
//    [self.view.layer addSublayer:layer];
    [self.layerView.layer addSublayer:layer];
    [layer displayPixelBuffer:imageBuffer];
}


#pragma mark - private method

#define LERP(A,B,C) ((A)*(1.0-C)+(B)*C)

-(void)displayNextFrame:(NSTimer *)timer
{
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    if (![self.video stepFrame]) {
        [timer invalidate];
        [self.playBtn setEnabled:YES];
        return;
    }
    
    self.imageView.image = self.video.currentImage;
//    float frameTime = 1.0/([NSDate timeIntervalSinceReferenceDate]-startTime);
//    if (lastFrameTime<0) {
//        lastFrameTime = frameTime;
//    } else {
//        lastFrameTime = LERP(frameTime, lastFrameTime, 0.8);
//    }
//    [self.FPSLabel setText:[NSString stringWithFormat:@"%.0f",lastFrameTime]];
}

@end
