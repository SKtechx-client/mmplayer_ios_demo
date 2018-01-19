//
//  ViewController.m
//  MusicMatePlayerDemo
//
//  Created by 1100442 on 2017. 11. 14..
//  Copyright © 2017년 sktechx. All rights reserved.
//

#import "ViewController.h"
#import "MusicMatePlayerDemo-Swift.h"

#import <WebKit/WebKit.h>

@interface ViewController () <WKScriptMessageHandler, PlayerControllerDelegate>
    
@property (nonatomic, weak) WKWebView *webView;
    
@end

@implementation ViewController
    
static NSString * const messageHandlerName = @"musicmate";
static NSString * const frontendURL = @"http://211.188.213.11/apigw/v1/page/lpoint/home?user_id=12345678";
//static NSString * const frontendURL = @"http://10.211.249.187:5000";

- (BOOL)prefersStatusBarHidden {
    return YES;
}
    
- (void)loadView {
    [super loadView];
    
    WKUserContentController *userContentController = [WKUserContentController new];
    [userContentController addScriptMessageHandler:self name:messageHandlerName];
    
    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    configuration.userContentController = userContentController;
    
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    webView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:webView];
    
    NSArray<NSLayoutConstraint *> *constraints = [NSArray arrayWithObjects:
                                                  [NSLayoutConstraint constraintWithItem:webView
                                                                               attribute:NSLayoutAttributeLeading
                                                                               relatedBy:NSLayoutRelationEqual
                                                                                  toItem:self.view
                                                                               attribute:NSLayoutAttributeLeading
                                                                              multiplier:1
                                                                                constant:0],
                                                  [NSLayoutConstraint constraintWithItem:webView
                                                                               attribute:NSLayoutAttributeTrailing
                                                                               relatedBy:NSLayoutRelationEqual
                                                                                  toItem:self.view
                                                                               attribute:NSLayoutAttributeTrailing
                                                                              multiplier:1
                                                                                constant:0],
                                                  [NSLayoutConstraint constraintWithItem:webView
                                                                               attribute:NSLayoutAttributeTop
                                                                               relatedBy:NSLayoutRelationEqual
                                                                                  toItem:self.view
                                                                               attribute:NSLayoutAttributeTop
                                                                              multiplier:1
                                                                                constant:0],
                                                  [NSLayoutConstraint constraintWithItem:webView
                                                                               attribute:NSLayoutAttributeBottom
                                                                               relatedBy:NSLayoutRelationEqual
                                                                                  toItem:self.view
                                                                               attribute:NSLayoutAttributeBottom
                                                                              multiplier:1
                                                                                constant:0], nil];
    [NSLayoutConstraint activateConstraints:constraints];
    self.webView = webView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURL *url = [NSURL URLWithString:frontendURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:request];
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    PlayerController.shared.delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    PlayerController.shared.delegate = nil;
}

// MARK: - Notifications

- (void)willEnterForeground:(NSNotification *)notification {
    [self evaluateJavascript:@"onResume(true)"];
}

- (void)didEnterBackground:(NSNotification *)notification {
    [self evaluateJavascript:@"onResume(false)"];
}

// MARK: - WKWebView Message Handler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    [PlayerController.shared processCommandWithJson:message.body];
}
    
// MARK: - PlayerControllerDelegate

- (void)controller:(PlayerController *)_ didChangeMetaData:(NSString * _Nonnull)data {
    NSString *script = [NSString stringWithFormat:@"onMetadata(%@)", data];
    [self evaluateJavascript:script];
}
    
- (void)controller:(PlayerController *)_ didChangeState:(NSString *)state {
    NSString *script = [NSString stringWithFormat:@"onState(%@)", state];
    [self evaluateJavascript:script];
}
    
- (void)controller:(PlayerController *)_ didReceivePlayResponse:(NSString *)response {
    NSString *script = [NSString stringWithFormat:@"onPlayResponse(%@)", response];
    [self evaluateJavascript:script];
}
    
- (void)controller:(PlayerController *)_ didReceiveLogResponse:(NSString *)code {
    NSString *script = [NSString stringWithFormat:@"onTicket(%@)", code];
    [self evaluateJavascript:script];
}

- (void)controller:(PlayerController *)_ didRetriveVersion:(NSString *)version {
    NSString *script = [NSString stringWithFormat:@"onVersion(\"%@\")", version];
    [self evaluateJavascript:script];
}

- (void)controller:(PlayerController *)_ didRetriveSessionToken:(NSString *)token {
    NSString *script = [NSString stringWithFormat:@"onToken(\"%@\")", token];
    [self evaluateJavascript:script];
}

- (void)controller:(PlayerController *)_ didRetriveProperty:(NSString *)property {
    NSString *script = [NSString stringWithFormat:@"onProperty(%@)", property];
    [self evaluateJavascript:script];
}

- (void)controller:(PlayerController *)_ didRetriveRepeat:(long)repeat {
    NSString *script = [NSString stringWithFormat:@"onRepeat(%ld)", repeat];
    [self evaluateJavascript:script];
}

- (void)controller:(PlayerController *)_ didRetriveShuffle:(BOOL)shuffle {
    NSString *script = [NSString stringWithFormat:@"onShuffle(%@)", shuffle ? @"true" : @"false"];
    [self evaluateJavascript:script];
}

- (void)evaluateJavascript:(NSString *)javascript {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.webView evaluateJavaScript:javascript completionHandler:^(id result, NSError *error) {
            NSLog(@"Script: %@, Result: %@, Error: %@", javascript, result, error);
        }];
    });
}
    
@end
