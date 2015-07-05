//
//  IDNImageLoopView.m
//  IDNFramework
//
//  Created by photondragon on 15/7/1.
//
//  Copyright 2015 photondragon
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "IDNLoopView.h"

#define MinSwipeVelocity 512.0

@interface IDNLoopView()

@property(nonatomic) CGPoint contentOffset; //contentOffset实时改变时，只会影响contentView的位置。不会影响unitViews。
@property(nonatomic) BOOL autoSwitch;
@property(nonatomic) NSInteger showIndex; //基本同currentIndex，区别在于showIndex可能会超出[0, numberOfViews)的范围，做取模运算后等于currentIndex

@end

@implementation IDNLoopView
{
	UIView* contentView;
	CGSize unitSize; //一个view的大小。
	NSInteger numberOfViews;
	NSMutableArray* reuseViews; //回收的views
	NSMutableDictionary* dicVisibleViews; //key: index, value: view。index可正可负，不受numberOfViews限制，主要是由contentOffset决定

	UIPanGestureRecognizer* panGestureRecognizer;
	CGPoint translateOfPan; //Pan操作的上一次translate
}

- (void)initializer
{
	if(dicVisibleViews)
		return;

	self.clipsToBounds = YES;
	
	dicVisibleViews = [NSMutableDictionary new];
	reuseViews = [NSMutableArray new];
	unitSize = self.bounds.size;
	contentView = [[UIView alloc] init];
	contentView.layer.anchorPoint = CGPointZero;
	[self addSubview:contentView];
	panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan)];
	[self addGestureRecognizer:panGestureRecognizer];
	[self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)]];

	_pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, unitSize.height-10 , unitSize.width, 0)];
	_pageControl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
//	_pageControl.currentPageIndicatorTintColor = [UIColor redColor];
//	_pageControl.pageIndicatorTintColor = [UIColor whiteColor];
	[self addSubview:_pageControl];
	
	_intervalTime = 5.0;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		[self initializer];
	}
	return self;
}
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self) {
		[self initializer];
	}
	return self;
}
- (instancetype)init
{
	self = [super init];
	if (self) {
		[self initializer];
	}
	return self;
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	if(numberOfViews<=0)
		return;

	CGSize newUnitSize = self.bounds.size;
	CGFloat ratioW, ratioH;
	if(unitSize.width<=0)
		ratioW = 1.0;
	else
		ratioW = newUnitSize.width/unitSize.width;
	if(unitSize.height<=0)
		ratioH = 1.0;
	else
		ratioH = newUnitSize.height/unitSize.height;
	unitSize = newUnitSize;
	self.contentOffset = CGPointMake(_contentOffset.x*ratioW, _contentOffset.y*ratioH);
	translateOfPan = CGPointZero;
	if(panGestureRecognizer.state != UIGestureRecognizerStatePossible)
		[panGestureRecognizer setTranslation:translateOfPan inView:self];
	[self layoutVisibleViews];
}

- (void)tap:(UITapGestureRecognizer*)tapGesture
{
	if(numberOfViews<=0)
		return;
	if([_delegate respondsToSelector:@selector(loopView:didTapViewAtIndex:)])
		[_delegate loopView:self didTapViewAtIndex:self.currentIndex];
}

- (void)pan
{
	if(numberOfViews<=0)
		return;

	CGPoint deltaTouch = [panGestureRecognizer translationInView:self];
	[self moveContent:CGPointMake(deltaTouch.x-translateOfPan.x, deltaTouch.y-translateOfPan.y)];
	switch (panGestureRecognizer.state) {
		case UIGestureRecognizerStateEnded:
		{
			translateOfPan = CGPointZero;

			CGPoint velocity = [panGestureRecognizer velocityInView:self];
			NSInteger newIndex;
			if(velocity.x>MinSwipeVelocity)
				newIndex = _showIndex-1;
			else if(velocity.x<-MinSwipeVelocity)
				newIndex = _showIndex+1;
			else
				newIndex = [self indexFromOffset:_contentOffset];

			[self setShowIndex:newIndex animated:YES];

			if(_intervalTime>0 && numberOfViews>1)
				self.autoSwitch = YES;
			break;
		}
		case UIGestureRecognizerStateCancelled:
			translateOfPan = CGPointZero;
			self.contentOffset = [self offsetFromIndex:_showIndex]; //恢复到showIndex对应的offset，相当于什么也没改变。

			if(_intervalTime>0 && numberOfViews>1)
				self.autoSwitch = YES;
			break;
		case UIGestureRecognizerStateBegan:
			self.autoSwitch = NO;
		default:
			translateOfPan = deltaTouch;
			break;
	}
}

- (NSInteger)currentIndex
{
	if(numberOfViews==0)
		return -1;
	// _currentIndex可能会超出[0, numberOfViews)的范围，所以下面要校正到正常范围内
	NSInteger currentIndex = _showIndex;
	if(currentIndex<0)
	{
		do {
			currentIndex += numberOfViews;
		}while (currentIndex<0);
	}
	else if(currentIndex>=numberOfViews)
	{
		do {
			currentIndex -= numberOfViews;
		}while (currentIndex<0);
	}
	return currentIndex;
}

- (void)setCurrentIndex:(NSInteger)currentIndex
{
	[self setCurrentIndex:currentIndex animated:NO];
}
- (void)setCurrentIndex:(NSInteger)currentIndex animated:(BOOL)animated
{
	if(numberOfViews==0)
		return;
	if(self.currentIndex==currentIndex)
		return;
	if(currentIndex<0 || currentIndex>=numberOfViews)
		return;
	[self setShowIndex:currentIndex animated:animated];
}

- (void)setShowIndex:(NSInteger)showIndex
{
	// 这个方法不起任何作用。
}
- (void)setShowIndex:(NSInteger)showIndex animated:(BOOL)animated
{
	if(numberOfViews==0)
		return;
	NSInteger oldIndex = self.currentIndex;

	_showIndex = showIndex; //_showIndex与showIndex即使相等也不return，因为有可能showIndex没改变，但contentOffset改变了，此时相当于将contentOffset恢复到showIndex对应的位置上。

	__weak IDNLoopView* wself = self;
	[self setContentOffset:[self offsetFromIndex:showIndex] animated:animated animateCompletion:^(BOOL finished) {
		IDNLoopView* sself = wself;
		[sself correctShowIndex]; //滚动动画结束后，校正_currentIndex到[0, numberOfViews)范围内
	}];
	[self loadVisibleViews];
	[self layoutVisibleViews];

	NSInteger newIndex = self.currentIndex;
	if(newIndex!=oldIndex)
	{
		_pageControl.currentPage = newIndex;
		if([_delegate respondsToSelector:@selector(loopView:didShowViewAtIndex:)])
			[_delegate loopView:self didShowViewAtIndex:newIndex];
	}
}

- (void)moveContent:(CGPoint)deltaTouch
{
	if(deltaTouch.x==0 && deltaTouch.y==0)
		return;
	self.contentOffset = CGPointMake(_contentOffset.x-deltaTouch.x, _contentOffset.y);
}

- (void)setContentOffset:(CGPoint)offset
{
	[self setContentOffset:offset animated:NO animateCompletion:nil];
}
- (void)setContentOffset:(CGPoint)offset animated:(BOOL)animated animateCompletion:(void (^)(BOOL finished))animateCompletion
{
	_contentOffset = offset;
	if(animated==NO)
	{
		contentView.frame = CGRectMake(-offset.x, 0, unitSize.width*numberOfViews, unitSize.height);
	}
	else
	{
		[UIView animateWithDuration:0.2 animations:^{
			contentView.frame = CGRectMake(-offset.x, 0, unitSize.width*numberOfViews, unitSize.height);
		} completion:animateCompletion];
	}
}

// 加载可见view，应该在currentIndex改变后调用
- (void)loadVisibleViews
{
	NSArray* newVisibles = [self calcVisibleViews];
	NSArray* oldVisibles = dicVisibleViews.allKeys;
	NSMutableSet* set = [NSMutableSet setWithArray:oldVisibles];
	[set addObjectsFromArray:newVisibles];
	for (NSNumber* indexNumber in set) {

		BOOL isOld,isNew;
		if ([oldVisibles containsObject:indexNumber])
			isOld = YES;
		else
			isOld = NO;
		if([newVisibles containsObject:indexNumber])
			isNew = YES;
		else
			isNew = NO;

		if(isOld && isNew) //一直可见
			continue;
		else if(isOld && isNew==NO) //之前可见，现在不可见
		{
			UIView* view = dicVisibleViews[indexNumber];
			[view removeFromSuperview];
			if(_reuseDisabled==NO)
				[reuseViews addObject:view];
			[dicVisibleViews removeObjectForKey:indexNumber];
		}
		else if(isOld==NO && isNew) //之前不可见，现在可见
		{
			NSInteger index = indexNumber.integerValue;
			NSInteger viewIndex = index;
			while (viewIndex<0) viewIndex += numberOfViews;
			while (viewIndex>=numberOfViews) viewIndex -= numberOfViews;
			UIView* view = [_datasource loopView:self viewAtIndex:viewIndex reuseView:[reuseViews lastObject]];
			[reuseViews removeLastObject];
			[contentView addSubview:view];
			dicVisibleViews[indexNumber] = view;
		}
	}
}

// 重新放置unitViews
- (void)layoutVisibleViews
{
	NSArray* visibles = dicVisibleViews.allKeys;
	for (NSNumber* indexNumber in visibles) {
		UIView* view = dicVisibleViews[indexNumber];
		[self layoutView:view index:indexNumber.integerValue];
	}
}

// 将currentIndex校正到[0, numberOfViews)之间
- (void)correctShowIndex
{
	NSInteger delta = 0;

	// 校正showIndex到正常范围内[0, numberOfViews)
	if(_showIndex<0)
	{
		do {
			_showIndex += numberOfViews;
			delta += numberOfViews;
		}while (_showIndex<0);
	}
	else if(_showIndex>=numberOfViews)
	{
		do {
			_showIndex -= numberOfViews;
			delta -= numberOfViews;
		}while (_showIndex>=numberOfViews);
	}
	if(delta!=0)
	{
		NSArray* newVisibles = dicVisibleViews.allKeys;
		for (NSInteger i = 0; i<newVisibles.count; i++) {
			NSNumber* oldIndexNumber = newVisibles[i];
			NSNumber* newIndexNumber = @(oldIndexNumber.integerValue+delta);
			UIView* view = dicVisibleViews[oldIndexNumber];
			dicVisibleViews[newIndexNumber] = view;
			[dicVisibleViews removeObjectForKey:oldIndexNumber];
		}
		self.contentOffset = [self offsetFromIndex:_showIndex];
		[self layoutVisibleViews];
	}
}

- (void)setDatasource:(id<IDNLoopViewDataSource>)datasource
{
	if(_datasource==datasource)
		return;
	_datasource = datasource;
	[self reloadViews];
}

- (void)reloadViews
{
	for (UIView* view in dicVisibleViews.allValues) {
		[view removeFromSuperview];
	}
	[dicVisibleViews removeAllObjects];
	[reuseViews removeAllObjects];

	if([_datasource respondsToSelector:@selector(numberOfViewsInLoopView:)])
		numberOfViews = [_datasource numberOfViewsInLoopView:self];
	else
		numberOfViews = 0;
	NSAssert1(numberOfViews>=0, @"[IDNLoopView.datasource numberOfViewsInLoopView:]不可返回负数（实际返回%d）", (int)numberOfViews);

	_pageControl.numberOfPages = numberOfViews;
	_pageControl.currentPage = 0;

	_showIndex = 0;
	_contentOffset = CGPointZero;
	contentView.frame = CGRectMake(0, 0, unitSize.width*numberOfViews, unitSize.height);
	[self loadVisibleViews];
	[self layoutVisibleViews];


	self.autoSwitch = NO;
	self.autoSwitch = YES;

	if(numberOfViews>0 && [_delegate respondsToSelector:@selector(loopView:didShowViewAtIndex:)])
		[_delegate loopView:self didShowViewAtIndex:0];
}

- (void)setReuseDisabled:(BOOL)reuseDisabled
{
	if(_reuseDisabled==reuseDisabled)
		return;
	_reuseDisabled = reuseDisabled;
	if(_reuseDisabled)
		[reuseViews removeAllObjects];
}
#pragma mark auto switch

- (void)willMoveToWindow:(UIWindow *)newWindow
{
	[super willMoveToWindow:newWindow];
	if(newWindow)
	{
		if(_intervalTime>0 && numberOfViews>1)
			self.autoSwitch = YES;
	}
	else
	{
		self.autoSwitch = NO; //移除异步任务，消除对self的引用。
	}
}

- (void)setIntervalTime:(NSTimeInterval)intervalTime
{
	if(_intervalTime==intervalTime)
		return;
	if(intervalTime>0 && intervalTime<0.5) //最小间隔为0.5秒
		intervalTime = 0.5;
	_intervalTime = intervalTime;
	if(_intervalTime>0 && numberOfViews>1)
		self.autoSwitch = YES;
	else
		self.autoSwitch = NO;
}

- (void)setAutoSwitch:(BOOL)autoSwitch
{
	if(_autoSwitch==autoSwitch)
		return;
	_autoSwitch = autoSwitch;
	if(_autoSwitch)
	{
		if(numberOfViews<=1 || _intervalTime<=0)
		{
			_autoSwitch = NO;
			return;
		}
		[self performSelector:@selector(switchToNext) withObject:nil afterDelay:_intervalTime];
	}
	else
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(switchToNext) object:nil];
	}
}

- (void)switchToNext
{
	_autoSwitch = NO;
	if(numberOfViews<=1)
		return;

	[self setShowIndex:_showIndex+1 animated:YES];
	if(_intervalTime>0 && numberOfViews>1)
		self.autoSwitch = YES;
}

#pragma mark

// 根据index计算offset
- (CGPoint)offsetFromIndex:(NSInteger)index
{
	return CGPointMake(unitSize.width*index, 0);
}
// 根据offset计算index
- (NSInteger)indexFromOffset:(CGPoint)offset
{
	return roundf(offset.x/unitSize.width);
}

- (NSArray*)calcVisibleViews
{
	if(numberOfViews==0)
		return nil;
	return @[@(_showIndex-1),@(_showIndex),@(_showIndex+1)];
}

- (void)layoutView:(UIView*)view index:(NSInteger)index
{
	view.frame = CGRectMake(unitSize.width*index, 0, unitSize.width, unitSize.height);
}

@end
