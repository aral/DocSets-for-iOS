//
//  DocPadAppDelegate.m
//  DocSets
//
//  Created by Ole Zorn on 05.12.10.
//  Copyright 2010 omz:software. All rights reserved.
//

#import "DocSetsAppDelegate.h"
#import "RootViewController.h"
#import "DetailViewController.h"
#import "SwipeSplitViewController.h"
#import "DocSetViewController.h"
#import "DocSet.h"
#import "DocSetDownloadManager.h"

@interface DocSetsAppDelegate ()

- (void)saveInterfaceState;
- (void)restoreInterfaceState;

@end


@implementation DocSetsAppDelegate

@synthesize window, splitViewController, rootViewController, detailViewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions 
{
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	
	[DocSetDownloadManager sharedDownloadManager];
	self.rootViewController = [[RootViewController alloc] initWithNibName:nil bundle:nil];
	rootNavigationController = [[UINavigationController alloc] initWithRootViewController:rootViewController];
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		self.detailViewController = [[DetailViewController alloc] initWithNibName:nil bundle:nil];
		rootViewController.detailViewController = detailViewController;
		self.splitViewController = [[SwipeSplitViewController alloc] initWithMasterViewController:rootNavigationController
																			 detailViewController:detailViewController];
		self.window.rootViewController = self.splitViewController;
	} else {
		self.window.rootViewController = rootNavigationController;
	}
	[self.window makeKeyAndVisible];
	
	[self restoreInterfaceState];
	
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	[self saveInterfaceState];
}

- (void)saveInterfaceState
{
	NSURL *currentURL = nil;
	NSMutableArray *navigationStack = [NSMutableArray array];
	for (UIViewController *vc in rootNavigationController.viewControllers) {
		if ([vc isKindOfClass:[DocSetViewController class]]) {
			DocSetViewController *docSetViewController = (DocSetViewController *)vc;
			NSMutableDictionary *stackItem = [NSMutableDictionary dictionary];
			[stackItem setObject:[docSetViewController.docSet.path lastPathComponent] 
						  forKey:@"docSetName"];
			NSManagedObject *rootNode = docSetViewController.rootNode;
			if (rootNode) {
				NSManagedObjectID *rootNodeObjectID = rootNode.objectID;
				[stackItem setObject:[rootNodeObjectID URIRepresentation] 
							  forKey:@"rootNodeID"];
			}
			[navigationStack addObject:stackItem];
		} else if ([vc isKindOfClass:[DetailViewController class]]) {
			DetailViewController *detailVC = (DetailViewController *)vc;
			currentURL = detailVC.currentURL;
		}
	}
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		currentURL = self.detailViewController.currentURL;
	}
	NSMutableDictionary *interfaceStateInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
											   navigationStack, @"navigationStack", nil];
	if (currentURL) {
		[interfaceStateInfo setObject:currentURL forKey:@"currentURL"];
	}
	NSData *interfaceStateData = [NSKeyedArchiver archivedDataWithRootObject:interfaceStateInfo];
	[[NSUserDefaults standardUserDefaults] setObject:interfaceStateData forKey:@"InterfaceState"];
}

- (void)restoreInterfaceState
{
	NSData *interfaceStateData = [[NSUserDefaults standardUserDefaults] objectForKey:@"InterfaceState"];
	if (!interfaceStateData) {
		return;
	}
	NSDictionary *interfaceStateInfo = [NSKeyedUnarchiver unarchiveObjectWithData:interfaceStateData];
	NSArray *navigationStack = [interfaceStateInfo objectForKey:@"navigationStack"];
	DocSet *selectedDocSet = nil;
	for (NSDictionary *stackItem in navigationStack) {
		NSString *docSetName = [stackItem objectForKey:@"docSetName"];
		selectedDocSet = [[DocSetDownloadManager sharedDownloadManager] downloadedDocSetWithName:docSetName];
		if (selectedDocSet) {
			NSManagedObject *rootNode = nil;
			NSURL *rootNodeObjectIDURI = [stackItem objectForKey:@"rootNodeID"];
			if (rootNodeObjectIDURI) {
				NSManagedObjectID *rootNodeObjectID = [[selectedDocSet persistentStoreCoordinator] managedObjectIDForURIRepresentation:rootNodeObjectIDURI];
				if (rootNodeObjectID) {
					rootNode = [[selectedDocSet managedObjectContext] existingObjectWithID:rootNodeObjectID error:NULL];
				}
			}
			DocSetViewController *vc = [[DocSetViewController alloc] initWithDocSet:selectedDocSet rootNode:rootNode];
			if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
				vc.detailViewController = self.detailViewController;
			}
			[rootNavigationController pushViewController:vc animated:NO];
		}
	}
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		self.detailViewController.docSet = selectedDocSet;
	}
	NSURL *currentURL = [interfaceStateInfo objectForKey:@"currentURL"];
	if (currentURL) {
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
			[self.detailViewController openURL:currentURL withAnchor:nil];
		} else {
			DetailViewController *vc = [[DetailViewController alloc] initWithNibName:nil bundle:nil];
			[rootNavigationController pushViewController:vc animated:NO];
			vc.docSet = selectedDocSet;
			[vc view];
			[vc openURL:currentURL withAnchor:nil];
		}
	}
}

@end

