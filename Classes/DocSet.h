//
//  DocSet.h
//  DocSets
//
//  Created by Ole Zorn on 05.12.10.
//  Copyright 2010 omz:software. All rights reserved.
//

#import <Foundation/Foundation.h>

#define DocSetWillBeDeletedNotification		@"DocSetWillBeDeletedNotification"

#define kNodeSectionNodes					@"nodes"
#define kNodeSectionTitle					@"title"

typedef void(^DocSetSearchCompletionHandler)(NSString *searchTerm, NSArray *results);

@interface DocSet : NSObject {

	NSString *path;
	NSString *title;
	NSString *copyright;
	NSURL *fallbackURL;
	
	NSManagedObjectContext *managedObjectContext;
	NSPersistentStoreCoordinator *persistentStoreCoordinator;
	
	dispatch_queue_t searchQueue;
	BOOL loadingTokens;
	NSArray *tokens;
	NSArray *nodeInfos;
	
	NSMutableArray *bookmarks;
}

@property (nonatomic, strong, readonly) NSString *path;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *copyright;
@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, strong, readonly) NSMutableArray *bookmarks;

- (id)initWithPath:(NSString *)docSetPath;
- (NSArray *)nodeSectionsForRootNode:(NSManagedObject *)rootNode;
- (BOOL)nodeIsExpandable:(NSManagedObject *)node;
- (void)saveBookmarks;
- (void)prepareSearch;
- (void)searchForNodesMatching:(NSString *)searchTerm completion:(DocSetSearchCompletionHandler)completion;
- (void)searchForTokensMatching:(NSString *)searchTerm completion:(DocSetSearchCompletionHandler)completion;

- (NSURL *)URLForNode:(NSManagedObject *)node;
- (NSURL *)webURLForNode:(NSManagedObject *)node;
- (NSURL *)webURLForLocalURL:(NSURL *)localURL;

@end
