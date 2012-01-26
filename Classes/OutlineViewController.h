//
//  OutlineViewController.h
//  DocSets
//
//  Created by Ole Zorn on 06.12.10.
//  Copyright 2010 omz:software. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DetailViewController, OutlineItem;

@interface OutlineViewController : UITableViewController {

	OutlineItem *rootItem;
	NSArray *visibleItems;
	__weak DetailViewController *detailViewController;
}

@property (nonatomic, weak) DetailViewController *detailViewController;
@property (nonatomic, strong) NSArray *visibleItems;

- (id)initWithItems:(NSArray *)outlineItems title:(NSString *)outlineTitle;

@end


@interface OutlineItem : NSObject {
    NSString *title;
	NSString *aref;
	NSString *href;
	NSArray *children;
	BOOL expanded;
	int level;
}

@property (nonatomic) BOOL expanded;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *aref;
@property (nonatomic, strong, readonly) NSString *href;
@property (nonatomic, readonly) int level;
@property (nonatomic, strong, readonly) NSArray *children;

- (id)initWithDictionary:(NSDictionary *)outlineInfo level:(int)outlineLevel;
- (NSArray *)flattenedChildren;
- (void)addOpenChildren:(NSMutableArray *)list;

@end


@interface OutlineCell : UITableViewCell {
	__weak id delegate;
	OutlineItem *outlineItem;
	UIButton *outlineDisclosureButton;
}

@property (nonatomic, weak) id delegate;
@property (nonatomic, strong) OutlineItem *outlineItem;

@end


@interface NSObject (OutlineCellDelegate)

- (void)outlineCellDidTapDisclosureButton:(OutlineCell *)cell;

@end