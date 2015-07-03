//
//  ViewController.m
//  IDNLoopView
//
//  Created by photondragon on 15/7/2.
//  Copyright (c) 2015年 iosdev.net. All rights reserved.
//

#import "ViewController.h"
#import "IDNLoopView.h"

@interface ViewController ()
<IDNLoopViewDelegate,
IDNLoopViewDataSource>

@property (weak, nonatomic) IBOutlet IDNLoopView *loopView;
@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.loopView.datasource = self;
	self.loopView.delegate = self;
//	self.loopView.intervalTime = 0;
//	self.loopView.currentIndex = 2;
}

- (NSInteger)numberOfViewsInLoopView:(IDNLoopView *)loopView
{
	return 6;
}

- (UIView*)loopView:(IDNLoopView *)loopView viewAtIndex:(NSInteger)index reuseView:(UIView *)view
{
	UIImageView* imageView;
	if(view==nil)
	{
		imageView = [[UIImageView alloc] init];
	}
	else
		imageView = (UIImageView*)view;
	NSString* imgfile = [NSString stringWithFormat:@"抽象派艺术%03d.jpg", (int)index];
	NSLog(@"%@", imgfile);
	imageView.image = [UIImage imageNamed:imgfile];
	return imageView;
}

- (void)loopView:(IDNLoopView *)loopView didTapViewAtIndex:(NSInteger)index
{
	NSLog(@"tap index = %d", (int)index);
}
@end
