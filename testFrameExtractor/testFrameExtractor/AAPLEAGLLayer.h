/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  This CAEAGLLayer subclass demonstrates how to draw a CVPixelBufferRef using OpenGLES and display the timecode associated with that pixel buffer in the top right corner.
  
 */

@import QuartzCore;
@import CoreVideo;
@import UIKit;
@import OpenGLES;
@import AVFoundation;

@interface AAPLEAGLLayer : CAEAGLLayer
@property CVPixelBufferRef pixelBufferContents;
@property CGSize presentationRect;
@property NSString *timeCode;
- (void)setupGL;
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end
