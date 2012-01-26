//
//  DocSetViewController.m
//  DocSets
//
//  Created by Ole Zorn on 05.12.10.
//  Copyright 2010 omz:software. All rights reserved.
//

#import "DocSetViewController.h"
#import "DocSet.h"
#import "DetailViewController.h"

#define SEARCH_SPINNER_TAG	1

@interface DocSetViewController ()

- (void)reloadSearchResults;
- (void)openNode:(NSManagedObject *)node;

@end


@implementation DocSetViewController

@synthesize docSet, rootNode, detailViewController, searchResults, searchDisplayController;

- (id)initWithDocSet:(DocSet *)set rootNode:(NSManagedObject *)node
{
	self = [super initWithStyle:UITableViewStylePlain];
	
	docSet = set;
	rootNode = node;
	nodeSections = [docSet nodeSectionsForRootNode:rootNode];
	
	self.title = (rootNode != nil) ? [rootNode valueForKey:@"kName"] : docSet.title;
	self.contentSizeForViewInPopover = CGSizeMake(400.0, 1024.0);
	
	iconsByTokenType = [[NSDictionary alloc] initWithObjectsAndKeys:
						[UIImage imageNamed:@"Const"], @"econst",
						[UIImage imageNamed:@"Member.png"], @"intfm",
						[UIImage imageNamed:@"Macro.png"], @"macro",
						[UIImage imageNamed:@"Type.png"], @"tdef",
						[UIImage imageNamed:@"Class.png"], @"cat",
						[UIImage imageNamed:@"Property.png"], @"intfp",
						[UIImage imageNamed:@"Const.png"], @"clconst",
						[UIImage imageNamed:@"Protocol.png"], @"intf",
						[UIImage imageNamed:@"Member.png"], @"instm",
						[UIImage imageNamed:@"Class.png"], @"cl",
						[UIImage imageNamed:@"Struct.png"], @"tag",
						[UIImage imageNamed:@"Member.png"], @"clm",
						[UIImage imageNamed:@"Property.png"], @"instp",
						[UIImage imageNamed:@"Function.png"], @"func",
						[UIImage imageNamed:@"Global.png"], @"data",
						nil];
	
	self.clearsSelectionOnViewWillAppear = YES;
		
	return self;
}

- (void)loadView
{
	[super loadView];
	
	UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
	searchBar.scopeButtonTitles = [NSArray arrayWithObjects:NSLocalizedString(@"API",nil), NSLocalizedString(@"Title",nil), nil];
	searchBar.selectedScopeButtonIndex = 0;
	searchBar.showsScopeBar = NO;
	self.tableView.tableHeaderView = searchBar;
	
	self.tableView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
	
	self.searchDisplayController = [[UISearchDisplayController alloc] initWithSearchBar:searchBar contentsController:self];
	searchDisplayController.delegate = self;
	searchDisplayController.searchResultsDataSource = self;
	searchDisplayController.searchResultsDelegate = self;
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	if (!self.navigationController.toolbarHidden) {
		[self.navigationController setToolbarHidden:YES animated:animated];
	}
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[self.searchDisplayController.searchBar resignFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		return YES;
	}
	return interfaceOrientation == UIInterfaceOrientationPortrait;
}

#pragma mark - Search

- (void)searchDisplayControllerDidBeginSearch:(UISearchDisplayController *)controller
{
	[docSet prepareSearch];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption
{
	self.searchResults = nil;
	[self reloadSearchResults];
	return YES;
}

- (void)searchDisplayController:(UISearchDisplayController *)controller didLoadSearchResultsTableView:(UITableView *)searchResultsTableView
{
	searchResultsTableView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
}

- (void)searchDisplayController:(UISearchDisplayController *)controller didHideSearchResultsTableView:(UITableView *)tableView
{
	self.searchResults = nil;
	[self.searchDisplayController.searchResultsTableView reloadData];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
	if (searchString.length == 0) {
		self.searchResults = nil;
		return YES;
	} else {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadSearchResults) object:nil];
		[self performSelector:@selector(reloadSearchResults) withObject:nil afterDelay:0.2];
		return (self.searchResults == nil);
	}
}

- (void)reloadSearchResults
{
	NSString *searchTerm = self.searchDisplayController.searchBar.text;
	DocSetSearchCompletionHandler completionHandler = ^(NSString *completedSearchTerm, NSArray *results) {
		dispatch_async(dispatch_get_main_queue(), ^{
			NSString *currentSearchTerm = self.searchDisplayController.searchBar.text;
			if ([currentSearchTerm isEqualToString:completedSearchTerm]) {
				self.searchResults = results;
				[self.searchDisplayController.searchResultsTableView reloadData];
			}
		});
	};
	
	if (self.searchDisplayController.searchBar.selectedScopeButtonIndex == 0) {
		[docSet searchForTokensMatching:searchTerm completion:completionHandler];
	} else {
		[docSet searchForNodesMatching:searchTerm completion:completionHandler];
	}	
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView 
{
	if (aTableView == self.tableView) {
		return [nodeSections count];
	} else if (aTableView == self.searchDisplayController.searchResultsTableView) {
		return 1;
	}
	return 0;
}

- (NSString *)tableView:(UITableView *)aTableView titleForHeaderInSection:(NSInteger)section
{
	if (aTableView == self.tableView) {
		NSDictionary *nodeSection = [nodeSections objectAtIndex:section];
		return [nodeSection objectForKey:kNodeSectionTitle];
	}
	return nil;
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section 
{
	if (aTableView == self.tableView) {
		return [[[nodeSections objectAtIndex:section] objectForKey:kNodeSectionNodes] count];
	} else if (aTableView == self.searchDisplayController.searchResultsTableView) {
		if (!self.searchResults) {
			return 1;
		} else {
			return [searchResults count];
		}
	}
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *CellIdentifier = @"Cell";
	UITableViewCell *cell = [aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
		cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0];
	}
	
	if (aTableView == self.tableView) {
		NSDictionary *nodeSection = [nodeSections objectAtIndex:indexPath.section];
		NSManagedObject *node = [[nodeSection objectForKey:kNodeSectionNodes] objectAtIndex:indexPath.row];
		
		BOOL expandable = [docSet nodeIsExpandable:node];
		cell.accessoryType = (expandable) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
		
		if ([[node valueForKey:@"installDomain"] intValue] > 1) {
			//external link, e.g. man pages
			cell.textLabel.textColor = [UIColor grayColor];
		} else {
			cell.textLabel.textColor = [UIColor blackColor];
		}
		
		int documentType = [[node valueForKey:@"kDocumentType"] intValue];
		if (documentType == 1) {
			cell.imageView.image = [UIImage imageNamed:@"SampleCodeIcon.png"];
		} else if (documentType == 2) {
			cell.imageView.image = [UIImage imageNamed:@"ReferenceIcon.png"];
		} else if (!expandable) {
			cell.imageView.image = [UIImage imageNamed:@"BookIcon.png"];
		} else {
			cell.imageView.image = nil;
		}
		
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		cell.textLabel.text = [node valueForKey:@"kName"];
		cell.detailTextLabel.text = nil;
		cell.accessoryView = nil;
		return cell;
	} else if (aTableView == self.searchDisplayController.searchResultsTableView) {
		if (!self.searchResults) {
			cell.textLabel.text = NSLocalizedString(@"Searching...", nil);
			cell.textLabel.textColor = [UIColor grayColor];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			cell.imageView.image = nil;
			UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			[spinner startAnimating];
			cell.accessoryView = spinner;
		} else {
			cell.textLabel.textColor = [UIColor blackColor];
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
			cell.accessoryView = nil;
			NSDictionary *result = [searchResults objectAtIndex:indexPath.row];
			if ([result objectForKey:@"tokenType"]) {
				NSManagedObjectID *tokenTypeID = [result objectForKey:@"tokenType"];
				if (tokenTypeID) {
					NSManagedObject *tokenType = [[docSet managedObjectContext] existingObjectWithID:tokenTypeID error:NULL];
					NSString *tokenTypeName = [tokenType valueForKey:@"typeName"];
					UIImage *icon = [iconsByTokenType objectForKey:tokenTypeName];
					cell.imageView.image = icon;
				} else {
					cell.imageView.image = nil;
				}
				
				NSManagedObjectID *parentNodeID = [result objectForKey:@"parentNode"];
				if (parentNodeID) {
					NSManagedObject *parentNode = [[docSet managedObjectContext] existingObjectWithID:parentNodeID error:NULL];
					NSString *parentNodeTitle = [parentNode valueForKey:@"kName"];
					cell.detailTextLabel.text = parentNodeTitle;
				} else {
					cell.detailTextLabel.text = nil;
				}
				
				cell.textLabel.text = [result objectForKey:@"tokenName"];
				cell.accessoryType = UITableViewCellAccessoryNone;
			} else {
				cell.textLabel.text = [result objectForKey:@"kName"];
				NSManagedObjectID *objectID = [result objectForKey:@"objectID"];
				
				NSManagedObject *node = [[docSet managedObjectContext] existingObjectWithID:objectID error:NULL];
			
				BOOL expandable = [docSet nodeIsExpandable:node];
				cell.accessoryType = (expandable) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
			
				int documentType = [[node valueForKey:@"kDocumentType"] intValue];
				if (documentType == 1) {
					cell.imageView.image = [UIImage imageNamed:@"SampleCodeIcon.png"];
				} else if (documentType == 2) {
					cell.imageView.image = [UIImage imageNamed:@"ReferenceIcon.png"];
				} else if (!expandable) {
					cell.imageView.image = [UIImage imageNamed:@"BookIcon.png"];
				} else {
					cell.imageView.image = nil;
				}
				cell.detailTextLabel.text = nil;
			
			}
		}
		return cell;
	}
	return nil;
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (aTableView == self.tableView) {
		NSDictionary *nodeSection = [nodeSections objectAtIndex:indexPath.section];
		NSManagedObject *node = [[nodeSection objectForKey:kNodeSectionNodes] objectAtIndex:indexPath.row];
		[self openNode:node];
	} else if (aTableView == self.searchDisplayController.searchResultsTableView) {
		[self.searchDisplayController.searchBar resignFirstResponder];
		NSDictionary *result = [searchResults objectAtIndex:indexPath.row];
		if ([result objectForKey:@"tokenType"]) {
			if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
				[self.detailViewController showToken:result inDocSet:docSet];
			} else {
				self.detailViewController = [[DetailViewController alloc] initWithNibName:nil bundle:nil];
				[self.navigationController pushViewController:self.detailViewController animated:YES];
				[self.detailViewController showToken:result inDocSet:docSet];
			}
		} else {
			NSManagedObject *node = [[docSet managedObjectContext] existingObjectWithID:[result objectForKey:@"objectID"] error:NULL];
			[self openNode:node];
		}
	}
}

- (void)openNode:(NSManagedObject *)node
{
	BOOL expandable = [docSet nodeIsExpandable:node];
	if (expandable) {
		DocSetViewController *childViewController = [[DocSetViewController alloc] initWithDocSet:docSet rootNode:node];
		childViewController.detailViewController = self.detailViewController;
		[self.navigationController pushViewController:childViewController animated:YES];
	} else {
		
		if ([[node valueForKey:@"installDomain"] intValue] > 1) {
			NSURL *webURL = [docSet webURLForNode:node];
			[[UIApplication sharedApplication] openURL:webURL];
			return;
		}
		
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
			[self.detailViewController showNode:node inDocSet:docSet];
		} else {
			self.detailViewController = [[DetailViewController alloc] initWithNibName:nil bundle:nil];
			[self.navigationController pushViewController:self.detailViewController animated:YES];
			[self.detailViewController showNode:node inDocSet:docSet];
		}
	}
}

#pragma mark -

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end

