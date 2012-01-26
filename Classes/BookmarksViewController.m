//
//  BookmarksViewController.m
//  DocSets
//
//  Created by Ole Zorn on 26.01.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "BookmarksViewController.h"
#import "DetailViewController.h"
#import "DocSet.h"

@implementation BookmarksViewController

@synthesize detailViewController;

- (id)initWithDocSet:(DocSet *)selectedDocSet
{
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		self.title = NSLocalizedString(@"Bookmarks", nil);
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
			self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
			self.navigationItem.leftBarButtonItem = [self editButtonItem];
		} else {
			self.contentSizeForViewInPopover = CGSizeMake(320, 480);
			self.navigationItem.rightBarButtonItem = [self editButtonItem];
		}
		docSet = selectedDocSet;
	}
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		return YES;
	}
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)done:(id)sender
{
	[self dismissModalViewControllerAnimated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [[docSet bookmarks] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
		cell.textLabel.minimumFontSize = 13.0;
		cell.textLabel.adjustsFontSizeToFitWidth = YES;	
	}
	
	NSDictionary *bookmark = [[docSet bookmarks] objectAtIndex:indexPath.row];
	cell.textLabel.text = [bookmark objectForKey:@"title"];
    
	return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		// Delete the row from the data source
		[[docSet bookmarks] removeObjectAtIndex:indexPath.row];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
		[docSet saveBookmarks];
	}
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
	if (toIndexPath.row != fromIndexPath.row) {
		NSDictionary *movedBookmark = [[docSet bookmarks] objectAtIndex:fromIndexPath.row];
        [[docSet bookmarks] removeObjectAtIndex:fromIndexPath.row];
		if (toIndexPath.row >= [[docSet bookmarks] count]) {
			[[docSet bookmarks] addObject:movedBookmark];
        } else {
			[[docSet bookmarks] insertObject:movedBookmark atIndex:toIndexPath.row];
		}
		[docSet saveBookmarks];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSDictionary *selectedBookmark = [[docSet bookmarks] objectAtIndex:indexPath.row];
	[self.detailViewController showBookmark:selectedBookmark];
}

@end
