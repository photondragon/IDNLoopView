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
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *constraintOfBottom;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *constraintOfRight;
@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	if([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = 0;

	self.loopView.delegate = self;
	self.loopView.datasource = self;
//	self.loopView.reuseDisabled = YES; //关闭view回收机制
//	self.loopView.pageControl.hidden = YES; //隐藏内置的UIPageControl
//	self.loopView.intervalTime = 0; //关闭自动切换
//	self.loopView.currentIndex = 2;
}

- (IBAction)changeSize:(id)sender {
	if(self.constraintOfBottom.constant>0)
	{
		self.constraintOfBottom.constant = 0;
		self.constraintOfRight.constant = 0;
	}
	else
	{
		self.constraintOfBottom.constant = 160;
		self.constraintOfRight.constant = 60;
	}
	[UIView animateWithDuration:0.2 animations:^{
		[self.view layoutIfNeeded];
	}];
}
- (IBAction)autoSwitch:(id)sender {
	if(self.loopView.intervalTime>0)
		self.loopView.intervalTime = 0;
	else
		self.loopView.intervalTime = 5.0;
}
- (IBAction)reload:(id)sender {
	[self.loopView reloadViews];
}

#pragma mark IDNLoopView DataSource & Delegate

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

- (void)loopView:(IDNLoopView *)loopView didShowViewAtIndex:(NSInteger)index
{
	NSLog(@"current index = %d", (int)index);
}

@end
