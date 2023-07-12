#import <Foundation/Foundation.h>

@interface HTTPRequest : NSObject

@property (readonly, nonatomic, strong) NSURL* URL;
@property (readonly, nonatomic, copy) NSString* method;
@property (readonly, nonatomic, strong) NSData* body;

@end

@interface HTTPResponse : NSObject

- (instancetype)initWithStatus:(int)status body:(NSData*)body anyAddress:(BOOL)anyAddress;

@end

@interface HTTPServer : NSObject

- (instancetype)initWithPort:(int)port backlog:(int)backlog;
- (BOOL)serveWithBlock:(HTTPResponse*(^)(HTTPRequest*))block;
- (void)close;
- (BOOL)isReadyToAccept;

@end
