//
//  PBSidebarTableViewCell.h
//  GitX
//
//  Created by Max Langer on 02.12.17.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PBSidebarTableViewCell : NSTableCellView {	
	__weak IBOutlet NSImageView *checkedOutImageView;
}

@property (assign, nonatomic) BOOL isCheckedOut;

NS_ASSUME_NONNULL_END

@end
