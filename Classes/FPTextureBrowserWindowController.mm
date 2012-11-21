//
//  FPTextureBrowserWindowController.mm
//  MeshMaker
//
//  Created by Filip Kunc on 4/14/12.
//  For license see LICENSE.TXT
//

#import "FPTextureBrowserWindowController.h"

@interface FPTextureBrowserWindowController ()  <NSTableViewDataSource, NSTableViewDelegate>
{
    IBOutlet NSTableView *textureList;
    IBOutlet NSImageView *textureView;
}

- (IBAction)setTexture:(id)sender;

@end

@implementation FPTextureBrowserWindowController

- (id)init
{
    self = [super initWithWindowNibName:@"FPTextureBrowserWindowController"];
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}
- (void)setItems:(ItemCollection *)anItems
{
    items = anItems;
    [textureList reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return items.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return [NSString stringWithFormat:@"Texture%.2li.png", row];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    int selectedRow = textureList.selectedRow;
    if (selectedRow >= 0 && selectedRow < (int)items.count)
    {    
        Mesh2 *mesh = [items itemAtIndex:selectedRow].mesh;
        [items deselectAll];
        [items setSelected:YES atIndex:selectedRow];
        [textureView setImage:mesh->texture().canvas];
    }
    else
    {
        [items deselectAll];
        [textureView setImage:nil];
    }
}

- (IBAction)setTexture:(id)sender
{
    int selectedRow = textureList.selectedRow;
    if (selectedRow >= 0 && selectedRow < (int)items.count)
    {    
        Mesh2 *mesh = [items itemAtIndex:selectedRow].mesh;
        [mesh->texture() setCanvas:textureView.image];
    }
}

@end
