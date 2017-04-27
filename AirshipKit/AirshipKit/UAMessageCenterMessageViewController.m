/* Copyright 2017 Urban Airship and Contributors */

#import "UAMessageCenterMessageViewController.h"
#import "UAWKWebViewNativeBridge.h"
#import "UAInbox.h"
#import "UAirship.h"
#import "UAInboxMessageList.h"
#import "UAInboxMessage.h"
#import "UAUtils.h"
#import "UAMessageCenterLocalization.h"

#define kMessageUp 0
#define kMessageDown 1

@interface UAMessageCenterMessageViewController () <UAWKWebViewDelegate>

@property (nonatomic, strong) UAWKWebViewNativeBridge *nativeBridge;

/**
 * The WebView used to display the message content.
 */
@property (nonatomic, strong) WKWebView *webView;

/**
 * The index of the currently displayed message.
 */
@property (nonatomic, assign) NSUInteger messageIndex;

/**
 * The view displayed when there are no messages.
 */
@property (nonatomic, weak) IBOutlet UIView *coverView;

/**
 * The label displayed in the coverView.
 */
@property (nonatomic, weak) IBOutlet UILabel *coverLabel;

/**
 * Convenience accessor for the messages currently available for display.
 */
@property (nonatomic, readonly) NSArray *messages;

@end

@implementation UAMessageCenterMessageViewController

- (void)dealloc {
    self.webView.navigationDelegate = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.nativeBridge = [[UAWKWebViewNativeBridge alloc] init];
    self.nativeBridge.forwardDelegate = self;
    self.webView.navigationDelegate = self.nativeBridge;

    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 0, 0}]) {
        // Allow the webView to detect data types (e.g. phone numbers, addresses) at will
        [self.webView.configuration setDataDetectorTypes:WKDataDetectorTypeAll];
    }

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_delete")
                                                                               style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(delete:)];

    self.coverLabel.text = UAMessageCenterLocalizedString(@"ua_message_not_selected");

    if (self.message) {
        [self loadMessageForID:self.message.messageID];
    } else {
        [self cover];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageListUpdated)
                                                 name:UAInboxMessageListUpdatedNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UAInboxMessageListUpdatedNotification object:nil];
}

// Note: since the message list is refreshed with new model objects when reloaded,
// we can't reliably hold onto any single instance. This method is mostly for convenience.
- (NSArray *)messages {
    NSArray *allMessages = [UAirship inbox].messageList.messages;
    if (self.filter) {
        return [allMessages filteredArrayUsingPredicate:self.filter];
    } else {
        return allMessages;
    }
}

#pragma mark -
#pragma mark UI

- (void)delete:(id)sender {
    if (self.message) {
        [[UAirship inbox].messageList markMessagesDeleted:@[self.message] completionHandler:nil];
    }
}

- (void)cover {
    self.title = nil;
    self.coverView.hidden = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void)uncover {
    self.coverView.hidden = YES;
    self.navigationItem.rightBarButtonItem.enabled = YES;
}

- (void)loadMessageForID:(NSString *)mid {
    NSUInteger index = NSNotFound;

    for (NSUInteger i = 0; i < [self.messages count]; i++) {
        UAInboxMessage *message = [self.messages objectAtIndex:i];
        if ([message.messageID isEqualToString:mid]) {
            index = i;
            break;
        }
    }

    if (index == NSNotFound) {
        UALOG(@"Can not find message with ID: %@", mid);
        return;
    }

    [self loadMessageAtIndex:index];
}

- (void)loadMessageAtIndex:(NSUInteger)index {
    self.messageIndex = index;

    [self.webView stopLoading];

    self.message = [self.messages objectAtIndex:index];
    if (self.message == nil) {
        UALOG(@"Unable to find message with index: %lu", (unsigned long)index);
        return;
    }

    [self uncover];
    self.title = self.message.title;

    NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:self.message.messageBodyURL];
    requestObj.timeoutInterval = 60;

    NSString *auth = [UAUtils userAuthHeaderString];
    [requestObj setValue:auth forHTTPHeaderField:@"Authorization"];

    [self.webView loadRequest:requestObj];
}

- (void)displayAlert:(BOOL)retry {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:UAMessageCenterLocalizedString(@"ua_connection_error")
                                                                   message:UAMessageCenterLocalizedString(@"ua_mc_failed_to_load")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_ok")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];

    if (retry) {
        UIAlertAction *retryAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_retry_button")
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
                                                                [self loadMessageAtIndex:self.messageIndex];
        }];

        [alert addAction:retryAction];
    }

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark UAWKWebViewDelegate

- (void)webView:(WKWebView *)wv decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)navigationResponse.response;
        NSInteger status = httpResponse.statusCode;
        NSString *blank = @"about:blank";
        if (status >= 400 && status <= 599) {
            decisionHandler(WKNavigationResponsePolicyCancel);
            [wv loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:blank]]];
            if (status >= 500) {
                // Display a retry alert
                [self displayAlert:YES];
            } else {
                // Display a generic alert
                [self displayAlert:NO];
            }
            return;
        }
    }
    
    decisionHandler(WKNavigationResponsePolicyAllow);

}

- (void)webView:(WKWebView *)wv didFinishNavigation:(WKNavigation *)navigation {
    NSString *blank = @"about:blank";
    if ([wv.URL.absoluteString isEqualToString:blank]) {
        return;
    }
    
    // Mark message as read after it has finished loading
    if (self.message.unread) {
        [self.message markMessageReadWithCompletionHandler:nil];
    }
}

- (void)webView:(WKWebView *)wv didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (error.code == NSURLErrorCancelled)
        return;
    UALOG(@"Failed to load message: %@", error);
    [self displayAlert:YES];
}

- (void)closeWindowAnimated:(BOOL)animated {
    if (self.closeBlock) {
        self.closeBlock(animated);
    }
}

#pragma mark NSNotificationCenter callbacks

- (void)messageListUpdated {

    if (self.messages.count) {
        // If the index path is still accessible,
        // find the nearest accessible neighbor
        NSUInteger index = MIN(self.messages.count - 1, self.messageIndex);

        UAInboxMessage *currentMessageAtIndex = [self.messages objectAtIndex:index];

        if (self.message) {
            // if the index has changed
            if (![self.message.messageID isEqual:currentMessageAtIndex.messageID]) {
                // reload the message at that index
                [self loadMessageAtIndex:index];
            } else {
                // refresh the stored instance
                self.message = currentMessageAtIndex;
            }
        }

    } else {
        // There are no more messages to display, so cover up the UI.
        self.message = nil;
        [self cover];
    }
}

@end