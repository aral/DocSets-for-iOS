//
//  DocSetViewController.h
//  DocSets
//
//  Created by Ole Zorn on 05.12.10.
//  Copyright 2010 omz:software. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DocSet, DetailViewController;

@interface DocSetViewController : UITableViewController <UISearchDisplayDelegate> {

	DetailViewController *detailViewController;
	DocSet *docSet;
	NSArray *nodeSections;
	NSArray *searchResults;
	UISearchDisplayController *searchDisplayController;
	NSDictionary *iconsByTokenType;
}

@property (nonatomic, strong) DocSet *docSet;
@property (nonatomic, strong) NSManagedObject *rootNode;
@property (nonatomic, strong) DetailViewController *detailViewController;
@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, strong) UISearchDisplayController *searchDisplayController;

- (id)initWithDocSet:(DocSet *)set rootNode:(NSManagedObject *)rootNode;

@end
