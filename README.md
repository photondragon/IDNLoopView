### IDNLoopView 图片/视图循环播放控件（可在Touch过程中改变控件大小）

![IDNLoopView演示](https://github.com/photondragon/IDNLoopView/raw/master/IDNLoopView.gif)

这个控件有如下特点：

1. 可实现图片或视图的无限循环播放
1. 支持任意类型视图，包括但不限于UIImageView
1. **可在Touch过程中改变控件大小，过渡效果完美**
1. 可配合[SDWebImage](https://github.com/rs/SDWebImage)流畅加载网络图片
1. 当Touch时，自动播放定时器会重置
1. 使用方法类似UITableView，没有学习成本

### 使用方法

先将源文件`IDNLoopView.h`和`IDNLoopView.m`加入项目中，具体用法跟UITableView差不多，示例代码如下：

``` objective-c
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
//	self.loopView.reuseDisabled = YES; //关闭view回收机制
//	self.loopView.pageControl.hidden = YES; //隐藏内置的UIPageControl
//	self.loopView.intervalTime = 0; //关闭自动切换
//	self.loopView.currentIndex = 2;
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
```

如果要显示网络图片，可配合[SDWebImage](https://github.com/rs/SDWebImage)使用，修改数据源方法`- loopView:viewAtIndex:reuseView:`如下：

``` objective-c
- (UIView*)loopView:(IDNLoopView *)loopView viewAtIndex:(NSInteger)index reuseView:(UIView *)view
{
	UIImageView* imageView;
	if(view==nil)
	{
		imageView = [[UIImageView alloc] init];
	}
	else
		imageView = (UIImageView*)view;

	static UIImage* placeholder = nil;
	if(placeholder==nil)
		placeholder = [UIImage imageNamed:@"imageLoading.jpg"];
		
	[imageView sd_setImageWithURL:[NSURL URLWithString:self.images[index]] placeholderImage:placeholder];

	return imageView;
}
```
