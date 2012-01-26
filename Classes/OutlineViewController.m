//
//  OutlineViewController.m
//  DocSets
//
//  Created by Ole Zorn on 06.12.10.
//  Copyright 2010 omz:software. All rights reserved.
//

#import "OutlineViewController.h"
#import "DetailViewController.h"

@implementation OutlineViewController

@synthesize detailViewController, visibleItems;

- (id)initWithItems:(NSArray *)outlineItems title:(NSString *)outlineTitle
{
	self = [super initWithStyle:UITableViewStylePlain];
	
	rootItem = [[OutlineItem alloc] initWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:outlineTitle, @"title", outlineItems, @"sections", nil] level:0];
	visibleItems = [rootItem flattenedChildren];
	
	self.title = outlineTitle;
	self.contentSizeForViewInPopover = CGSizeMake(320, 1024);
	return self;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		return YES;
	}
	return interfaceOrientation == UIInterfaceOrientationPortrait;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return [visibleItems count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    OutlineCell *cell = (OutlineCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[OutlineCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
	OutlineItem *item = [visibleItems objectAtIndex:indexPath.row];
	cell.outlineItem = item;
	cell.delegate = self;
    return cell;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
	[self.detailViewController showOutlineItem:[visibleItems objectAtIndex:indexPath.row]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	OutlineItem *item = [visibleItems objectAtIndex:indexPath.row];
	[self.detailViewController showOutlineItem:item];
}

- (void)outlineCellDidTapDisclosureButton:(OutlineCell *)cell
{
	OutlineItem *item = cell.outlineItem;
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[visibleItems indexOfObject:item] inSection:0];
	
	if (item.children.count > 0 && !item.expanded) {
		//expand
		item.expanded = YES;
		NSArray *expandedChildren = [item flattenedChildren];
		NSMutableArray *addedIndexPaths = [NSMutableArray array];
		for (int i=0; i<expandedChildren.count; i++) {
			NSIndexPath *addedIndexPath = [NSIndexPath indexPathForRow:indexPath.row + i + 1 inSection:0];
			[addedIndexPaths addObject:addedIndexPath];
		}
		self.visibleItems = [rootItem flattenedChildren];
		[self.tableView insertRowsAtIndexPaths:addedIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
	} else if (item.children.count > 0 && item.expanded) {
		//collapse
		NSMutableArray *removedIndexPaths = [NSMutableArray array];
		NSArray *collapsedChildren = [item flattenedChildren];
		item.expanded = NO;
		for (int i=0; i<collapsedChildren.count; i++) {
			NSIndexPath *removedIndexPath = [NSIndexPath indexPathForRow:indexPath.row + i + 1 inSection:0];
			[removedIndexPaths addObject:removedIndexPath];
		}
		self.visibleItems = [rootItem flattenedChildren];
		[self.tableView deleteRowsAtIndexPaths:removedIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
	}
}


@end



@implementation OutlineItem

@synthesize expanded, title, aref, href, level, children;

- (id)initWithDictionary:(NSDictionary *)outlineInfo level:(int)outlineLevel
{
	self = [super init];
	if (self) {
		title = [outlineInfo objectForKey:@"title"];
		level = outlineLevel;
		expanded = (level <= 0);
		NSArray *sections = [outlineInfo objectForKey:@"sections"];
		aref = [outlineInfo objectForKey:@"aref"];
		href = [outlineInfo objectForKey:@"href"];
		NSMutableArray *subItems = [NSMutableArray array];
		for (NSDictionary *subItemInfo in sections) {
			OutlineItem *subItem = [[OutlineItem alloc] initWithDictionary:subItemInfo level:level + 1];
			[subItems addObject:subItem];
		}
		children = [NSArray arrayWithArray:subItems];
	}
	return self;
}

- (NSArray *)flattenedChildren
{
	NSMutableArray *flatList = [NSMutableArray array];
	for (OutlineItem *child in children) {
		[child addOpenChildren:flatList];
	}
	return [NSArray arrayWithArray:flatList];
}

- (void)addOpenChildren:(NSMutableArray *)list
{
	[list addObject:self];
	if (expanded) {
		for (OutlineItem *child in children) {
			[child addOpenChildren:list];
		}
	}
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ (level %i)", title, level];
}


@end


@implementation OutlineCell

@synthesize delegate, outlineItem;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (self) {
		outlineDisclosureButton = [UIButton buttonWithType:UIButtonTypeCustom];
		outlineDisclosureButton.frame = CGRectMake(0, 0, 44, 44);
		[outlineDisclosureButton setBackgroundImage:[UIImage imageNamed:@"OutlineDisclosureButton.png"] forState:UIControlStateNormal];
		outlineDisclosureButton.hidden = YES;
		[outlineDisclosureButton addTarget:self action:@selector(expandOrCollapse:) forControlEvents:UIControlEventTouchUpInside];
		[self.contentView addSubview:outlineDisclosureButton];
	}
	return self;
}

- (void)setOutlineItem:(OutlineItem *)item
{
	outlineItem = item;
	self.textLabel.text = outlineItem.title;
	
	self.indentationWidth = 32.0 + 15.0 * (outlineItem.level - 1);
	self.indentationLevel = 1; //outlineItem.level;
	self.textLabel.font = (outlineItem.level <= 1) ? [UIFont boldSystemFontOfSize:17.0] : [UIFont boldSystemFontOfSize:15.0];
	
	if (outlineItem.children.count > 0) {
		outlineDisclosureButton.frame = CGRectMake(15 * (outlineItem.level - 1), 0, 44, 44);
		if (outlineItem.expanded) {
			outlineDisclosureButton.transform = CGAffineTransformMakeRotation(M_PI / 2);
		} else {
			outlineDisclosureButton.transform = CGAffineTransformIdentity;
		}
		outlineDisclosureButton.hidden = NO;
	} else {
		outlineDisclosureButton.hidden = YES;
	}
}

- (void)expandOrCollapse:(id)sender
{
	[UIView beginAnimations:nil context:nil];
	if (outlineItem.expanded) {
		outlineDisclosureButton.transform = CGAffineTransformIdentity;
	} else {
		outlineDisclosureButton.transform = CGAffineTransformMakeRotation(M_PI / 2);
	}
	if ([self.delegate respondsToSelector:@selector(outlineCellDidTapDisclosureButton:)]) {
		[self.delegate outlineCellDidTapDisclosureButton:self];
	}
	[UIView commitAnimations];
}

@end

