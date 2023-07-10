#import <Foundation/Foundation.h>

@interface HTTPRequest : NSObject

@property (readonly, nonatomic, copy) NSString* path;
@property (readonly, nonatomic, copy) NSString* method;
@property (readonly, nonatomic, strong) NSData* body;

- (instancetype)initWithPath:(NSString*)path method:(NSString*)method body:(NSData*)body;

@end

@interface HTTPResponse : NSObject

- (instancetype)initWithStatus:(int)status body:(NSData*)body;

@end

@interface HTTPServer : NSObject

- (instancetype)initWithPort:(int)port;
- (void)serveWithBlock:(HTTPResponse*(^)(HTTPRequest*))block;
- (BOOL)isReadyToAccept;

@end
