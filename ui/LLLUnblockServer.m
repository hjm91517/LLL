//
//  ui/LLLUnblockServer.m
//  设备内本地换源服务：CFSocket 起一个极简 HTTP/1.1，只处理 GET /match。
//

#import "LLLUnblockServer.h"
#import "LLLUnblockSource.h"
#import "BaseComponents.h"

#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <fcntl.h>
#import <string.h>

static NSString * const kAutoKey = @"LLL.unblockAuto";
static const uint16_t kDefaultPort = 18080;

@interface LLLUnblockServer ()
@property (nonatomic, assign) int listenFD;
@property (nonatomic, assign, readwrite) uint16_t port;
@property (nonatomic, strong) dispatch_queue_t q;
@property (nonatomic, assign) BOOL running;
@end

@implementation LLLUnblockServer

+ (instancetype)shared {
    static LLLUnblockServer *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [LLLUnblockServer new]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _listenFD = -1;
        _port = 0;
        _running = NO;
        _q = dispatch_queue_create("lll.unblock.server", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - 开关

- (BOOL)autoStartEnabled {
    NSNumber *n = [NSUserDefaults.standardUserDefaults objectForKey:kAutoKey];
    return n ? n.boolValue : YES;
}

- (void)setAutoStartEnabled:(BOOL)on {
    [NSUserDefaults.standardUserDefaults setBool:on forKey:kAutoKey];
}

- (NSString *)localBaseURL {
    if (!self.running || self.port == 0) return nil;
    return [NSString stringWithFormat:@"http://127.0.0.1:%u", self.port];
}

#pragma mark - 启动

- (BOOL)bindPort:(uint16_t)p {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return NO;

    int on = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));

    struct sockaddr_in a;
    memset(&a, 0, sizeof(a));
    a.sin_family = AF_INET;
    a.sin_port = htons(p);
    /* 只绑回环，不对外暴露 */
    a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    if (bind(fd, (struct sockaddr *)&a, sizeof(a)) != 0) {
        close(fd);
        return NO;
    }
    if (listen(fd, 16) != 0) {
        close(fd);
        return NO;
    }
    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK);

    self.listenFD = fd;
    self.port = p;
    return YES;
}

- (BOOL)start {
    if (self.running) return YES;

    uint16_t p = 0;
    if ([self bindPort:kDefaultPort]) {
        p = kDefaultPort;
    } else if ([self bindPort:kDefaultPort + 1]) {
        p = kDefaultPort + 1;
    } else {
        /* 让系统挑 */
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0) return NO;
        struct sockaddr_in a;
        memset(&a, 0, sizeof(a));
        a.sin_family = AF_INET;
        a.sin_port = htons(0);
        a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        if (bind(fd, (struct sockaddr *)&a, sizeof(a)) != 0 || listen(fd, 16) != 0) {
            close(fd);
            return NO;
        }
        socklen_t len = sizeof(a);
        getsockname(fd, (struct sockaddr *)&a, &len);
        fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK);
        self.listenFD = fd;
        self.port = ntohs(a.sin_port);
        p = self.port;
    }

    if (p == 0) return NO;
    self.running = YES;
    [self startAcceptLoop];
    lllLog(@"4.0 本地换源服务已启动 127.0.0.1:%u", self.port);
    return YES;
}

- (void)stop {
    self.running = NO;
    if (self.listenFD >= 0) {
        close(self.listenFD);
        self.listenFD = -1;
    }
    self.port = 0;
}

#pragma mark - 收连接

- (void)startAcceptLoop {
    __weak typeof(self) w = self;
    dispatch_source_t src = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ,
                                                   (uintptr_t)self.listenFD, 0, self.q);
    dispatch_source_set_event_handler(src, ^{
        __strong typeof(w) s = w;
        if (!s || !s.running) return;

        for (int i = 0; i < 8; i++) {
            int c = accept(s.listenFD, NULL, NULL);
            if (c < 0) break;
            [s handleClient:c];
        }
    });
    dispatch_resume(src);
}

#pragma mark - 处理一个请求

- (void)handleClient:(int)fd {
    /* 读请求头（最多 2KB，够用） */
    char buf[2048];
    ssize_t n = recv(fd, buf, sizeof(buf) - 1, 0);
    if (n <= 0) { close(fd); return; }
    buf[n] = 0;

    NSString *head = [NSString stringWithUTF8String:buf] ?: @"";
    NSArray *lines = [head componentsSeparatedByString:@"\r\n"];
    NSString *first = lines.count ? lines[0] : @"";

    NSArray *parts = [first componentsSeparatedByString:@" "];
    if (parts.count < 2) { [self sendText:fd code:400 body:@"{\"error\":\"bad request\"}"]; close(fd); return; }

    NSString *path = parts[1];
    NSRange qm = [path rangeOfString:@"?"];
    NSString *route = (qm.location == NSNotFound) ? path : [path substringToIndex:qm.location];
    NSString *query = (qm.location == NSNotFound) ? @"" : [path substringFromIndex:qm.location + 1];

    if (![route isEqualToString:@"/match"]) {
        [self sendText:fd code:404 body:@"{\"error\":\"unknown path\"}"];
        close(fd);
        return;
    }

    NSDictionary<NSString *, NSString *> *q = [self parseQuery:query];
    NSString *name = q[@"name"] ?: @"";
    NSString *artist = q[@"artist"] ?: @"";
    NSString *sid = q[@"id"] ?: @"";

    if (!name.length && !sid.length) {
        [self sendText:fd code:400 body:@"{\"error\":\"need name or id\"}"];
        close(fd);
        return;
    }

    __weak typeof(self) w = self;
    [[LLLUnblockSource shared] resolveSongID:(sid.length ? @(sid.longLongValue) : nil)
                                        name:name
                                      artist:artist
                                    duration:0
                                        done:^(NSURL *url, NSString *err) {
        __strong typeof(w) s = w;
        if (!s) { close(fd); return; }

        NSString *body;
        NSInteger code;
        if (url) {
            code = 200;
            body = [NSString stringWithFormat:
                    @"{\"url\":\"%@\",\"source\":\"kuwo\",\"br\":320000}",
                    url.absoluteString];
        } else {
            code = 404;
            body = [NSString stringWithFormat:@"{\"error\":\"%@\"}",
                    (err.length ? err : @"not found")];
        }
        [s sendText:fd code:code body:body];
        close(fd);
    }];
}

- (NSDictionary<NSString *, NSString *> *)parseQuery:(NSString *)query {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if (!query.length) return d;
    for (NSString *kv in [query componentsSeparatedByString:@"&"]) {
        NSRange eq = [kv rangeOfString:@"="];
        if (eq.location == NSNotFound) continue;
        NSString *k = [kv substringToIndex:eq.location];
        NSString *v = [kv substringFromIndex:eq.location + 1];
        k = [k stringByRemovingPercentEncoding] ?: k;
        v = [v stringByRemovingPercentEncoding] ?: v;
        if (k.length) d[k] = v;
    }
    return d;
}

- (void)sendText:(int)fd code:(NSInteger)code body:(NSString *)body {
    NSData *b = [body dataUsingEncoding:NSUTF8StringEncoding];
    NSString *h = [NSString stringWithFormat:
        @"HTTP/1.1 %ld %@\r\n"
         "Content-Type: application/json; charset=utf-8\r\n"
         "Content-Length: %lu\r\n"
         @"Connection: close\r\n\r\n",
        (long)code,
        (code == 200 ? @"OK" : (code == 404 ? @"Not Found" : @"Bad Request")),
        (unsigned long)b.length];

    NSMutableData *out = [NSMutableData data];
    [out appendData:[h dataUsingEncoding:NSUTF8StringEncoding]];
    [out appendData:b];

    const uint8_t *p = out.bytes;
    size_t left = out.length;
    while (left > 0) {
        ssize_t w = send(fd, p, left, 0);
        if (w <= 0) break;
        p += w;
        left -= (size_t)w;
    }
}

@end
