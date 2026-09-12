//
//  GLFileViewLayoutTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "GLFileView.h"

// The type bar is an outlet, so a test has to hand it over itself. Only the
// room it takes up matters here, which any view can stand in for.
@interface PBLayoutStubFileView : GLFileView
- (void)useTypeBar:(id)bar;
@end

@implementation PBLayoutStubFileView

- (void)useTypeBar:(id)bar
{
	typeBar = bar;
}

@end

@interface GLFileViewLayoutTests : XCTestCase
@property (nonatomic, strong) NSView *container;
@property (nonatomic, strong) NSView *typeBar;
@property (nonatomic, strong) PBLayoutStubFileView *fileView;
@end

@implementation GLFileViewLayoutTests

- (void)buildViewerOfHeight:(CGFloat)height barHeight:(CGFloat)barHeight
{
	self.container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, height)];
	self.typeBar = [[NSView alloc] initWithFrame:NSMakeRect(0, height - barHeight, 400, barHeight)];
	[self.container addSubview:self.typeBar];

	self.fileView = [[PBLayoutStubFileView alloc] init];
	[self.fileView useTypeBar:self.typeBar];
}

- (void)testTheViewerStopsWhereTheTypeBarStarts
{
	[self buildViewerOfHeight:214 barHeight:25];

	NSRect frame = [self.fileView frameForWebView];

	XCTAssertEqual(NSMaxY(frame), 189.0, @"the file has to end below the bar, not behind it");
	XCTAssertEqual(NSMinY(frame), 0.0);
	XCTAssertEqual(NSWidth(frame), 400.0, @"the whole width is still the viewer's to use");
}

- (void)testTheViewerFollowsTheContainerItSitsIn
{
	[self buildViewerOfHeight:900 barHeight:25];

	XCTAssertEqual(NSMaxY([self.fileView frameForWebView]), 875.0, @"a resized window leaves the bar where it is");
}

- (void)testATallerTypeBarTakesItsOwnRoom
{
	[self buildViewerOfHeight:214 barHeight:46];

	XCTAssertEqual(NSMaxY([self.fileView frameForWebView]), 168.0);
}

@end
