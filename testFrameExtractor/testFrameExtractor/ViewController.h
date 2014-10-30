//
//  ViewController.h
//  testFrameExtractor
//
//  Created by htaiwan on 10/24/14.
//  Copyright (c) 2014 appteam. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SuperVideoFrameExtractor.h"


@class SuperVideoFrameExtractor;

@interface ViewController : UIViewController <SuperVideoFrameExtractorDelegate> 
{
    float lastFrameTime;
}
@property (weak, nonatomic) IBOutlet UIView *layerView;

@property (nonatomic, retain) SuperVideoFrameExtractor *video;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIButton *playBtn;
@property (weak, nonatomic) IBOutlet UIButton *timeBtn;
@property (weak, nonatomic) IBOutlet UILabel *FPSLabel;

- (IBAction)play:(UIButton *)sender;
- (IBAction)showTime:(UIButton *)sender;

@end

