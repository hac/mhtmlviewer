#import <Cocoa/Cocoa.h>

#import <WebKit/WebKit.h>

#import "arUnMHTExtractor.h"

@interface MyDocument : NSDocument
{	
	IBOutlet WebView *browserView;
	IBOutlet NSToolbar *toolbar;
	
	NSSavePanel *exportPanel;
	
	IBOutlet NSView *formatChooserView;
	IBOutlet NSPopUpButton *formatChooserButton;
	
	NSToolbarItem *printToolbarItem, *exportToolbarItem;
	
	NSArray *documentAttachments;
}

- (IBAction)export:(id)sender;
- (IBAction)printWebView:(id)sender;

- (IBAction)exportFormatChanged:(id)sender;

@end
