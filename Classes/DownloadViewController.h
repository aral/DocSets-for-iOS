//
//  DownloadViewController.h
//  DocSets
//
//  Created by Ole Zorn on 22.01.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DownloadViewController : UITableViewController {
	
}

@end


@class DocSetDownload;
@interface DownloadCell : UITableViewCell {
	NSDictionary *_downloadInfo;
	DocSetDownload *_download;
	UIProgressView *_progressView;
}

@property (nonatomic, strong) NSDictionary *downloadInfo;
@property (nonatomic, strong) DocSetDownload *download;
@property (nonatomic, strong) UIProgressView *progressView;

- (void)updateStatusLabel;

@end