# cf-http
CF HTTP server

Example:
```
__auto_type server = [[HTTPServer alloc] initWithPort: 8080];

if ([server isReadyToAccept] == NO) {
    NSLog(@"failed to create server");
    exit(1);
}

[server serveWithBlock: ^(HTTPRequest* request) {
    NSLog(@"new request: %@ %@ %lu", request.path, request.method, [request.body length]);
    __auto_type input = [[NSString alloc] initWithData: request.body
                                              encoding: NSUTF8StringEncoding];
    NSMutableString* output = [input mutableCopy];
    [output appendString: input];
    return [[HTTPResponse alloc] initWithStatus: 200
                                           body: [output dataUsingEncoding: NSUTF8StringEncoding]];
}];
```
