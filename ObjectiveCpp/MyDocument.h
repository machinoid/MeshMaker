//
//  MyDocument.h
//  OpenGLEditor
//
//  Created by Filip Kunc on 6/29/09.
//  Copyright __MyCompanyName__ 2009 . All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import "ItemCollection.h"
#import "OpenGLSceneView.h"
#import "AddItemWithStepsSheetController.h"

@interface MyDocument : NSDocument <AddItemWithStepsProtocol, OpenGLSceneViewDelegate>
{
@public // public for unit tests
	ItemCollection *items;
	OpenGLManipulatingController *itemsController;
	OpenGLManipulatingController *meshController;
	id<OpenGLManipulating> manipulated;
	IBOutlet OpenGLSceneView *view;
	IBOutlet NSPopUpButton *editModePopUp;
	IBOutlet NSPopUpButton *cameraModePopUp;
	IBOutlet NSPopUpButton *viewModePopUp;
	IBOutlet AddItemWithStepsSheetController *addItemWithStepsSheetController;
	enum ItemWithSteps itemWithSteps;
}

@property (readwrite, assign) id<OpenGLManipulating> manipulated;
@property (readwrite, assign) float selectionX, selectionY, selectionZ;

- (void)addItem:(Item *)item withName:(NSString *)name;
- (void)removeItem:(Item *)item withName:(NSString *)name;
- (IBAction)addCube:(id)sender;
- (IBAction)addCylinder:(id)sender;
- (IBAction)addSphere:(id)sender;
- (void)editMeshWithMode:(enum MeshSelectionMode)mode;
- (void)editItems;
- (IBAction)changeEditMode:(id)sender;
- (IBAction)changeCameraMode:(id)sender;
- (IBAction)changeManipulator:(id)sender;
- (IBAction)changeViewMode:(id)sender;
- (IBAction)mergeSelected:(id)sender;
- (IBAction)splitSelected:(id)sender;
- (IBAction)turnSelectedEdges:(id)sender;
- (IBAction)mergeVertexPairs:(id)sender;
- (IBAction)cloneSelected:(id)sender;
- (IBAction)deleteSelected:(id)sender;
- (IBAction)selectAll:(id)sender;
- (IBAction)invertSelection:(id)sender;
- (void)readFromTmd:(NSString *)fileName;

@end