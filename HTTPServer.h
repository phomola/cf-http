#import <Foundation/Foundation.h>

@interface HTTPRequest : NSObject

@property (readonly, nonatomic, strong) NSURL* URL;
@property (readonly, nonatomic, copy) NSString* method;
@property (readonly, nonatomic, strong) NSData* body;
@property (readonly, nonatomic, strong) NSDictionary* headers;

@end

@interface HTTPResponse : NSObject

- (instancetype)initWithStatus:(int)status body:(NSData*)body headers:(NSDictionary*)headers;

@end

@interface HTTPServer : NSObject

- (instancetype)initWithPort:(int)port backlog:(int)backlog anyAddress:(BOOL)anyAddress multithreaded:(BOOL)multithreaded;
- (BOOL)serveWithBlock:(HTTPResponse*(^)(HTTPRequest*))block;
- (void)close;
- (BOOL)isReadyToAccept;

@end
