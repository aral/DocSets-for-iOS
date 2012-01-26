//
//  SwipeSplitViewController.m
//  SwipeSplitTest
//
//  Created by Ole Zorn on 23.01.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import "SwipeSplitViewController.h"

#define MASTER_VIEW_WIDTH	384.0

@interface SwipeSplitViewController ()

- (void)layoutViewControllers;

@end

@implementation SwipeSplitViewController

@synthesize masterContainerView=_masterContainerView, masterViewController=_masterViewController, detailViewController=_detailViewController;
@synthesize shieldView=_shieldView;

- (id)initWithMasterViewController:(UIViewController *)masterVC detailViewController:(UIViewController *)detailVC
{
	self = [super initWithNibName:nil bundle:nil];
	if (self) {
		_detailViewController = detailVC;
		_masterViewController = masterVC;
		
		[self addChildViewController:detailVC];
		[self addChildViewController:masterVC];
	}
	return self;
}

- (void)loadView
{
	[super loadView];
	
	self.detailViewController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	self.masterViewController.view.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
	
	self.masterViewController.view.layer.cornerRadius = 6.0;
	self.masterViewController.view.clipsToBounds = YES;
	self.masterContainerView.layer.shouldRasterize = YES;
	
	self.detailViewController.view.layer.cornerRadius = 6.0;
	self.detailViewController.view.clipsToBounds = YES;
	
	self.masterContainerView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Shadow.png"]];
	_masterContainerView.userInteractionEnabled = YES;
	_masterContainerView.contentStretch = CGRectMake(0.2, 0.2, 0.6, 0.6);
	_masterContainerView.image = nil;
	
	[self layoutViewControllers];
	
	[self.view addSubview:self.detailViewController.view];
	self.masterViewController.view.frame = CGRectInset(_masterContainerView.bounds, 3, 3);
	[_masterContainerView addSubview:self.masterViewController.view];
	[self.view addSubview:_masterContainerView];
	
	UISwipeGestureRecognizer *rightSwipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(rightSwipe:)];
	rightSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
	[self.detailViewController.view addGestureRecognizer:rightSwipeRecognizer];
}

- (void)viewDidAppear:(BOOL)animated
{
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
		[self showMasterViewControllerAnimated:YES];
	}
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation) && UIInterfaceOrientationIsPortrait(toInterfaceOrientation)) {
		[self.masterViewController viewWillDisappear:(duration > 0)];
	}
	if (self.shieldView) {
		[self.shieldView removeFromSuperview];
	}
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self layoutViewControllers];
}

- (void)layoutViewControllers
{
	CGSize boundsSize = self.view.bounds.size;
	CGRect masterFrame;
	CGRect detailFrame;
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
		masterFrame = CGRectMake(-MASTER_VIEW_WIDTH, 0, MASTER_VIEW_WIDTH, boundsSize.height);
		detailFrame = self.view.bounds;
	} else {
		masterFrame = CGRectMake(0, 0, MASTER_VIEW_WIDTH, boundsSize.height);
		detailFrame = CGRectMake(MASTER_VIEW_WIDTH + 1, 0, boundsSize.width - MASTER_VIEW_WIDTH - 1, boundsSize.height);
	}
	self.masterContainerView.frame = CGRectInset(masterFrame, -3, -3);
	//self.masterContainerView.image = nil;
	
	self.detailViewController.view.frame = detailFrame;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
		self.masterContainerView.image = nil;
	}
	
	if (UIInterfaceOrientationIsLandscape(fromInterfaceOrientation) && UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
		[self.masterViewController viewDidDisappear:YES];
	}
}

- (void)showMasterViewControllerAnimated:(BOOL)animated
{
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
		return;
	}
	
	[self.masterViewController viewWillAppear:animated];
	
	CGSize boundsSize = self.view.bounds.size;
	CGRect masterFrame = CGRectMake(0, 0, MASTER_VIEW_WIDTH, boundsSize.height);
	
	self.masterContainerView.image = [UIImage imageNamed:@"Shadow.png"];
	
	void(^transition)(void) = ^(void) {
		self.masterContainerView.frame = CGRectInset(masterFrame, -3, -3);
	};
	
	if (!self.shieldView) {
		_shieldView = [[UIView alloc] initWithFrame:self.view.bounds];
		_shieldView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		_shieldView.backgroundColor = [UIColor clearColor];
		[_shieldView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(shieldViewTapped:)]];
		UISwipeGestureRecognizer *leftSwipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(shieldViewLeftSwipe:)];
		leftSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
		[_shieldView addGestureRecognizer:leftSwipeRecognizer];
		
		UISwipeGestureRecognizer *rightSwipeRecognizer =[[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(shieldViewRightSwipe:)];
		rightSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
		[_shieldView addGestureRecognizer:rightSwipeRecognizer];
	}
	self.shieldView.frame = self.view.bounds;
	[self.view insertSubview:self.shieldView belowSubview:self.masterContainerView];
	
	if (animated) {
		[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState 
						 animations:transition 
						 completion:^ (BOOL finished) {
							 [self.masterViewController viewDidAppear:YES];
						 }];
	} else {
		transition();
		[self.masterViewController viewDidAppear:NO];
	}
}

- (void)hideMasterViewControllerAnimated:(BOOL)animated
{
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
		return;
	}
	void(^transition)(void) = ^(void) {
		[self.masterViewController viewWillDisappear:animated];
		[self layoutViewControllers];
		[self.shieldView removeFromSuperview]; 
	};
	if (animated) {
		[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState 
						 animations:transition 
						 completion:^ (BOOL finished) {
							 if (finished) {
								 self.masterContainerView.image = nil;
								 [self.masterViewController viewDidDisappear:YES];
							 }
						 }];
	} else {
		transition();
		[self.masterViewController viewDidDisappear:NO];
	}
}

- (void)rightSwipe:(UISwipeGestureRecognizer *)recognizer
{
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
		[self showMasterViewControllerAnimated:YES];
	} else {
		if ([self.masterViewController isKindOfClass:[UINavigationController class]]) {
			[(UINavigationController *)self.masterViewController popViewControllerAnimated:YES];
		}
	}
}

- (void)shieldViewRightSwipe:(UISwipeGestureRecognizer *)recognizer
{
	if ([self.masterViewController isKindOfClass:[UINavigationController class]]) {
		[(UINavigationController *)self.masterViewController popViewControllerAnimated:YES];
	}
}

- (void)shieldViewTapped:(UITapGestureRecognizer *)recognizer
{
	[self hideMasterViewControllerAnimated:YES];
}

- (void)shieldViewLeftSwipe:(UISwipeGestureRecognizer *)recognizer
{
	[self hideMasterViewControllerAnimated:YES];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}


@end
