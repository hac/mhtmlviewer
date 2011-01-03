//
//  Created by David Gelhar on 11/11/09.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/NSURLProtocol.h>

// Our custom NSURLProtocol is implemented as a subclass.
@interface CidProtocol : NSURLProtocol
{
}
+ (void)registerCidProtocol;
@end

@interface NSURLRequest (CidProtocol)
- (NSData *)contentData;
@end

@interface NSMutableURLRequest (CidProtocol)
- (void)setContentData:(NSData *)value;
@end