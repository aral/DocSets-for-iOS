//
//  RootViewController.h
//  DocSets
//
//  Created by Ole Zorn on 05.12.10.
//  Copyright 2010 omz:software. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DetailViewController;

@interface RootViewController : UITableViewController {
	
	DetailViewController *detailViewController;
}

@property (nonatomic, strong) DetailViewController *detailViewController;

@end
