#import "MyDocument.h"

#import "CidProtocol.h"

#import "AppKitPrivateMethods.h"

@implementation MyDocument

#pragma mark -
#pragma mark Life Cycle

- (id)init
{
    self = [super init];
    if (self)
	{
		// We use a custom URL protocol so that the web view can request the attachment files.
		[CidProtocol registerCidProtocol];
		
		// Make the export sheet.
		exportPanel = [[NSSavePanel alloc] init];
    }
    return self;
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
	[browserView setResourceLoadDelegate:self];
	
	// Set the web view to print images if the user should decide to print.
	[[browserView preferences] setShouldPrintBackgrounds:YES];
	
	// Set up the export sheet.
	[exportPanel setAccessoryView:formatChooserView];
	[exportPanel setExtensionHidden:NO];
	[exportPanel setCanSelectHiddenExtension:YES];
	
	if (documentAttachments)
	{
		// Load the data that we previously extracted when the file was opened.
		[[browserView mainFrame] loadData:[documentAttachments objectAtIndex:0] // The first file in the array is the main one and is HTML.
								 MIMEType:@"text/html"
						 textEncodingName:@"utf-8"
								  baseURL:NULL];
	}
	
    [super windowControllerDidLoadNib:aController];
}

- (void)dealloc
{
	[documentAttachments release];
	[exportPanel release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Reading and Writing Documents

- (NSString *)windowNibName
{
    return @"MyDocument";
}

- (NSData *)dataOfType:(NSString *)typeName
				 error:(NSError **)outError
// There is no "Save" feature because this is not an editor.
{
    if (outError != NULL)
	{
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
	return nil;
}

- (BOOL)readFromData:(NSData *)data
			  ofType:(NSString *)typeName
			   error:(NSError **)outError
// Parse the data from an MHTML file.
{
	NSString *mhtml = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	
	// Make the extractor that will extract the MHTML.
	arUnMHTExtractor *extractor = [[arUnMHTExtractor alloc] init];
	
    [extractor setCID];
	[extractor extractMHT:mhtml
		  originalURISpec:@""];
		
	// Because of the strange memory management in arUnMHTMLExtractor, the files will autorelease their content.
	// So we need to save the files in an array in order to use them later:
	
	NSMutableArray *fileAttachments = [NSMutableArray array];
	int i;
	for (i = 0; i < [extractor->files count]; i++)
	{
		arUnMHTExtractorFile *file = [extractor->files objectAtIndex:i];
		
		// Some files are binary files and some are plain text.
		if (file->binContent)
			[fileAttachments addObject:file->binContent];
		else
			[fileAttachments addObject:[file->content dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	[extractor release];
	
	// Keep our array of files.
	[documentAttachments release];
	documentAttachments = [[NSArray alloc] initWithArray:fileAttachments];
    
    if (outError != NULL)
	{
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
	
    return YES;
}

#pragma mark -
#pragma mark Loading Attachments into the Web View

-(NSURLRequest *)webView:(WebView *)sender resource:(id)identifier 
		 willSendRequest:(NSURLRequest *)request
		redirectResponse:(NSURLResponse *)redirectResponse
		  fromDataSource:(WebDataSource *)dataSource
{
	if ([CidProtocol canInitWithRequest:request])
		// If this request is an attachment of the main file.
	{
		NSString *lastPathComponent = [[[request URL] path] lastPathComponent];
		int numberPart = [[lastPathComponent substringFromIndex:10] intValue];
		
		// Make a new request and give assign the document data to it.
		NSMutableURLRequest *cidURLRequest = [[request mutableCopy] autorelease];
		[cidURLRequest setContentData:[documentAttachments objectAtIndex:numberPart]];
		
		return cidURLRequest;
    }

	// This is the main file, so do nothing special.
	return request;
}

#pragma mark -
#pragma mark Toolbar Delegate

- (void)toolbarWillAddItem:(NSNotification *)notification
{
	NSToolbarItem *item = [[notification userInfo] valueForKey:@"item"];

	if ([item itemIdentifier] == NSToolbarPrintItemIdentifier)
	{
		[item setTarget:self];
		[item setAction:@selector(printWebView:)];
	}
	
	if ([[item label] isEqualToString:@"Print"])
	{
		printToolbarItem = item;
	}
	else if ([[item label] isEqualToString:@"Export"])
	{
		exportToolbarItem = item;
	}
}

#pragma mark -
#pragma mark Toolbar Actions

- (void)toolbarItem:(NSToolbarItem *)toolbarItem
	 setHighlighted:(BOOL)highlighted
{
	if ([toolbarItem respondsToSelector:@selector(_view)])
	{
		NSToolbarItemViewer *toolbarItemViewer = (NSToolbarItemViewer *)[[toolbarItem _view] superview];
		if ([toolbarItemViewer respondsToSelector:@selector(_setHighlighted:displayNow:)])
			[toolbarItemViewer _setHighlighted:highlighted displayNow:YES];
	}
}

- (IBAction)exportFormatChanged:(id)sender
{
	NSArray *exportFileTypes = [NSArray arrayWithObjects:@"webarchive", @"war", @"pdf", @"", nil];
	
	int selectedFileType = [formatChooserButton indexOfSelectedItem];
	if (selectedFileType < [exportFileTypes count])
	{
		[exportPanel setRequiredFileType:[exportFileTypes objectAtIndex:selectedFileType]];
	}
	
}

- (IBAction)export:(id)sender
{
	[self exportFormatChanged:nil];
	
	[self toolbarItem:exportToolbarItem
	   setHighlighted:YES];
	
	[exportPanel beginSheetForDirectory:[self fileName]
								   file:[[[self fileName] lastPathComponent] stringByDeletingPathExtension]
						 modalForWindow:[browserView window]
						  modalDelegate:self
						 didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
							contextInfo:nil];
}
	
- (void)savePanelDidEnd:(NSSavePanel *)sheet
			 returnCode:(int)returnCode 
			contextInfo:(void  *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		int selectedFileType = [formatChooserButton indexOfSelectedItem];
		if (selectedFileType == 0)
		{
			WebArchive *archive = [[[browserView mainFrame] dataSource] webArchive];
			NSData *data = [archive data];
			[data writeToURL:[exportPanel URL]
				  atomically:YES];
		}
		else if (selectedFileType == 2)
		{
			NSView *viewToPrint = [[[browserView mainFrame] frameView] documentView];
			NSDictionary *printInfoDictionary = [NSDictionary dictionaryWithObjectsAndKeys:NSPrintSaveJob, NSPrintJobDisposition, [exportPanel filename], NSPrintSavePath, nil];
			NSPrintInfo *printInfo = [[[NSPrintInfo alloc] initWithDictionary:printInfoDictionary] autorelease];
			[printInfo setVerticallyCentered:NO];
			
			NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:viewToPrint
																			  printInfo:printInfo];
			[printOperation setShowPanels:NO];
			[printOperation runOperation];
		}
	}
	
	[self toolbarItem:exportToolbarItem
	   setHighlighted:NO];
}

- (IBAction)printWebView:(id)sender
{
	[self toolbarItem:printToolbarItem setHighlighted:YES];
	
	NSView *viewToPrint = [[[browserView mainFrame] frameView] documentView];
	
	NSPrintInfo *printInfo = [[[NSPrintInfo alloc] init] autorelease];
	[printInfo setVerticallyCentered:NO];
	
	NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:viewToPrint
																	  printInfo:printInfo];
	
	[printOperation runOperationModalForWindow:[viewToPrint window]
									  delegate:self
								didRunSelector:@selector(printOperationDidRun:success:contextInfo:)
								   contextInfo:NULL];
}

- (void)printOperationDidRun:(NSPrintOperation *)printOperation
					 success:(BOOL)success
				 contextInfo:(void *)contextInfo
{
	[self toolbarItem:printToolbarItem
	   setHighlighted:NO];
}

@end
