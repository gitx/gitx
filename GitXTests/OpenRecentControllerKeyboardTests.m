//
//  OpenRecentControllerKeyboardTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "OpenRecentController.h"

// Records what would be opened instead of opening it.
@interface PBKeyboardOpenRecentController : OpenRecentController
@property (nonatomic, strong) NSMutableArray<NSURL *> *openedResults;
@property (nonatomic, readonly) NSTableView *table;
@property (nonatomic, readonly) NSSearchField *search;
@end

@implementation PBKeyboardOpenRecentController

- (NSTableView *)table
{
	return resultViewer;
}

- (NSSearchField *)search
{
	return searchField;
}

- (void)openSelectedResult
{
	if (selectedResult != nil)
		[self.openedResults addObject:selectedResult];
}

@end

@interface OpenRecentControllerKeyboardTests : XCTestCase
@property (nonatomic, strong) PBKeyboardOpenRecentController *controller;
@property (nonatomic, strong) NSArray<NSURL *> *repositories;
@end

@implementation OpenRecentControllerKeyboardTests

- (void)setUp
{
	[super setUp];

	self.repositories = @[
		[NSURL fileURLWithPath:@"/tmp/first"],
		[NSURL fileURLWithPath:@"/tmp/second"],
		[NSURL fileURLWithPath:@"/tmp/third"],
	];

	self.controller = [[PBKeyboardOpenRecentController alloc] init];
	self.controller.openedResults = [NSMutableArray array];
	self.controller.possibleResults = [self.repositories mutableCopy];
	[self.controller window];
	[self.controller doSearch:self];
	[self.controller.window makeFirstResponder:self.controller.table];
}

- (void)tearDown
{
	[self.controller.window close];

	[super tearDown];
}

- (void)pressKeyCode:(unsigned short)keyCode characters:(NSString *)characters modifiers:(NSEventModifierFlags)modifiers
{
	NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown
									  location:NSZeroPoint
								 modifierFlags:modifiers
									 timestamp:0
								  windowNumber:self.controller.window.windowNumber
									   context:nil
									characters:characters
				   charactersIgnoringModifiers:characters
									 isARepeat:NO
									   keyCode:keyCode];
	[self.controller.window sendEvent:event];
}

- (void)pressDownArrow
{
	unichar down = NSDownArrowFunctionKey;
	[self pressKeyCode:125
			characters:[NSString stringWithCharacters:&down length:1]
			 modifiers:NSEventModifierFlagFunction | NSEventModifierFlagNumericPad];
}

- (void)pressUpArrow
{
	unichar up = NSUpArrowFunctionKey;
	[self pressKeyCode:126
			characters:[NSString stringWithCharacters:&up length:1]
			 modifiers:NSEventModifierFlagFunction | NSEventModifierFlagNumericPad];
}

- (void)testReturnInTheListOpensTheRowChosenWithTheArrowKeys
{
	[self pressDownArrow];
	XCTAssertEqual(self.controller.table.selectedRow, 1, @"the arrow key should move the list's selection");

	[self pressKeyCode:36 characters:@"\r" modifiers:0];

	XCTAssertEqualObjects(self.controller.openedResults, @[ self.repositories[1] ]);
}

- (void)testKeypadEnterInTheListOpensTheSelectedRow
{
	[self pressDownArrow];
	[self pressDownArrow];

	[self pressKeyCode:76 characters:@"\x03" modifiers:NSEventModifierFlagNumericPad];

	XCTAssertEqualObjects(self.controller.openedResults, @[ self.repositories[2] ]);
}

- (void)testUpArrowInTheSearchFieldMovesUpOneRow
{
	[self.controller.window makeFirstResponder:self.controller.search];
	[self pressDownArrow];
	[self pressDownArrow];

	[self pressUpArrow];

	XCTAssertEqual(self.controller.table.selectedRow, 1);
}

- (void)testUpArrowInTheSearchFieldStaysOnTheTopRow
{
	[self.controller.window makeFirstResponder:self.controller.search];

	XCTAssertNoThrow([self pressUpArrow]);

	XCTAssertEqual(self.controller.table.selectedRow, 0);
}

@end
