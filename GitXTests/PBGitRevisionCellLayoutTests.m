//
//  PBGitRevisionCellLayoutTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>

#import "PBGitRevisionCell.h"
#import "PBGitCommit.h"
#import "PBGitRef.h"
#import "PBGraphCellInfo.h"

// The cell draws the subject itself and lays its own text field out, so the
// only way to tell whether a row lines up is to ask it for the rectangles.
// -rectsForRefsinRect: is the one the drawing and layout paths both use;
// -rectAtIndex: probes a 10000pt tall rect for hit testing and says nothing
// about where a label sits in a row.
@interface PBGitRevisionCell (LayoutTests)
- (NSArray<NSValue *> *)rectsForRefsinRect:(NSRect)rect;
@end

// -[PBGitCommit refs] reads through to the repository's table, so a commit
// with no repository has none. This stub carries its own.
@interface PBLayoutTestCommit : PBGitCommit
@property (nonatomic, strong) NSMutableArray *stubRefs;
@end

@implementation PBLayoutTestCommit
- (NSMutableArray *)refs
{
	return self.stubRefs;
}
@end

@interface PBGitRevisionCellLayoutTests : XCTestCase
@end

@implementation PBGitRevisionCellLayoutTests

static const CGFloat kRowHeight = 20;
static const CGFloat kTextHeight = 14;

- (PBGitRevisionCell *)cellWithRefs:(NSArray<NSString *> *)refNames graphLine:(BOOL)hasGraphLine
{
	PBGitRevisionCell *cell = [[PBGitRevisionCell alloc] initWithFrame:NSMakeRect(0, 0, 400, kRowHeight)];

	NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 400, kTextHeight)];
	[cell addSubview:field];
	cell.textField = field;

	PBLayoutTestCommit *commit = [PBLayoutTestCommit new];
	NSMutableArray *refs = [NSMutableArray array];
	for (NSString *name in refNames)
		[refs addObject:[PBGitRef refFromString:name]];
	commit.stubRefs = refs;

	if (hasGraphLine) {
		PBGraphCellInfo *info = [[PBGraphCellInfo alloc] initWithPosition:0 andLines:NULL];
		info.nLines = 0;
		info.numColumns = 1;
		commit.lineInfo = info;
	}

	cell.objectValue = commit;
	return cell;
}

- (void)testTheSubjectSitsOnTheRowCentre
{
	PBGitRevisionCell *cell = [self cellWithRefs:@[ @"refs/heads/master" ] graphLine:YES];

	[cell layout];

	XCTAssertEqualWithAccuracy(NSMidY(cell.textField.frame), NSMidY(cell.bounds), 0.5,
							   @"the subject is not on the row's centre line");
}

- (void)testTheSubjectSitsOnTheRowCentreWithoutAGraphLine
{
	PBGitRevisionCell *cell = [self cellWithRefs:@[] graphLine:NO];

	[cell layout];

	XCTAssertEqualWithAccuracy(NSMidY(cell.textField.frame), NSMidY(cell.bounds), 0.5,
							   @"a commit with no graph line leaves the subject where the nib put it");
}

- (void)testTheSubjectStaysCentredWhenTheHeightsDifferByAnOddAmount
{
	PBGitRevisionCell *cell = [self cellWithRefs:@[] graphLine:NO];
	cell.frame = NSMakeRect(0, 0, 400, kRowHeight + 1);

	[cell layout];

	XCTAssertEqualWithAccuracy(NSMidY(cell.textField.frame), NSMidY(cell.bounds), 0.5,
							   @"an odd difference between the row and the text is not centred");
	XCTAssertTrue(NSEqualRects(cell.textField.frame,
							   [cell backingAlignedRect:cell.textField.frame options:NSAlignAllEdgesNearest]),
				  @"the subject is off the pixel grid, which renders blurred at 1x");
}

- (void)testTheRefLabelsSitOnTheRowCentre
{
	NSArray *names = @[ @"refs/heads/master", @"refs/remotes/origin/master" ];
	PBGitRevisionCell *cell = [self cellWithRefs:names graphLine:YES];

	NSArray<NSValue *> *rects = [cell rectsForRefsinRect:cell.bounds];
	XCTAssertEqual(rects.count, names.count, @"the cell did not lay every ref out");

	for (NSValue *value in rects) {
		XCTAssertEqualWithAccuracy(NSMidY(value.rectValue), NSMidY(cell.bounds), 0.5,
								   @"a ref label is not on the row's centre line");
	}
}

@end
