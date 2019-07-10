//
//  TTARViewController.m
//  TTARCamera
//
//  Created by wenzhaot on 07/09/2019.
//  Copyright (c) 2019 wenzhaot. All rights reserved.
//

#import "TTARViewController.h"
#import "TTARRecorder.h"

#define IPHONE_XSeries \
({BOOL isPhoneXSeries = NO;\
if (@available(iOS 11.0, *)) {\
isPhoneXSeries = [[UIApplication sharedApplication] delegate].window.safeAreaInsets.bottom > 0.0;\
}\
(isPhoneXSeries);})


@interface TTARViewController ()
@property (strong, nonatomic) TTARRecorder *arRecorder;
@end

@implementation TTARViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (_arRecorder == nil) {
        CGRect rect = [UIScreen mainScreen].bounds;
        if (IPHONE_XSeries) {
            rect = CGRectMake(0, 0, rect.size.width, 16.0/9 * rect.size.width);
        }
        
        self.arRecorder = [[TTARRecorder alloc] init];
        
        [self.view addSubview:self.arRecorder.preview];
        [self.arRecorder.preview setTranslatesAutoresizingMaskIntoConstraints:NO];
        
        NSLayoutConstraint *left = [self.arRecorder.preview.leftAnchor constraintEqualToAnchor:self.view.leftAnchor];
        NSLayoutConstraint *right = [self.arRecorder.preview.rightAnchor constraintEqualToAnchor:self.view.rightAnchor];
        NSLayoutConstraint *height = [self.arRecorder.preview.heightAnchor constraintEqualToConstant:rect.size.height];
        NSLayoutConstraint *top = nil;
        if (IPHONE_XSeries) {
            top = [self.arRecorder.preview.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor];
        } else {
            top = [self.arRecorder.preview.topAnchor constraintEqualToAnchor:self.view.topAnchor];
        }
        [NSLayoutConstraint activateConstraints:@[top, left, right, height]];
        [self.arRecorder startRunning:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"AR camera running error: %@", error.localizedDescription);
            }
        }];
    }
}

@end
