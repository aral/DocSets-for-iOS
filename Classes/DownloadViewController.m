//
//  DownloadViewController.m
//  DocSets
//
//  Created by Ole Zorn on 22.01.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import "DownloadViewController.h"
#import "DocSetDownloadManager.h"

@implementation DownloadViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
		self.title = NSLocalizedString(@"Download", nil);
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(docSetsChanged:) name:DocSetDownloadManagerUpdatedDocSetsNotification object:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.tableView.rowHeight = 64.0;
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		return YES;
	}
	return interfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void)docSetsChanged:(NSNotification *)notification
{
	[self.tableView reloadData];
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
	return [[[DocSetDownloadManager sharedDownloadManager] availableDownloads] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    DownloadCell *cell = (DownloadCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
		cell = [[DownloadCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
		cell.detailTextLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
    }
	
    NSDictionary *downloadInfo = [[[DocSetDownloadManager sharedDownloadManager] availableDownloads] objectAtIndex:indexPath.row];
	cell.downloadInfo = downloadInfo;
	/*
	cell.textLabel.text = [downloadInfo objectForKey:@"title"];
	cell.detailTextLabel.text = [downloadInfo objectForKey:@"URL"];
    cell.imageView.image = [UIImage imageNamed:@"DocSet.png"];
	*/
	
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	NSDictionary *downloadInfo = [[[DocSetDownloadManager sharedDownloadManager] availableDownloads] objectAtIndex:indexPath.row];
	
	NSString *name = [downloadInfo objectForKey:@"name"];
	BOOL downloaded = [[[DocSetDownloadManager sharedDownloadManager] downloadedDocSetNames] containsObject:name];
	if (downloaded) {
		[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Already Downloaded", nil) 
									 message:NSLocalizedString(@"You have already downloaded this DocSet.", nil) 
									delegate:nil 
						   cancelButtonTitle:NSLocalizedString(@"OK", nil) 
						   otherButtonTitles:nil] show];
	} else {
		NSString *docSetURL = [downloadInfo objectForKey:@"URL"];
		[[DocSetDownloadManager sharedDownloadManager] downloadDocSetAtURL:docSetURL];
	}
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end



@implementation DownloadCell

@synthesize downloadInfo=_downloadInfo, download=_download, progressView=_progressView;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadStarted:) name:DocSetDownloadManagerStartedDownloadNotification object:nil];
		_progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
		CGRect pFrame = _progressView.frame;
		pFrame.size.width = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) ? 120 : 70;
		_progressView.frame = pFrame;
	}
	return self;
}

- (void)downloadStarted:(NSNotification *)notification
{
	if (!self.download) {
		self.download = [[DocSetDownloadManager sharedDownloadManager] downloadForURL:[self.downloadInfo objectForKey:@"URL"]];
	}
}

- (void)downloadFinished:(NSNotification *)notification
{
	if (notification.object == self.download) {
		self.download = nil;
	}
}

- (void)setDownloadInfo:(NSDictionary *)downloadInfo
{
	_downloadInfo = downloadInfo;
	NSString *URL = [_downloadInfo objectForKey:@"URL"];
	NSString *name = [_downloadInfo objectForKey:@"name"];
	BOOL downloaded = [[[DocSetDownloadManager sharedDownloadManager] downloadedDocSetNames] containsObject:name];
	if (downloaded) {
		self.textLabel.textColor = [UIColor grayColor];
	} else {
		self.textLabel.textColor = [UIColor blackColor];
	}
	self.download = [[DocSetDownloadManager sharedDownloadManager] downloadForURL:URL];
	
	self.textLabel.text = [_downloadInfo objectForKey:@"title"];
	self.imageView.image = [UIImage imageNamed:@"DocSet.png"];
}

- (void)setDownload:(DocSetDownload *)download
{
	if (_download) {
		[_download removeObserver:self forKeyPath:@"progress"];
		[_download removeObserver:self forKeyPath:@"status"];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:DocSetDownloadFinishedNotification object:_download];
	}
	
	_download = download;
	[_download addObserver:self forKeyPath:@"progress" options:NSKeyValueObservingOptionNew context:nil];
	[_download addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadFinished:) name:DocSetDownloadFinishedNotification object:_download];
	
	if (_download) {
		self.progressView.progress = self.download.progress;
		self.accessoryView = self.progressView;
	} else {
		self.accessoryView = nil;
	}
	[self updateStatusLabel];
}

- (void)updateStatusLabel
{
	if (!self.download) {
		self.detailTextLabel.text = nil;
	} else if (self.download.status == DocSetDownloadStatusWaiting) {
		self.detailTextLabel.text = NSLocalizedString(@"Waiting...", nil);
	} else if (self.download.status == DocSetDownloadStatusDownloading) {
		NSInteger downloadSize = self.download.downloadSize;
		NSUInteger bytesDownloaded = self.download.bytesDownloaded;
		if (downloadSize != 0) {
			NSString *totalMegabytes = [NSString stringWithFormat:@"%.01f", (float)(downloadSize / pow(2, 20))];
			NSString *downloadedMegabytes = [NSString stringWithFormat:@"%.01f", (float)(bytesDownloaded / pow(2, 20))];
			if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
				self.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Downloading... (%@ MB / %@ MB)", nil), downloadedMegabytes, totalMegabytes];
			} else {
				self.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@ MB / %@ MB", nil), downloadedMegabytes, totalMegabytes];
			}
		} else {
			self.detailTextLabel.text = NSLocalizedString(@"Downloading...", nil);
		}
	} else if (self.download.status == DocSetDownloadStatusExtracting) {
		int extractedPercentage = (int)(self.download.progress * 100);
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
			self.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Extracting Download... (%i%%)", nil), extractedPercentage];
		} else {
			self.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Extracting (%i%%)", nil), extractedPercentage];
		}
	} else {
		self.detailTextLabel.text = nil;
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"progress"]) {
		self.progressView.progress = self.download.progress;
		[self updateStatusLabel];
	} else if ([keyPath isEqualToString:@"status"]) {
		[self updateStatusLabel];
	}
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_download removeObserver:self forKeyPath:@"progress"];
	[_download removeObserver:self forKeyPath:@"status"];
}

@end