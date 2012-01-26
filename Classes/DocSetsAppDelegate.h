//
//  DocPadAppDelegate.h
//  DocSets
//
//  Created by Ole Zorn on 05.12.10.
//  Copyright 2010 omz:software. All rights reserved.
//

#import <UIKit/UIKit.h>


@class RootViewController, DetailViewController, SwipeSplitViewController;

@interface DocSetsAppDelegate : NSObject <UIApplicationDelegate> {
    
	UIWindow *window;
	SwipeSplitViewController *splitViewController;
	RootViewController *rootViewController;
	UINavigationController *rootNavigationController;
	DetailViewController *detailViewController;
}

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) SwipeSplitViewController *splitViewController;
@property (nonatomic, strong) RootViewController *rootViewController;
@property (nonatomic, strong) DetailViewController *detailViewController;

@end
