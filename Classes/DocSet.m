//
//  DocSet.m
//  DocSets
//
//  Created by Ole Zorn on 05.12.10.
//  Copyright 2010 omz:software. All rights reserved.
//

#import "DocSet.h"


@implementation DocSet

@synthesize path, title, copyright, bookmarks;

- (id)initWithPath:(NSString *)docSetPath
{
	self = [super init];
	
	path = docSetPath;
	
	NSString *infoPath = [path stringByAppendingPathComponent:@"Contents/Info.plist"];
	NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
	title = [info objectForKey:@"CFBundleName"];
	fallbackURL = [NSURL URLWithString:[info objectForKey:@"DocSetFallbackURL"]];
	if (title) {
		copyright = [info objectForKey:@"NSHumanReadableCopyright"];
		if (!copyright) copyright = @"";
	} else {
		self = nil;
	}
		
	searchQueue = dispatch_queue_create("DocSet Search Queue", NULL);
	
	return self;
}

- (NSMutableArray *)bookmarks
{
	//load bookmarks lazily:
	if (!bookmarks) {
		NSString *bookmarksPath = [path stringByAppendingPathComponent:@"Bookmarks.plist"];
		bookmarks = [NSMutableArray arrayWithContentsOfFile:bookmarksPath];
		if (!bookmarks) {
			bookmarks = [NSMutableArray array];
		}
	}
	return bookmarks;
}

- (void)saveBookmarks
{
	NSString *bookmarksPath = [path stringByAppendingPathComponent:@"Bookmarks.plist"];
	[[self bookmarks] writeToFile:bookmarksPath atomically:YES];
}

- (void)prepareSearch
{
	if (!tokens && !loadingTokens) {
		loadingTokens = YES;
		NSPersistentStoreCoordinator *psc = [self persistentStoreCoordinator];
		dispatch_async(searchQueue, ^{
			
			NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] init];
			[moc setPersistentStoreCoordinator:psc];
			
			NSEntityDescription *tokenEntity = [NSEntityDescription entityForName:@"Token" inManagedObjectContext:moc];
			NSFetchRequest *allTokensRequest = [[NSFetchRequest alloc] init];
			[allTokensRequest setEntity:tokenEntity];
			[allTokensRequest setPredicate:[NSPredicate predicateWithFormat:@"tokenType.typeName != 'writerid' AND parentNode.installDomain == 1"]];
			[allTokensRequest setSortDescriptors:[NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"tokenName" ascending:YES]]];
			[allTokensRequest setResultType:NSDictionaryResultType];
			
			[allTokensRequest setPropertiesToFetch:[NSArray arrayWithObjects:
													[[tokenEntity attributesByName] objectForKey:@"tokenName"], 
													[[tokenEntity relationshipsByName] objectForKey:@"tokenType"], 
													[[tokenEntity relationshipsByName] objectForKey:@"metainformation"], 
													[[tokenEntity relationshipsByName] objectForKey:@"parentNode"], 
													nil]];
			NSArray *loadedTokens = [moc executeFetchRequest:allTokensRequest error:NULL];
			
			NSEntityDescription *nodeEntity = [NSEntityDescription entityForName:@"Node" inManagedObjectContext:moc];
			NSFetchRequest *allNodesRequest = [[NSFetchRequest alloc] init];
			[allNodesRequest setEntity:nodeEntity];
			[allNodesRequest setPredicate:[NSPredicate predicateWithFormat:@"installDomain == 1"]];
			[allNodesRequest setSortDescriptors:[NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"kName" ascending:YES]]];
			[allNodesRequest setResultType:NSDictionaryResultType];
			
			NSExpressionDescription* objectIdDesc = [[NSExpressionDescription alloc] init];
			objectIdDesc.name = @"objectID";
			objectIdDesc.expression = [NSExpression expressionForEvaluatedObject];
			objectIdDesc.expressionResultType = NSObjectIDAttributeType;
			
			[allNodesRequest setPropertiesToFetch:[NSArray arrayWithObjects:
												   [[nodeEntity attributesByName] objectForKey:@"kName"], 
												   objectIdDesc,
													nil]];
			
			NSArray *loadedNodes = [moc executeFetchRequest:allNodesRequest error:NULL];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				loadingTokens = NO;
				tokens = loadedTokens;
				nodeInfos = loadedNodes;
			});
		});
	}
}


- (void)searchForNodesMatching:(NSString *)searchTerm completion:(DocSetSearchCompletionHandler)completion
{
	if (searchTerm.length == 0) {
		completion(searchTerm, [NSArray array]);
		return;
	}
	
	dispatch_async(searchQueue, ^{
		NSArray *terms = [searchTerm componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		terms = [terms filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length != 0"]];
		NSMutableArray *results = [NSMutableArray array];
		for (NSDictionary *nodeInfo in nodeInfos) {
			NSString *nodeTitle = [nodeInfo objectForKey:@"kName"];
			BOOL allMatched = YES;
			NSUInteger minLocation = WINT_MAX;
			for (NSString *term in terms) {
				NSRange range = [nodeTitle rangeOfString:term options:NSCaseInsensitiveSearch];
				if (range.location != NSNotFound) {
					allMatched = YES;
					minLocation = MIN(range.location, minLocation);
				} else {
					allMatched = NO;
					break;
				}
			}
			if (allMatched) {
				[results addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									nodeInfo, @"node",
									nodeTitle, @"title",
									[NSNumber numberWithInteger:minLocation], @"location",
									nil]];
			}
		}
		//Sort results first by the position of the search term in the title, then alphabetically.
		//This ensures that a search for e.g. "NSString" will return "NSString" before "CFStringConvertEncodingToNSString...".
		NSArray *sortedResults = [results sortedArrayUsingDescriptors:[NSArray arrayWithObjects:
																	   [[NSSortDescriptor alloc] initWithKey:@"location" ascending:YES],
																	   [[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES selector:@selector(caseInsensitiveCompare:)],
																	   nil]];
		
		completion(searchTerm, [sortedResults valueForKey:@"node"]);
	});
}

- (void)searchForTokensMatching:(NSString *)searchTerm completion:(DocSetSearchCompletionHandler)completion
{
	if (searchTerm.length == 0) {
		completion(searchTerm, [NSArray array]);
		return;
	}
	
	dispatch_async(searchQueue, ^{
		int maxNumberOfResults = 1000;
		NSMutableArray *results = [NSMutableArray array];
		//Do a simpler prefix search for very short search terms. Otherwise, too many irrelevant results would
		//clutter the results and most of the relevant results would probably not be returned at all, because
		//the maxNumberOfResults is already reached...
		BOOL prefixSearch = searchTerm.length < 3;
		for (NSDictionary *token in tokens) {
			NSString *tokenName = [token objectForKey:@"tokenName"];
			if (prefixSearch) {
				NSRange range = [tokenName rangeOfString:searchTerm options:NSCaseInsensitiveSearch];
				if (range.location == 0) {
					[results addObject:[NSDictionary dictionaryWithObjectsAndKeys:
										token, @"token",
										tokenName, @"tokenName",
										nil]];
				}
			} else {
				NSRange range = [tokenName rangeOfString:searchTerm options:NSCaseInsensitiveSearch];
				if (range.location != NSNotFound) {
					[results addObject:[NSDictionary dictionaryWithObjectsAndKeys:
										token, @"token",
										tokenName, @"tokenName",
										[NSNumber numberWithInteger:range.location], @"location",
										nil]];
				}
			}
			if (maxNumberOfResults > 0 && [results count] > maxNumberOfResults) break;
		}
		NSArray *sortedResults = nil;
		if (prefixSearch) {
			//Tokens are already sorted alphabetically...
			sortedResults = results;
		} else {
			//Sort results first by the position of the search term in the token name, then by token name.
			//This ensures that a search for e.g. "NSString" will return "NSString" before "CFStringConvertEncodingToNSString..."
			sortedResults = [results sortedArrayUsingDescriptors:[NSArray arrayWithObjects:
																  [[NSSortDescriptor alloc] initWithKey:@"location" ascending:YES],
																  [[NSSortDescriptor alloc] initWithKey:@"tokenName" ascending:YES selector:@selector(caseInsensitiveCompare:)],
																  nil]];
		}
		completion(searchTerm, [sortedResults valueForKey:@"token"]);
	});
}

- (NSArray *)nodeSectionsForRootNode:(NSManagedObject *)rootNode
{
	if (!rootNode) {
		NSManagedObjectContext *moc = [self managedObjectContext];
		NSFetchRequest *rootNodeRequest = [NSFetchRequest fetchRequestWithEntityName:@"Node"];
		[rootNodeRequest setPredicate:[NSPredicate predicateWithFormat:@"kIsSearchable == 0 AND primaryParent == nil"]];
		[rootNodeRequest setSortDescriptors:[NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"kName" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
		NSArray *rootNodes = [moc executeFetchRequest:rootNodeRequest error:NULL];
		NSMutableArray *sections = [NSMutableArray array];
		for (NSManagedObject *rootNode in rootNodes) {
			NSArray *subnodes = [[rootNode valueForKey:@"orderedSubnodes"] sortedArrayUsingDescriptors:
								  [NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES]]];
			
			NSMutableArray *nodes = [NSMutableArray array];
			
			for (NSManagedObject *orderedNode in subnodes) {
				[nodes addObject:[orderedNode valueForKeyPath:@"node"]];
			}
			NSDictionary *section = [NSDictionary dictionaryWithObjectsAndKeys:
									 nodes, kNodeSectionNodes,
									 [rootNode valueForKey:@"kName"], kNodeSectionTitle,
									 nil];
			[sections addObject:section];
		}
		return sections;
	
	} else {
		NSArray *subnodes = [[[rootNode valueForKey:@"orderedSubnodes"] sortedArrayUsingDescriptors:
							  [NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES]]] valueForKey:@"node"];
		
		NSMutableArray *folderNodes = [NSMutableArray array];
		NSMutableArray *guideNodes = [NSMutableArray array];
		NSMutableArray *referenceNodes = [NSMutableArray array];
		NSMutableArray *sampleCodeNodes = [NSMutableArray array];
		NSMutableArray *otherNodes = [NSMutableArray array];
		
		for (NSManagedObject *node in subnodes) {
			BOOL expandable = [self nodeIsExpandable:node];
			if (expandable) {
				[folderNodes addObject:node];
			} else {
				int documentType = [[node valueForKey:@"kDocumentType"] intValue];
				if (documentType == 0) {
					[guideNodes addObject:node];
				} else if (documentType == 1) {
					[sampleCodeNodes addObject:node];
				} else if (documentType == 2) {
					[referenceNodes addObject:node];
				} else {
					[otherNodes addObject:node];
				}
			}
		}
		
		NSMutableArray *sections = [NSMutableArray array];
		
		if ([folderNodes count] > 0) [sections addObject:[NSDictionary dictionaryWithObjectsAndKeys:folderNodes, kNodeSectionNodes, nil]];
		if ([guideNodes count] > 0) [sections addObject:[NSDictionary dictionaryWithObjectsAndKeys:guideNodes, kNodeSectionNodes, NSLocalizedString(@"Guides / Articles",nil), kNodeSectionTitle,  nil]];
		if ([referenceNodes count] > 0) [sections addObject:[NSDictionary dictionaryWithObjectsAndKeys:referenceNodes, kNodeSectionNodes, NSLocalizedString(@"Reference",nil), kNodeSectionTitle,  nil]];
		if ([sampleCodeNodes count] > 0) [sections addObject:[NSDictionary dictionaryWithObjectsAndKeys:sampleCodeNodes, kNodeSectionNodes, NSLocalizedString(@"Sample Code",nil), kNodeSectionTitle,  nil]];
		if ([otherNodes count] > 0) [sections addObject:[NSDictionary dictionaryWithObjectsAndKeys:otherNodes, kNodeSectionNodes, NSLocalizedString(@"Others",nil), kNodeSectionTitle,  nil]];
		
		return [NSArray arrayWithArray:sections];
	}
	return nil;
}


- (NSURL *)URLForNode:(NSManagedObject *)node
{
	NSString *nodePath = [node valueForKey:@"kPath"];
	NSString *fullPath = [[path stringByAppendingPathComponent:@"Contents/Resources/Documents"] stringByAppendingPathComponent:nodePath];
	NSURL *URL = [NSURL fileURLWithPath:fullPath];
	
	return URL;
}

- (NSURL *)webURLForNode:(NSManagedObject *)node
{
	return [fallbackURL URLByAppendingPathComponent:[node valueForKey:@"kPath"]];
}



- (NSURL *)webURLForLocalURL:(NSURL *)localURL
{
	NSString *URLString = [localURL absoluteString];
	NSUInteger anchorLocation = [URLString rangeOfString:@"#"].location;
	NSString *anchor = nil;
	if (anchorLocation != NSNotFound) {
		anchor = [URLString substringFromIndex:anchorLocation];
		URLString = [URLString substringToIndex:anchorLocation];
	}
	if ([[URLString lowercaseString] hasSuffix:@"__cached__.html"]) {
		URLString = [[URLString substringToIndex:URLString.length - [@"__cached__.html" length]] stringByAppendingFormat:@".html"];
	}
	if (anchor) {
		URLString = [URLString stringByAppendingString:anchor];
	}
	NSRange prefixRange = [URLString rangeOfString:@"Contents/Resources/Documents/"];
	NSString *URLPath = [URLString substringFromIndex:prefixRange.location + prefixRange.length];
	NSURL *webURL = [NSURL URLWithString:[[fallbackURL absoluteString] stringByAppendingFormat:@"/%@", URLPath]];
	return webURL;
}

- (BOOL)nodeIsExpandable:(NSManagedObject *)node
{
	int numberOfSubnodes = [[node valueForKey:@"kSubnodeCount"] intValue];
	if (numberOfSubnodes == 0) return NO;
	
	NSURL *nodeURL = [self URLForNode:node];
	NSURL *bookURL = [[nodeURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"book.json"];
	if ([[NSFileManager defaultManager] fileExistsAtPath:[bookURL path]]) {
		return NO;
	}
	return YES;
}

- (NSManagedObjectContext *)managedObjectContext
{
	if (!managedObjectContext) {
		managedObjectContext = [[NSManagedObjectContext alloc] init];
		[managedObjectContext setPersistentStoreCoordinator:[self persistentStoreCoordinator]];
	}
	return managedObjectContext;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
	if (!persistentStoreCoordinator) {
		NSURL *storeURL = [NSURL fileURLWithPath:[path stringByAppendingPathComponent:@"Contents/Resources/docSet.dsidx"]];
		NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"docSet" withExtension:@"mom"];
		NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
		
		persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
		[persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType 
												 configuration:nil 
														   URL:storeURL 
													   options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:NSReadOnlyPersistentStoreOption] 
														 error:NULL];
	}
	return persistentStoreCoordinator;
}

- (void)dealloc
{
	dispatch_release(searchQueue);
}

@end
