#import "HTTPServer.h"
#include <netinet/in.h>

@interface HTTPRequest ()

@property (nonatomic, strong) NSURL* URL;
@property (nonatomic, copy) NSString* method;
@property (nonatomic, strong) NSData* body;

@end

@implementation HTTPRequest

- (instancetype)initWithURL:(NSURL*)URL method:(NSString*)method body:(NSData*)body {
    if ((self = [super init])) {
        self.URL = URL;
        self.method = method;
        self.body = body;
    }
    return self;
}

@end

@interface HTTPResponse ()

@property (nonatomic) int status;
@property (nonatomic, strong) NSData* body;

@end

@implementation HTTPResponse

- (instancetype)initWithStatus:(int)status body:(NSData*)body {
    if ((self = [super init])) {
        self.status = status;
        self.body = body;
    }
    return self;
}

@end

@interface HTTPServer ()

@property (nonatomic) int serverfd;

@end

@implementation HTTPServer

- (instancetype)initWithPort:(int)port {
    if ((self = [super init])) {
        int sockfd = socket(AF_INET, SOCK_STREAM, 0);
        if (sockfd < 0) {
            NSLog(@"socket creation failed");
            return self;
        }
        struct sockaddr_in servaddr;
        bzero(&servaddr, sizeof(servaddr));
        servaddr.sin_family = AF_INET;
        servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
        servaddr.sin_port = htons(port);
        if (bind(sockfd, (struct sockaddr*)&servaddr, sizeof(servaddr)) < 0) {
            NSLog(@"socket bind failed");
            return self;
        }
        if (listen(sockfd, 100) != 0) {
            NSLog(@"socket listen failed");
            return self;
        }
        self.serverfd = sockfd;
    }
    return self;
}

- (void)serveWithBlock:(HTTPResponse*(^)(HTTPRequest*))block {
    struct sockaddr_in claddr;
    unsigned int len = sizeof(claddr);
    for (;;) {
        int connfd = accept(self.serverfd, (struct sockaddr*)&claddr, &len);
        if (connfd < 0) {
            NSLog(@"accept failed");
            return;
        }
        [NSThread detachNewThreadWithBlock: ^{
            CFURLRef url = NULL;
            CFStringRef method = NULL;
            CFDataRef body = NULL;
            CFHTTPMessageRef resp = NULL;
            HTTPResponse* response;
            int contentLength = 0;
            bool headerProcessed = false;
            __auto_type req = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
            unsigned char buf[1000];
            int shouldRead = 1000;
            for (;;) {
                int n = read(connfd, buf, shouldRead);
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
                    body = CFHTTPMessageCopyBody(req);
                    if (body != NULL) {
                        __auto_type len = CFDataGetLength(body);
                        if (len >= contentLength) break;
                        shouldRead = contentLength - len;
                        CFRelease(body);
                    } else break;
                }
            }
            url = CFHTTPMessageCopyRequestURL(req);
            if (url == NULL) {
                NSLog(@"failed to get request URL");
                goto cleanup;
            }
            method = CFHTTPMessageCopyRequestMethod(req);
            response = block([[HTTPRequest alloc] initWithURL: (__bridge NSURL*)url
                                                       method: (__bridge NSString*)method
                                                         body: (__bridge NSData*)body]);
            resp = CFHTTPMessageCreateResponse(kCFAllocatorDefault, response.status, NULL, kCFHTTPVersion1_1);
            CFHTTPMessageSetBody(resp, (__bridge CFDataRef)response.body);
            __auto_type msg = CFHTTPMessageCopySerializedMessage(resp);
            __auto_type ptr = CFDataGetBytePtr(msg);
            __auto_type len = CFDataGetLength(msg);
            while (len > 0) {
                int n = write(connfd, ptr, len);
                if (n < 0) {
                    printf("write failed\n");
                    break;
                }
                ptr += n;
                len -= n;
            }
            CFRelease(msg);
        cleanup:
            if (url != NULL) CFRelease(url);
            if (method != NULL) CFRelease(method);
            if (body != NULL) CFRelease(body);
            CFRelease(req);
            if (resp != NULL) CFRelease(resp);
            close(connfd);
        }];
    }
}

- (BOOL)isReadyToAccept {
    return self.serverfd != 0;
}

@end

#if !__has_feature(objc_arc)
	#error ARC is required
#endif
