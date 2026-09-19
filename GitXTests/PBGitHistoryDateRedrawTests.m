//
//  PBGitHistoryDateRedrawTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitHistoryController.h"
#import "PBGitRepository.h"
#import "PBGitCommitDateFormatter.h"

@interface PBGitHistoryController (CommitDateRedrawTesting)
- (void)_commitDateFormatChangedNotification:(NSNotification *)notification;
@end

// The date column binds to a commit's date, and a commit hands the same date
// back every time it is asked. That is the whole difficulty: the value behind
// the column never changes, only the formatter in front of it.
@interface PBStubDatedCommit : NSObject
@property (nonatomic, strong) NSDate *date;
@end

@implementation PBStubDatedCommit
@end

// AppKit does not hand -needsDisplay back as a flag a test can read: on a
// layer-backed view the getter answers no however the setter was called. So the
// field counts the requests it is given instead.
@interface PBRedrawCountingTextField : NSTextField
@property (nonatomic, assign) NSUInteger redrawRequests;
@end

@implementation PBRedrawCountingTextField

- (void)setNeedsDisplay:(BOOL)needsDisplay
{
	if (needsDisplay)
		self.redrawRequests++;

	[super setNeedsDisplay:needsDisplay];
}

@end

// Stands in for the history list's nib. The cell view holds the commit and the
// text field reads the date off it through a binding, which is how
// PBGitHistoryView.xib wires this column, rather than through a data source
// the table can be told to ask again.
@interface PBDateColumnSource : NSObject <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) PBStubDatedCommit *commit;
@end

@implementation PBDateColumnSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return 3;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	return self.commit;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSTableCellView *cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 165, 20)];

	PBRedrawCountingTextField *field = [[PBRedrawCountingTextField alloc] initWithFrame:cell.bounds];
	field.editable = NO;
	field.formatter = [[PBGitCommitDateFormatter alloc] init];
	[field bind:NSValueBinding toObject:cell withKeyPath:@"objectValue.date" options:nil];

	[cell addSubview:field];
	cell.textField = field;

	return cell;
}

@end

@interface PBGitHistoryDateRedrawTests : XCTestCase
@property (nonatomic, strong) PBGitHistoryController *historyController;
@property (nonatomic, strong) NSTableView *commitList;
@property (nonatomic, strong) PBDateColumnSource *source;
@property (nonatomic, strong) NSWindow *window;
@end

@implementation PBGitHistoryDateRedrawTests

// -[PBGitRepository init] and -[PBViewController initWithRepository:...] both
// stay in memory, and the table is built here rather than loaded from the nib,
// so nothing in this suite needs a repository on disk. The controller holds its
// table weakly, so the test keeps the only strong reference to it.
- (void)setUp
{
	[super setUp];

	self.source = [PBDateColumnSource new];
	self.source.commit = [PBStubDatedCommit new];
	self.source.commit.date = [NSDate dateWithTimeIntervalSince1970:1789394700];

	self.commitList = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 400, 100)];
	self.commitList.dataSource = self.source;
	self.commitList.delegate = self.source;

	NSTableColumn *dateColumn = [[NSTableColumn alloc] initWithIdentifier:@"DateColumn"];
	dateColumn.width = 165;
	[self.commitList addTableColumn:dateColumn];

	self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 100)
											  styleMask:NSWindowStyleMaskBorderless
												backing:NSBackingStoreBuffered
												  defer:NO];
	self.window.contentView = self.commitList;

	[self.commitList reloadData];
	[self.commitList layoutSubtreeIfNeeded];
	[self.window displayIfNeeded];

	self.historyController = [[PBGitHistoryController alloc] initWithRepository:[[PBGitRepository alloc] init] superController:nil];
	[self.historyController setValue:self.commitList forKey:@"commitList"];
}

- (NSArray<PBRedrawCountingTextField *> *)dateFields
{
	NSMutableArray<PBRedrawCountingTextField *> *fields = [NSMutableArray array];

	NSInteger column = [self.commitList columnWithIdentifier:@"DateColumn"];
	[self.commitList enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row) {
		NSTableCellView *cell = (NSTableCellView *)[self.commitList viewAtColumn:column row:row makeIfNecessary:NO];
		if (cell.textField)
			[fields addObject:(PBRedrawCountingTextField *)cell.textField];
	}];

	return fields;
}

- (NSArray<NSNumber *> *)redrawRequestsSoFar
{
	NSMutableArray<NSNumber *> *counts = [NSMutableArray array];
	for (PBRedrawCountingTextField *field in [self dateFields])
		[counts addObject:@(field.redrawRequests)];

	return counts;
}

// The controller subscribes when its view loads, which this suite never does,
// so the handler is called the way the notification centre would call it.
- (void)announceAFormatChange
{
	NSNotification *notification = [NSNotification notificationWithName:PBGitCommitDateFormatDidChangeNotification object:nil];
	[self.historyController _commitDateFormatChangedNotification:notification];
}

- (void)testTheRowsAreOnScreenToBeginWith
{
	XCTAssertEqual([self dateFields].count, 3, @"the rest of this suite is about rows that are drawn, so there have to be some");
}

// The bug: the list was reloaded instead, which re-hands the column the commit
// it already had. The binding sees the same object, pushes nothing, and every
// row goes on showing the format it was drawn with until something else
// happens to redraw it - selecting it, or scrolling it away and back.
- (void)testAChangedFormatMarksEveryDrawnRowForRedraw
{
	NSArray<NSNumber *> *before = [self redrawRequestsSoFar];

	[self announceAFormatChange];

	NSArray<PBRedrawCountingTextField *> *fields = [self dateFields];
	[fields enumerateObjectsUsingBlock:^(PBRedrawCountingTextField *field, NSUInteger index, BOOL *stop) {
		XCTAssertGreaterThan(field.redrawRequests, before[index].unsignedIntegerValue,
							 @"row %lu was left showing the format it was drawn with", (unsigned long)index);
	}];
}

- (void)testAListWithNoDateColumnIsLeftAlone
{
	[self.commitList removeTableColumn:[self.commitList tableColumnWithIdentifier:@"DateColumn"]];

	XCTAssertNoThrow([self announceAFormatChange]);
}

@end
