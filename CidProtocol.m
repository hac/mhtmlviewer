//
//  Created by David Gelhar on 11/11/09.
//

#import "CidProtocol.h"

#import <Foundation/NSError.h>

@implementation CidProtocol

// We call this before the web view requests applewebdata resources.
+ (void)registerCidProtocol
{
    [NSURLProtocol registerClass:[CidProtocol class]];
}

/* class method for protocol called by webview to determine if this
 protocol should be used to load the request. */
+ (BOOL)canInitWithRequest:(NSURLRequest *)theRequest
{	
     NSString *theScheme = [[theRequest URL] scheme];
    
    // The extracted HTML uses the applewebdata protocol to refer to attachments.
    return ([theScheme caseInsensitiveCompare: @"applewebdata"] == NSOrderedSame);
}

/* if canInitWithRequest returns true, then webKit will call your
 canonicalRequestForRequest method so you have an opportunity to modify
 the NSURLRequest before processing the request */
+(NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
        
    /* we don't do any special processing here, though we include this
     method because all subclasses must implement this method. */
    
    return request;
}

/* our main loading routine. Locate the attachment corresponding to the given
 Content-id, load its data.  */
- (void)startLoading
{    
    /* retrieve the current request. */
    NSURLRequest *request = [self request];
	
    /* get a reference to the client so we can hand off the data (or send error) */
    id<NSURLProtocolClient> client = [self client];
	
    NSData *data = [request contentData];
    if (data)
	{
		// Copy attachment data into the response.
		[client URLProtocol:self didLoadData:data];
		
		// Notify that we completed loading.
		[client URLProtocolDidFinishLoading:self];
    }
	
	else
	{
		[client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain
																	  code:NSURLErrorResourceUnavailable userInfo:nil]];
    }
}

/* called to stop loading or to abort loading.  We don't do anything special here. */
- (void)stopLoading
{
    //NSLog(@"%@ received %@", self, NSStringFromSelector(_cmd));
}

@end

/* data passing categories on NSURLRequest and NSMutableURLRequest. */

@implementation NSURLRequest (CidProtocol)

- (NSData *)contentData
{
    return [NSURLProtocol propertyForKey:@"contentData"
							   inRequest:self];
}

@end

@implementation NSMutableURLRequest (CidProtocol)

- (void)setContentData:(NSData *)value
{
    [NSURLProtocol setProperty:[[value copy] autorelease]
						forKey:@"contentData"
					 inRequest:self];
}

@end

