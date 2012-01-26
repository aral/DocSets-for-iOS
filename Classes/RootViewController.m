//
//  RootViewController.m
//  DocSets
//
//  Created by Ole Zorn on 05.12.10.
//  Copyright 2010 omz:software. All rights reserved.
//

#import "RootViewController.h"
#import "DetailViewController.h"
#import "DocSetViewController.h"
#import "DownloadViewController.h"
#import "DocSetDownloadManager.h"
#import "DocSet.h"

@implementation RootViewController

@synthesize detailViewController;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nil bundle:nil];
	self.title = NSLocalizedString(@"DocSets",nil);
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(docSetsChanged:) name:DocSetDownloadManagerUpdatedDocSetsNotification object:nil];
	return self;
}

- (void)viewDidLoad 
{
	[super viewDidLoad];
	self.tableView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
	self.clearsSelectionOnViewWillAppear = YES;
	self.contentSizeForViewInPopover = CGSizeMake(400.0, 1024.0);
	self.tableView.rowHeight = 64.0;
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addDocSet:)];
	self.navigationItem.rightBarButtonItem = [self editButtonItem];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		return YES;
	}
	return interfaceOrientation == UIInterfaceOrientationPortrait;
}

#pragma mark -

- (void)addDocSet:(id)sender
{
	DownloadViewController *vc = [[DownloadViewController alloc] initWithStyle:UITableViewStyleGrouped];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:vc];
	navController.modalPresentationStyle = UIModalPresentationFormSheet;
	[self presentModalViewController:navController animated:YES];
}

- (void)docSetsChanged:(NSNotification *)notification
{
	if (!self.editing) {
		[self.tableView reloadData];
	}
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView 
{
	return 1;
}


- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section 
{
	return [[[DocSetDownloadManager sharedDownloadManager] downloadedDocSets] count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{    
	static NSString *CellIdentifier = @"CellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.imageView.image = [UIImage imageNamed:@"DocSet.png"];
    }
    
	DocSet *docSet = [[[DocSetDownloadManager sharedDownloadManager] downloadedDocSets] objectAtIndex:indexPath.row];
	cell.textLabel.text = docSet.title;
	cell.detailTextLabel.text = docSet.copyright;
	
	return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		DocSet *docSetToDelete = [[[DocSetDownloadManager sharedDownloadManager] downloadedDocSets] objectAtIndex:indexPath.row];
		[[DocSetDownloadManager sharedDownloadManager] deleteDocSet:docSetToDelete];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
	}
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	DocSet *selectedDocSet = [[[DocSetDownloadManager sharedDownloadManager] downloadedDocSets] objectAtIndex:indexPath.row];
	DocSetViewController *docSetViewController = [[DocSetViewController alloc] initWithDocSet:selectedDocSet rootNode:nil];
	docSetViewController.detailViewController = self.detailViewController;
	[self.navigationController pushViewController:docSetViewController animated:YES];
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && !self.detailViewController.docSet) {
		//enables the bookmarks button
		self.detailViewController.docSet = selectedDocSet;
	}
}

#pragma mark -

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end

