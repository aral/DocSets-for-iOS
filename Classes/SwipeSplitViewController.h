//
//  SwipeSplitViewController.h
//  SwipeSplitTest
//
//  Created by Ole Zorn on 23.01.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SwipeSplitViewController : UIViewController {

	UIImageView *_masterContainerView;
	UIViewController *__weak _masterViewController;
	UIViewController *__weak _detailViewController;
	
	UIView *_shieldView;
}

@property (nonatomic, strong) UIImageView *masterContainerView;
@property (nonatomic, readonly) UIViewController *masterViewController;
@property (nonatomic, readonly) UIViewController *detailViewController;
@property (nonatomic, strong) UIView *shieldView;

- (id)initWithMasterViewController:(UIViewController *)masterVC detailViewController:(UIViewController *)detailVC;
- (void)showMasterViewControllerAnimated:(BOOL)animated;
- (void)hideMasterViewControllerAnimated:(BOOL)animated;

@end
