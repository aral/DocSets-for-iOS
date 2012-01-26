//
//  BookmarksViewController.h
//  DocSets
//
//  Created by Ole Zorn on 26.01.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DocSet, DetailViewController;

@interface BookmarksViewController : UITableViewController {

	DocSet *docSet;
	__weak DetailViewController *detailViewController;
}

@property (nonatomic, weak) DetailViewController *detailViewController;

- (id)initWithDocSet:(DocSet *)selectedDocSet;

@end
