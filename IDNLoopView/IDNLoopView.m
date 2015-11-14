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
#import <UIKit/UIGestureRecognizerSubclass.h>

#pragma mark Touch检测手势

// 用于检测是否有任何Touch存在
@interface IDNLoopViewTouchGestureRecognizer : UIGestureRecognizer
@end
@implementation IDNLoopViewTouchGestureRecognizer
{
	NSMutableSet* allTouches;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		allTouches = [NSMutableSet new];
	}
	return self;
}
- (instancetype)initWithTarget:(id)target action:(SEL)action
{
	self = [super initWithTarget:target action:action];
	if (self) {
		allTouches = [NSMutableSet new];
	}
	return self;
}
- (void)reset
{
	[allTouches removeAllObjects];
}
- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer
{
	return NO;
}
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer
{
	return YES;
}
- (BOOL)shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
	return NO;
}
- (BOOL)shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
	return NO;
}
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[allTouches unionSet:touches];
	self.state = UIGestureRecognizerStateBegan;
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[allTouches minusSet:touches];
	if(allTouches.count==0)
		self.state = UIGestureRecognizerStateEnded;
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[allTouches minusSet:touches];
	if(allTouches.count==0)
		self.state = UIGestureRecognizerStateEnded;
}
@end

#pragma mark 

#define MinSwipeVelocity 512.0

@interface IDNLoopView()
<UIScrollViewDelegate>
{
	UIScrollView* scrollView;
	CGSize unitSize; //一个view的大小。
	NSInteger numberOfViews;
	NSMutableArray* reuseViews; //回收的views
	NSMutableDictionary* dicVisibleViews; //key: index, value: view。index可正可负，不受numberOfViews限制，主要是由contentOffset决定

	IDNLoopViewTouchGestureRecognizer* touchGestureRecognizer; //用于检测touchdown touchup，以便关闭或打开轮播
}

@property(nonatomic) BOOL autoSwitch;
@property(nonatomic) NSInteger showIndex; //基本同currentIndex，区别在于showIndex会超出[0, numberOfViews)的范围，做取模运算后等于currentIndex

@end

#define LoopTimes 15

@implementation IDNLoopView

- (void)initializer
{
	if(dicVisibleViews)
		return;

	self.clipsToBounds = YES;
	
	dicVisibleViews = [NSMutableDictionary new];
	reuseViews = [NSMutableArray new];

	unitSize = self.bounds.size;

	scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, unitSize.width, unitSize.height)];
	scrollView.pagingEnabled = YES;
	scrollView.delegate = self;
	scrollView.showsVerticalScrollIndicator = NO;
	scrollView.showsHorizontalScrollIndicator = NO;
	[self addSubview:scrollView];

	[self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)]];

	touchGestureRecognizer = [[IDNLoopViewTouchGestureRecognizer alloc] initWithTarget:self action:@selector(pan)];
	[self addGestureRecognizer:touchGestureRecognizer];

	_pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, unitSize.height-10 , unitSize.width, 0)];
	_pageControl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	_pageControl.pageIndicatorTintColor = [UIColor colorWithWhite:0.3 alpha:0.3];
	_pageControl.currentPageIndicatorTintColor = [UIColor colorWithWhite:0.95 alpha:1.0];
	[self addSubview:_pageControl];
	
	_intervalTime = 5.0;
	_currentIndex = NSNotFound;
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

#pragma mark 

- (void)layoutSubviews
{
	[super layoutSubviews];

	CGSize newUnitSize = self.bounds.size;
	if(newUnitSize.width == unitSize.width && newUnitSize.height==unitSize.height)
		return; //frame没变，返回

	CGFloat ratioW; //宽度改变的比例，然后缩放scrollView.contentOffset
	if(unitSize.width<=0)
		ratioW = 1.0;
	else
		ratioW = newUnitSize.width/unitSize.width;
	unitSize = newUnitSize;
	CGPoint contentOffset = scrollView.contentOffset;
	contentOffset.x *= ratioW;
	scrollView.frame = CGRectMake(0, 0, unitSize.width, unitSize.height);
	scrollView.contentSize = CGSizeMake(unitSize.width*numberOfViews*LoopTimes, 0);
	scrollView.contentOffset = contentOffset;

	[self layoutVisibleViews];
}

- (void)setCurrentIndex:(NSInteger)currentIndex
{
	if(numberOfViews==0 && currentIndex!=NSNotFound)
		currentIndex = NSNotFound;

	if(currentIndex!=NSNotFound)
	{
		if(currentIndex<0 || currentIndex>=numberOfViews)
			return;
	}

	if(_currentIndex==currentIndex)
		return;

	_currentIndex = currentIndex;

	if(_currentIndex!=NSNotFound)
	{
		if(_currentIndex != (_showIndex%numberOfViews))
		{
			_showIndex = numberOfViews*(LoopTimes/2)+_currentIndex;
			[self updateContentOffsetAnimated:NO];
			[self loadVisibleViews];
			[self layoutVisibleViews];
		}

		_pageControl.currentPage = _currentIndex;
	}
	if([_delegate respondsToSelector:@selector(loopView:didShowViewAtIndex:)])
		[_delegate loopView:self didShowViewAtIndex:_currentIndex];
}

- (void)reloadViews
{
	//清理
	if(numberOfViews)
	{
		NSInteger index = 0;
		for (UIView* view in dicVisibleViews.allValues) {
			[view removeFromSuperview];
			index++;
		}
		[dicVisibleViews removeAllObjects];
		[reuseViews removeAllObjects];
		numberOfViews = 0;
		_showIndex = 0;
		[self updateContentOffsetAnimated:NO];
		self.currentIndex = NSNotFound;
	}

	numberOfViews = [_datasource numberOfViewsInLoopView:self];
	NSAssert2(numberOfViews>=0, @"[%@ numberOfViewsInLoopView:]不可返回负数（实际返回%d）", NSStringFromClass([_datasource class]), (int)numberOfViews);

	_pageControl.numberOfPages = numberOfViews;
	scrollView.contentSize = CGSizeMake(unitSize.width*numberOfViews*LoopTimes, 0);

	_showIndex = numberOfViews;

	[self updateContentOffsetAnimated:NO];
	[self loadVisibleViews];
	[self layoutVisibleViews];
	[self updateCurrentIndex];

	self.autoSwitch = NO;
	self.autoSwitch = YES;
}

- (void)setDatasource:(id<IDNLoopViewDataSource>)datasource
{
	if(datasource)
	{
		NSAssert1([datasource respondsToSelector:@selector(numberOfViewsInLoopView:)], @"IDNLoopView设置了无效的datasource，[%@ numberOfViewsInLoopView:]方法不存在", NSStringFromClass([datasource class]));
		NSAssert1([datasource respondsToSelector:@selector(loopView:viewAtIndex:reuseView:)], @"IDNLoopView设置了无效的datasource，[%@ loopView:viewAtIndex:reuseView:]方法不存在", NSStringFromClass([datasource class]));
	}
	if(_datasource==datasource)
		return;

	_datasource = datasource;
	[self reloadViews];
}

- (void)contentOffsetChanged
{
	if(numberOfViews==0)
		return;
	NSInteger showIndex = scrollView.contentOffset.x / unitSize.width + 0.5;
	if(showIndex==_showIndex)
		return;

	_showIndex = showIndex;

	[self loadVisibleViews];
	[self layoutVisibleViews];
	[self updateCurrentIndex];
}

// 将showIndex校正到[numberOfViews*(LoopTimes/2), numberOfViews*(LoopTimes/2+1))之间
- (void)correctShowIndex
{
	NSInteger deltaIndex = 0;

	// 校正showIndex到正常范围内[0, numberOfViews)
	if(_showIndex<numberOfViews*(LoopTimes/2))
	{
		do {
			_showIndex += numberOfViews;
			deltaIndex += numberOfViews;
		}while (_showIndex<numberOfViews*(LoopTimes/2));
	}
	else if(_showIndex>=numberOfViews*(LoopTimes/2+1))
	{
		do {
			_showIndex -= numberOfViews;
			deltaIndex -= numberOfViews;
		}while (_showIndex>=numberOfViews*(LoopTimes/2+1));
	}
	if(deltaIndex!=0)
	{
		// 修改dicVisibleViews中的key的值
		NSArray* newVisibles = dicVisibleViews.allKeys;
		NSMutableDictionary* dic = [NSMutableDictionary new];
		for (NSInteger i = 0; i<newVisibles.count; i++) {
			NSNumber* oldIndexNumber = newVisibles[i];
			NSNumber* newIndexNumber = @(oldIndexNumber.integerValue+deltaIndex);
			UIView* view = dicVisibleViews[oldIndexNumber];
			dic[newIndexNumber] = view;
		}
		dicVisibleViews = dic;
		
		scrollView.contentOffset = [self offsetFromIndex:_showIndex];
		[self layoutVisibleViews];
	}
}

#pragma mark 视图加载的几个基本步骤

// 根据_showIndex设置contentOffset
- (void)updateContentOffsetAnimated:(BOOL)animated
{
	[scrollView setContentOffset:[self offsetFromIndex:_showIndex] animated:animated];
}

- (void)updateCurrentIndex
{
	NSInteger currentIndex = _showIndex;
	if(numberOfViews<=0)
	{
		currentIndex = NSNotFound;
	}
	else
	{
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
			}while (currentIndex>=numberOfViews);
		}
	}
	self.currentIndex = currentIndex;
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
			[scrollView addSubview:view];
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

#pragma mark 位置计算相关

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

#pragma mark 其它

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

	switch (touchGestureRecognizer.state) {
		case UIGestureRecognizerStatePossible:
		case UIGestureRecognizerStateBegan:
			self.autoSwitch = NO;
			break;
		case UIGestureRecognizerStateEnded:
		case UIGestureRecognizerStateCancelled:
		case UIGestureRecognizerStateFailed:
			if(_intervalTime>0 && numberOfViews>1)
				self.autoSwitch = YES;
			break;
		default:
			break;
	}

}

- (void)setReuseDisabled:(BOOL)reuseDisabled
{
	if(_reuseDisabled==reuseDisabled)
		return;
	_reuseDisabled = reuseDisabled;
	if(_reuseDisabled)
		[reuseViews removeAllObjects];
}

#pragma mark scroll view delegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
	self.autoSwitch = NO;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if(_intervalTime>0 && numberOfViews>1)
		self.autoSwitch = YES;
}

- (void)scrollViewDidScroll:(UIScrollView *)aScrollView
{
	[self contentOffsetChanged];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
	[self correctShowIndex];
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	[self correctShowIndex];
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

	[scrollView setContentOffset:[self offsetFromIndex:_showIndex+1] animated:YES];

	if(_intervalTime>0 && numberOfViews>1)
		self.autoSwitch = YES;
}

@end
