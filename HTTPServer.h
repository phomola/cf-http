#import <Foundation/Foundation.h>

@interface HTTPRequest : NSObject

@property (nonatomic, copy) NSString* path;
@property (nonatomic, copy) NSString* method;
@property (nonatomic, strong) NSData* body;

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
