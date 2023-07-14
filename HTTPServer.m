#import "HTTPServer.h"
#include <netinet/in.h>

@interface HTTPRequest ()

@property (nonatomic, strong) NSURL* URL;
@property (nonatomic, copy) NSString* method;
@property (nonatomic, strong) NSData* body;
@property (nonatomic, strong) NSDictionary* headers;

@end

@implementation HTTPRequest

- (instancetype)initWithURL:(NSURL*)URL method:(NSString*)method body:(NSData*)body headers:(NSDictionary*)headers {
    if ((self = [super init])) {
        self.URL = URL;
        self.method = method;
        self.body = body;
        self.headers = headers;
    }
    return self;
}

@end

@interface HTTPResponse ()

@property (nonatomic) int status;
@property (nonatomic, strong) NSData* body;
@property (nonatomic, strong) NSDictionary* headers;

@end

@implementation HTTPResponse

- (instancetype)initWithStatus:(int)status body:(NSData*)body headers:(NSDictionary*)headers {
    if ((self = [super init])) {
        self.status = status;
        self.body = body;
        self.headers = headers;
    }
    return self;
}

@end

@interface HTTPServer ()

@property (nonatomic) int serverfd;
@property (nonatomic) BOOL multithreaded;
@property (atomic) BOOL closed;

@end

@implementation HTTPServer

- (instancetype)initWithPort:(int)port backlog:(int)backlog anyAddress:(BOOL)anyAddress multithreaded:(BOOL)multithreaded {
    if ((self = [super init])) {
        int sockfd = socket(AF_INET, SOCK_STREAM, 0);
        if (sockfd < 0) {
            NSLog(@"socket creation failed");
            return self;
        }
        if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &(int){1}, sizeof(int)) < 0) {
            NSLog(@"failed to set socket option");
            return self;
        }
        struct sockaddr_in servaddr;
        bzero(&servaddr, sizeof(servaddr));
        servaddr.sin_family = AF_INET;
        servaddr.sin_addr.s_addr = htonl(anyAddress ? INADDR_ANY : INADDR_LOOPBACK);
        servaddr.sin_port = htons(port);
        if (bind(sockfd, (struct sockaddr*)&servaddr, sizeof(servaddr)) < 0) {
            NSLog(@"socket bind failed");
            return self;
        }
        if (backlog > SOMAXCONN) backlog = SOMAXCONN;
        if (listen(sockfd, backlog) < 0) {
            NSLog(@"socket listen failed");
            return self;
        }
        self.serverfd = sockfd;
        self.multithreaded = multithreaded;
    }
    return self;
}

- (BOOL)serveWithBlock:(HTTPResponse*(^)(HTTPRequest*))block {
    struct sockaddr_in claddr;
    unsigned int len = sizeof(claddr);
    const int bufferSize = 10*1000;
    for (;;) {
        int connfd = accept(self.serverfd, (struct sockaddr*)&claddr, &len);
        if (connfd < 0) {
            if (self.closed == NO) NSLog(@"accept failed");
            return self.closed;
        }
        __auto_type f = ^{
            @autoreleasepool {
                CFURLRef url = NULL;
                CFStringRef method = NULL;
                CFDataRef body = NULL;
                CFHTTPMessageRef resp = NULL;
                CFDictionaryRef headers = NULL;
                HTTPResponse* response;
                int contentLength = 0;
                bool headerProcessed = false;
                __auto_type req = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
                unsigned char buf[bufferSize];
                long shouldRead = bufferSize;
                for (;;) {
                    __auto_type n = read(connfd, buf, shouldRead);
                    if (n < 0) {
                        NSLog(@"read failed");
                        goto cleanup;
                    }
                    if (n == 0) break;
                    if (CFHTTPMessageAppendBytes(req, buf, n) == FALSE) {
                        NSLog(@"request message append failed");
                        goto cleanup;
                    }
                    if (CFHTTPMessageIsHeaderComplete(req) == TRUE) {
                        if (!headerProcessed) {
                            __auto_type sContentLength = CFHTTPMessageCopyHeaderFieldValue(req, CFSTR("Content-Length"));
                            if (sContentLength != NULL) {
                                char s[100];
                                CFStringGetCString(sContentLength, s, 100, kCFStringEncodingUTF8);
                                contentLength = atoi(s);
                                CFRelease(sContentLength);
                            }
                            headerProcessed = true;
                        }
                        __auto_type body2 = CFHTTPMessageCopyBody(req);
                        if (body2 != NULL) {
                            __auto_type len = CFDataGetLength(body2);
                            if (len >= contentLength) { body = body2; break; }
                            shouldRead = contentLength - len;
                            if (shouldRead > bufferSize) shouldRead = bufferSize;
                            CFRelease(body2);
                        } else break;
                    }
                }
                url = CFHTTPMessageCopyRequestURL(req);
                if (url == NULL) {
                    NSLog(@"failed to get request URL");
                    goto cleanup;
                }
                method = CFHTTPMessageCopyRequestMethod(req);
                headers = CFHTTPMessageCopyAllHeaderFields(req);
                if (headers == NULL) {
                    NSLog(@"failed to get request headers");
                    goto cleanup;
                }
                response = block([[HTTPRequest alloc] initWithURL: (__bridge NSURL*)url
                                                           method: (__bridge NSString*)method
                                                             body: (__bridge NSData*)body
                                                          headers: (__bridge NSDictionary*)headers]);
                resp = CFHTTPMessageCreateResponse(kCFAllocatorDefault, response.status, NULL, kCFHTTPVersion1_1);
                if (response.headers != nil) {
                    [response.headers enumerateKeysAndObjectsUsingBlock: ^(NSString* key, NSString* value, BOOL* stop) {
                        CFHTTPMessageSetHeaderFieldValue(resp, (__bridge CFStringRef)key, (__bridge CFStringRef)value);
                    }];
                }
                CFHTTPMessageSetBody(resp, (__bridge CFDataRef)response.body);
                __auto_type msg = CFHTTPMessageCopySerializedMessage(resp);
                __auto_type ptr = CFDataGetBytePtr(msg);
                __auto_type len = CFDataGetLength(msg);
                while (len > 0) {
                    __auto_type n = write(connfd, ptr, len);
                    if (n < 0) {
                        printf("write failed\n");
                        break;
                    }
                    ptr += n;
                    len -= n;
                }
                CFRelease(msg);
            cleanup:
                CFRelease(req);
                if (url != NULL) CFRelease(url);
                if (method != NULL) CFRelease(method);
                if (body != NULL) CFRelease(body);
                if (resp != NULL) CFRelease(resp);
                if (headers != NULL) CFRelease(headers);
                if (close(connfd) < 0) {
                    NSLog(@"failed to close socket: %s", strerror(errno));
                }
            }
        };
        if (self.multithreaded == YES) [NSThread detachNewThreadWithBlock: f];
        else f();
    }
}

- (void)close {
    self.closed = YES;
    close(self.serverfd);
}

- (BOOL)isReadyToAccept {
    return self.serverfd != 0 && self.closed == NO;
}

@end

#if !__has_feature(objc_arc)
    #error ARC is required
#endif
