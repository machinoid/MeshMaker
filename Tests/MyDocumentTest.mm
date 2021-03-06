//
//  MyDocumentTest.mm
//  OpenGLEditor
//
//  Created by Filip Kunc on 10/2/09.
//  For license see LICENSE.TXT
//

#import <SenTestingKit/SenTestingKit.h>
#import "MyDocument.h"

@interface MyDocumentTest : SenTestCase 
{
	MyDocument *document;
}

@end

@implementation MyDocumentTest

- (void)prepareDocument
{
	document = [[MyDocument alloc] init];
	[[document undoManager] setGroupsByEvent:NO];
	
	STAssertNotNil(document, @"document can't be nil");
	STAssertEquals([document->items count], 0U, @"items must be empty");	
}

- (void)groupAction:(void (^)())action
{
	[[document undoManager] beginUndoGrouping];
	action();
	[[document undoManager] endUndoGrouping];
}

- (void)testUndoMakeCube
{
	[self prepareDocument];
	
	// adding cube adds one item on undo stack
	[self groupAction:^ { [document addCube:self]; }];
	
	STAssertEquals([document->items count], 1U, @"items must contain one item");	
	
	// undo this action
	[[document undoManager] undo];
	
	// state must be same as before
	STAssertEquals([document->items count], 0U, @"items must be empty");
}

- (void)testUndoItemManipulation
{
	[self prepareDocument];

	[self groupAction:^ { [document addCube:self]; }];
	
	STAssertEquals([document->items count], 1U, @"items must contain one item");
	
	[self groupAction:^ 
	{ 
		[document manipulationStartedInView:nil];
		[document->itemsController moveSelectedByOffset:Vector3D(0, 5, 0)]; 
		[document manipulationEndedInView:nil]; 
	}];

	Item *item = [document->items itemAtIndex:0];
	STAssertEquals([item position], Vector3D(0, 5, 0), @"item position after move must be x = 0, y = 5, z = 0");
	
	[[document undoManager] undo];
	STAssertEquals([item position], Vector3D(0, 0, 0), @"item position after undo must be x = 0, y = 0, z = 0");	
	
	[[document undoManager] redo];
	STAssertEquals([item position], Vector3D(0, 5, 0), @"item position after redo must be x = 0, y = 5, z = 0");
}

- (void)testUndoItemManipulations
{
	[self prepareDocument];
	
	[self groupAction:^ { [document addCube:self]; }]; // 0
	[self groupAction:^ { [document addCube:self]; }]; // 1
	
	STAssertEquals([document->itemsController selectedCount], 1U, @"one item must be selected");	
	
	[self groupAction:^ 
	{ 
		[document manipulationStartedInView:nil];
		[document->itemsController moveSelectedByOffset:Vector3D(0, 5, 0)]; // moves the second cube
		[document manipulationEndedInView:nil]; 
	}];
	
	[document invertSelection:self];
	
	STAssertEquals([document->itemsController selectedCount], 1U, @"one item must be selected");	
	
	[self groupAction:^ 
	{ 
		[document manipulationStartedInView:nil];
		[document->itemsController moveSelectedByOffset:Vector3D(5, 0, 0)]; // moves the first cube
		[document manipulationEndedInView:nil]; 
	}];
	
	while ([[document undoManager] canUndo])
	{
		[[document undoManager] undo];
	}
	
	[[document undoManager] undo];
	[[document undoManager] undo];
	
	STAssertEquals([document->items count], 0U, @"items must be empty");	
	
	while ([[document undoManager] canRedo]) 
	{
		[[document undoManager] redo];
	}
	
	[[document undoManager] redo];
	[[document undoManager] redo];
	
	STAssertEquals([document->items count], 2U, @"items count must be two");
	
	STAssertEquals([[document->items itemAtIndex:0U] position], Vector3D(5, 0, 0), @"first item (5, 0, 0)");
	STAssertEquals([[document->items itemAtIndex:1U] position], Vector3D(0, 5, 0), @"second item (0, 5, 0)");
}

- (void)testUndoItemManipulationDuplicateDelete
{
	[self prepareDocument];

	[self groupAction:^ { [document addCube:self]; }];
	[self groupAction:^ { [document duplicateSelected:self]; }];
	
	[self groupAction:^ 
	{ 
		[document manipulationStartedInView:nil]; 
		[document->itemsController moveSelectedByOffset:Vector3D(5, 0, 0)];
		[document manipulationEndedInView:nil]; 
	}];	
	
	[document selectAll:self];
	
	[self groupAction:^ { [document duplicateSelected:self]; }];	
	
	[self groupAction:^ 
	{ 
		[document manipulationStartedInView:nil];
		[document->itemsController moveSelectedByOffset:Vector3D(0, 5, 0)];
		[document manipulationEndedInView:nil]; 
	}];
		
	while ([[document undoManager] canUndo])
	{
		[[document undoManager] undo];
	}
	
	STAssertEquals([document->items count], 0U, @"items must be empty");	

	while ([[document undoManager] canRedo]) 
	{
		[[document undoManager] redo];
	}
		
	STAssertEquals([document->items count], 4U, @"items count must be four");
	
	STAssertEquals([[document->items itemAtIndex:0U] position], Vector3D(0, 0, 0), @"first item (0, 0, 0)");
	STAssertEquals([[document->items itemAtIndex:1U] position], Vector3D(5, 0, 0), @"second item (5, 0, 0)");
	STAssertEquals([[document->items itemAtIndex:2U] position], Vector3D(0, 5, 0), @"third item (0, 5, 0)");
	STAssertEquals([[document->items itemAtIndex:3U] position], Vector3D(5, 5, 0), @"fourth item (5, 5, 0)");
		
	[document selectAll:self];
	[document invertSelection:self];
	[document->items setSelected:YES atIndex:1U]; 
	[document->items setSelected:YES atIndex:2U]; 
	[document->itemsController updateSelection];
	
	[self groupAction:^ { [document deleteSelected:self]; }];
	
	while ([[document undoManager] canUndo])
	{
		[[document undoManager] undo];
	}
	
	STAssertEquals([document->items count], 0U, @"items must be empty");	

	while ([[document undoManager] canRedo])
	{
		[[document undoManager] redo];
	}
	
	STAssertEquals([document->items count], 2U, @"items count must be two");
	STAssertEquals([[document->items itemAtIndex:0U] position], Vector3D(0, 0, 0), @"first item (0, 0, 0)");
	STAssertEquals([[document->items itemAtIndex:1U] position], Vector3D(5, 5, 0), @"second item (5, 5, 0)");
}

@end
