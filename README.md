# cf-http
This is a simple HTTP server based on CoreFoundation. It's a naïve implementation detaching a new thread for each request. We'll use *kqueue* in the future.

Example:
```
__auto_type server = [[HTTPServer alloc] initWithPort: 8080 backlog: 100 anyAddress: NO multithreaded: NO];

if ([server isReadyToAccept] == NO) {
    NSLog(@"failed to create server");
    exit(1);
}

[server serveWithBlock: ^(HTTPRequest* request) {
    NSLog(@"new request: %@ %@ %lu", request.URL.path, request.method, [request.body length]);
    __auto_type input = [[NSString alloc] initWithData: request.body
                                              encoding: NSUTF8StringEncoding];
    NSMutableString* output = [input mutableCopy];
    [output appendString: input];
    return [[HTTPResponse alloc] initWithStatus: 200
                                           body: [output dataUsingEncoding: NSUTF8StringEncoding]
                                        headers: nil];
}];
```
