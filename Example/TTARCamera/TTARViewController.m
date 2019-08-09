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


@interface TTARStickerCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@end

@implementation TTARStickerCell

@end





@interface TTARViewController () <UICollectionViewDelegate, UICollectionViewDataSource>
@property (strong, nonatomic) TTARRecorder *arRecorder;
@property (strong, nonatomic) NSArray *stickerNames;
@property (assign, nonatomic) NSUInteger lastStickerItem;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@end

@implementation TTARViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor blackColor]];
    
    self.stickerNames = @[@"ocean", @"chewbacca", @"glasses", @"lolipopRabbit"];
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

- (BOOL)shouldAutorotate {
    return NO;
}

- (nonnull __kindof UICollectionViewCell *)collectionView:(nonnull UICollectionView *)collectionView cellForItemAtIndexPath:(nonnull NSIndexPath *)indexPath {
    TTARStickerCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];
    cell.imageView.image = [UIImage imageNamed:self.stickerNames[indexPath.item]];
    return cell;
}

- (NSInteger)collectionView:(nonnull UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.stickerNames.count;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *zipPath = [[NSBundle mainBundle] pathForResource:self.stickerNames[indexPath.item] ofType:@"zip"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = NSTemporaryDirectory();
    NSString *savePath = [path stringByAppendingString:[zipPath lastPathComponent]];
    if (![fileManager fileExistsAtPath:savePath]) {
        [fileManager copyItemAtPath:zipPath toPath:savePath error:NULL];
    }
    
    [self.arRecorder removeStickerPackage:@(self.lastStickerItem).stringValue];
    [self.arRecorder addStickerPackage:@(indexPath.item).stringValue zipPath:savePath];
    
    self.lastStickerItem = indexPath.item;
}

@end
