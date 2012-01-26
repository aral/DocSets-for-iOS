//
//  DocSetDownloadManager.m
//  DocSets
//
//  Created by Ole Zorn on 22.01.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import "DocSetDownloadManager.h"
#import "DocSet.h"
#import "xar.h"

@interface DocSetDownloadManager ()

- (void)startNextDownload;
- (void)reloadDownloadedDocSets;
- (void)downloadFinished:(DocSetDownload *)download;
- (void)downloadFailed:(DocSetDownload *)download;

@end


@implementation DocSetDownloadManager

@synthesize downloadedDocSets=_downloadedDocSets, downloadedDocSetNames=_downloadedDocSetNames, availableDownloads=_availableDownloads, currentDownload=_currentDownload;

- (id)init
{
	self = [super init];
	if (self) {
		NSString *docSetsPlistPath = [[NSBundle mainBundle] pathForResource:@"AvailableDocSets" ofType:@"plist"];
		_availableDownloads = [[NSDictionary dictionaryWithContentsOfFile:docSetsPlistPath] objectForKey:@"DocSets"];
		_downloadsByURL = [NSMutableDictionary new];
		_downloadQueue = [NSMutableArray new];
		[self reloadDownloadedDocSets];
	}
	return self;
}

- (void)reloadDownloadedDocSets
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSArray *documents = [fm contentsOfDirectoryAtPath:docPath error:NULL];
	NSMutableArray *loadedSets = [NSMutableArray array];
	for (NSString *path in documents) {
		if ([[[path pathExtension] lowercaseString] isEqual:@"docset"]) {
			NSString *fullPath = [docPath stringByAppendingPathComponent:path];
			DocSet *docSet = [[DocSet alloc] initWithPath:fullPath];
			if (docSet) [loadedSets addObject:docSet];
		}
	}
	self.downloadedDocSets = [NSArray arrayWithArray:loadedSets];
	self.downloadedDocSetNames = [NSSet setWithArray:documents];
	[[NSNotificationCenter defaultCenter] postNotificationName:DocSetDownloadManagerUpdatedDocSetsNotification object:self];
}

+ (id)sharedDownloadManager
{
	static id sharedDownloadManager = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedDownloadManager = [[self alloc] init];
	});
	return sharedDownloadManager;
}

- (DocSetDownload *)downloadForURL:(NSString *)URL
{
	return [_downloadsByURL objectForKey:URL];
}

- (void)downloadDocSetAtURL:(NSString *)URL
{
	if ([_downloadsByURL objectForKey:URL]) {
		//already downloading
		return;
	}
	
	DocSetDownload *download = [[DocSetDownload alloc] initWithURL:[NSURL URLWithString:URL]];
	[_downloadQueue addObject:download];
	[_downloadsByURL setObject:download forKey:URL];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:DocSetDownloadManagerStartedDownloadNotification object:self];
	
	[self startNextDownload];
}

- (void)deleteDocSet:(DocSet *)docSetToDelete
{
	[[NSNotificationCenter defaultCenter] postNotificationName:DocSetWillBeDeletedNotification object:docSetToDelete userInfo:nil];
	[[NSFileManager defaultManager] removeItemAtPath:docSetToDelete.path error:NULL];
	[self reloadDownloadedDocSets];
}

- (DocSet *)downloadedDocSetWithName:(NSString *)docSetName
{
	for (DocSet *docSet in _downloadedDocSets) {
		if ([[docSet.path lastPathComponent] isEqualToString:docSetName]) {
			return docSet;
		}
	}
	return nil;
}

- (void)startNextDownload
{
	if ([_downloadQueue count] == 0) {
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
		return;
	}
	if (self.currentDownload != nil) return;
	
	self.currentDownload = [_downloadQueue objectAtIndex:0];
	[_downloadQueue removeObjectAtIndex:0];
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	[self.currentDownload start];
}

- (void)downloadFinished:(DocSetDownload *)download
{
	[[NSNotificationCenter defaultCenter] postNotificationName:DocSetDownloadFinishedNotification object:download];
	
	NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSArray *extractedItems = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:download.extractedPath error:NULL];
	for (NSString *file in extractedItems) {
		if ([[[file pathExtension] lowercaseString] isEqualToString:@"docset"]) {
			NSString *fullPath = [download.extractedPath stringByAppendingPathComponent:file];
			NSString *targetPath = [docPath stringByAppendingPathComponent:file];
			[[NSFileManager defaultManager] moveItemAtPath:fullPath toPath:targetPath error:NULL];
			NSLog(@"Moved downloaded docset to %@", targetPath);
		}
	}
	
	[self reloadDownloadedDocSets];
	
	[_downloadsByURL removeObjectForKey:[download.URL absoluteString]];	
	self.currentDownload = nil;
	[self startNextDownload];
}

- (void)downloadFailed:(DocSetDownload *)download
{
	[[NSNotificationCenter defaultCenter] postNotificationName:DocSetDownloadFinishedNotification object:download];
	[_downloadsByURL removeObjectForKey:[download.URL absoluteString]];	
	self.currentDownload = nil;
	[self startNextDownload];
	
	[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Download Failed", nil) 
								 message:NSLocalizedString(@"An error occured while trying to download the DocSet.", nil) 
								delegate:nil 
					   cancelButtonTitle:NSLocalizedString(@"OK", nil) 
					   otherButtonTitles:nil] show];
}

@end



@implementation DocSetDownload

@synthesize connection=_connection, URL=_URL, fileHandle=_fileHandle, downloadTargetPath=_downloadTargetPath, extractedPath=_extractedPath, progress=_progress, status=_status;
@synthesize downloadSize, bytesDownloaded;

- (id)initWithURL:(NSURL *)URL
{
	self = [super init];
	if (self) {
		_URL = URL;
		self.status = DocSetDownloadStatusWaiting;
	}
	return self;
}

- (void)start
{
	if (self.status != DocSetDownloadStatusWaiting) {
		return;
	}
	
	_backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
	
	self.status = DocSetDownloadStatusDownloading;
	
	self.downloadTargetPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"download.xar"];
	[@"" writeToFile:self.downloadTargetPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.downloadTargetPath];
	
	bytesDownloaded = 0;
	self.connection = [NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:self.URL] delegate:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	NSDictionary *headers = [(NSHTTPURLResponse *)response allHeaderFields];
	downloadSize = [[headers objectForKey:@"Content-Length"] integerValue];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	bytesDownloaded += [data length];
	if (downloadSize != 0) {
		self.progress = (float)bytesDownloaded / (float)downloadSize;
		//NSLog(@"Download progress: %f", self.progress);
	}
	[self.fileHandle writeData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[self.fileHandle closeFile];
	self.fileHandle = nil;
	
	self.status = DocSetDownloadStatusExtracting;
	self.progress = 0.0;
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSFileManager *fm = [[NSFileManager alloc] init];
		NSString *extractionTargetPath = [[self.downloadTargetPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"xar_extract"];
		self.extractedPath = extractionTargetPath;
		[fm createDirectoryAtPath:extractionTargetPath withIntermediateDirectories:YES attributes:nil error:NULL];
		
		const char *xar_path = [self.downloadTargetPath fileSystemRepresentation];
		xar_t x = xar_open(xar_path, READ);
		
		xar_iter_t i = xar_iter_new();
		xar_file_t f = xar_file_first(x, i);
		NSInteger numberOfFiles = 1;
		do {
			f = xar_file_next(i);
			if (f != NULL) {
				numberOfFiles += 1;
			}
		} while (f != NULL);
		xar_iter_free(i);
		
		chdir([extractionTargetPath fileSystemRepresentation]);
		
		if (x == NULL) {
			NSLog(@"Could not open archive");
			[self fail];
		} else {
			xar_iter_t i = xar_iter_new();
			xar_file_t f = xar_file_first(x, i);
			NSInteger filesExtracted = 0;
			do {
				if (f) {				
					const char *name = NULL;
					xar_prop_get(f, "name", &name);
					int32_t extractResult = xar_extract(x, f);
					if (extractResult != 0) {
						NSLog(@"Could not extract file: %s", name);
					}
					f = xar_file_next(i);
					
					filesExtracted++;
					float extractionProgress = (float)filesExtracted / (float)numberOfFiles;
					dispatch_async(dispatch_get_main_queue(), ^{
						self.progress = extractionProgress;
					});
				}
			} while (f != NULL);
			xar_iter_free(i);
		}
		xar_close(x);
		
		[fm removeItemAtPath:self.downloadTargetPath error:NULL];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			self.status = DocSetDownloadStatusFinished;
			[[DocSetDownloadManager sharedDownloadManager] downloadFinished:self];
			
			if (_backgroundTask != UIBackgroundTaskInvalid) {
				[[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
			}
		});
	});
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[self fail];
}

- (void)fail
{
	[[DocSetDownloadManager sharedDownloadManager] downloadFailed:self];
	if (_backgroundTask != UIBackgroundTaskInvalid) {
		[[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
	}
}



@end