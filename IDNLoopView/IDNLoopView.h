//
//  IDNImageLoopView.h
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

#import <UIKit/UIKit.h>

@protocol IDNLoopViewDataSource;
@protocol IDNLoopViewDelegate;

/** 图片/视图循环播放控件

 地址：https://github.com/photondragon/IDNLoopView

 这个控件有如下特点：

 1. 可实现图片或视图的无限循环播放
 2. 支持任意类型视图，包括但不限于UIImageView
 3. 支持运行时动态改变IDNLoopView控件的大小
 4. 使用方法类似UITableView，没有学习成本

 用法类似于UITableView，设置好datasource和delegate就行了。
 */
@interface IDNLoopView : UIView

@property(nonatomic,weak) id<IDNLoopViewDataSource> datasource;
@property(nonatomic,weak) id<IDNLoopViewDelegate> delegate;

@property(nonatomic) NSInteger currentIndex; ///< 当前显示的View的Index

- (void)reloadViews;

@property(nonatomic) NSTimeInterval intervalTime; ///< 自动切换图片间隔时间，默认5秒，0表示不自动切换
@property(nonatomic) BOOL reuseDisabled; ///< 是否禁用view的回收机制（类似UITableViewCell的回收机制），默认NO。
@property(nonatomic,strong,readonly) UIPageControl *pageControl; ///< 内置的UIPageControll，你可以设置其颜色或者隐藏它

@end

@protocol IDNLoopViewDataSource <NSObject>

- (NSInteger)numberOfViewsInLoopView:(IDNLoopView*)loopView; ///< 返回要显示的视图个数
- (UIView*)loopView:(IDNLoopView*)loopView viewAtIndex:(NSInteger)index reuseView:(UIView*)view;

@end

@protocol IDNLoopViewDelegate <NSObject>

@optional
/**
 当用户tap当前View时被调用。
 @param index 当前view的index
 */
- (void)loopView:(IDNLoopView*)loopView didTapViewAtIndex:(NSInteger)index;

/**
 当currentIndex因触摸（或自动切换）改变时被调用，在设置dataSource或者reloadViews时也会被调用
 @param index 当前view的index
 */
- (void)loopView:(IDNLoopView*)loopView didShowViewAtIndex:(NSInteger)index;

@end
