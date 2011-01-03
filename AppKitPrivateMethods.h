// We use these to fix some weird toolbar behavior.

@interface NSToolbarItemViewer : NSObject

- (NSView *)_setHighlighted:(BOOL)value
				 displayNow:(BOOL)value;

@end

@interface NSToolbarItem (PrivateMethods)

- (NSView *)_view;

@end

@interface NSToolbar (PrivateMethods)

- (NSView *)_toolbarView;

@end