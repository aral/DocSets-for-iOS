//
//  DocSetDownloadManager.h
//  DocSets
//
//  Created by Ole Zorn on 22.01.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import <Foundation/Foundation.h>

#define DocSetDownloadManagerStartedDownloadNotification	@"DocSetDownloadManagerStartedDownloadNotification"
#define DocSetDownloadManagerUpdatedDocSetsNotification		@"DocSetDownloadManagerUpdatedDocSetsNotification"
#define DocSetDownloadFinishedNotification					@"DocSetDownloadFinishedNotification"

@class DocSet, DocSetDownload;

@interface DocSetDownloadManager : NSObject {

	NSArray *_downloadedDocSets;
	NSSet *_downloadedDocSetNames;
	
	NSArray *_availableDownloads;
	NSMutableDictionary *_downloadsByURL;
	DocSetDownload *_currentDownload;
	NSMutableArray *_downloadQueue;
}

@property (nonatomic, strong) NSArray *downloadedDocSets;
@property (nonatomic, strong) NSSet *downloadedDocSetNames;
@property (nonatomic, strong) NSArray *availableDownloads;
@property (nonatomic, strong) DocSetDownload *currentDownload;

+ (id)sharedDownloadManager;
- (void)downloadDocSetAtURL:(NSString *)URL;
- (void)deleteDocSet:(DocSet *)docSetToDelete;
- (DocSetDownload *)downloadForURL:(NSString *)URL;
- (DocSet *)downloadedDocSetWithName:(NSString *)docSetName;

@end


typedef enum DocSetDownloadStatus {
	DocSetDownloadStatusWaiting = 0,
	DocSetDownloadStatusDownloading,
	DocSetDownloadStatusExtracting,
	DocSetDownloadStatusFinished
} DocSetDownloadStatus;

@interface DocSetDownload : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {

	UIBackgroundTaskIdentifier _backgroundTask;
	NSURL *_URL;
	NSURLConnection *_connection;
	NSFileHandle *_fileHandle;
	NSString *_downloadTargetPath;
	NSString *_extractedPath;
	
	DocSetDownloadStatus _status;
	float _progress;
	NSUInteger bytesDownloaded;
	NSInteger downloadSize;
}

@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) NSURLConnection *connection;
@property (strong) NSString *downloadTargetPath;
@property (nonatomic, strong) NSString *extractedPath;
@property (nonatomic, assign) DocSetDownloadStatus status;
@property (nonatomic, assign) float progress;
@property (readonly) NSUInteger bytesDownloaded;
@property (readonly) NSInteger downloadSize;

- (id)initWithURL:(NSURL *)URL;
- (void)start;
- (void)fail;

@end