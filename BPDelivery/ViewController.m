//
//  ViewController.m
//  BPDelivery
//
//  Created by Jonathan Jungck on 7/12/17.
//  Copyright © 2017 Jonathan Jungck. All rights reserved.
//

#import "ViewController.h"
#import "DJIFlightHelpers.h"
#import <VideoPreviewer/VideoPreviewer.h>
#import <Photos/Photos.h>
#include "TargetConditionals.h"

@interface ViewController () <DJISDKManagerDelegate, DJICameraDelegate, DJIVideoFeedListener, DJIBaseProductDelegate, DJIPlaybackDelegate>

@property (weak, nonatomic) IBOutlet UIButton *takeOffButton;
@property (weak, nonatomic) IBOutlet UIImageView *droneImage;
@property(nonatomic, weak) DJIBaseProduct* product;
@property (nonatomic, strong) DJICamera* camera;
@property (weak, nonatomic) IBOutlet UILabel *productConnectionStatus;
@property (weak, nonatomic) IBOutlet UILabel *productModel;
@property (weak, nonatomic) IBOutlet UISwitch *restEnabledSwitch;
@property (weak, nonatomic) IBOutlet UIView *sectionHeaderView;

@property (weak, nonatomic) NSString* pid;

@property (strong, nonatomic) DJICameraSystemState* cameraSystemState;
@property (strong, nonatomic) DJICameraPlaybackState* cameraPlaybackState;

@property (assign, nonatomic) int selectedFileCount;
@property (strong, nonatomic) NSMutableData *downloadedImageData;
@property (strong, nonatomic) NSTimer *updateImageDownloadTimer;
@property (strong, nonatomic) NSError *downloadImageError;
@property (strong, nonatomic) NSString* targetFileName;
@property (assign, nonatomic) long totalFileSize;
@property (assign, nonatomic) long currentDownloadSize;
@property (assign, nonatomic) int downloadedFileCount;

@property (weak, nonatomic) IBOutlet UIView *fpvPreviewView;
@property (strong, nonatomic) dispatch_source_t timer;
@end

@implementation ViewController

#pragma mark - UI Initializers
- (void)viewDidLoad {
    [super viewDidLoad];
    [self initializeTimer];
    [self.restEnabledSwitch setOn:false];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [[VideoPreviewer instance] setView:self.fpvPreviewView];
    [self registerApp];
    [self roundCornersOnView:self.sectionHeaderView onTopLeft:YES topRight:YES bottomLeft:NO bottomRight:NO radius:5];
}

-(void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    //TODO: Remove later if this works
//    [[VideoPreviewer instance] setView:nil];
//    [[DJISDKManager videoFeeder].primaryVideoFeed removeListener:self];
    [self resetVideoPreview];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (UIView *)roundCornersOnView:(UIView *)view onTopLeft:(BOOL)tl topRight:(BOOL)tr bottomLeft:(BOOL)bl bottomRight:(BOOL)br radius:(float)radius
{
    if (tl || tr || bl || br) {
        UIRectCorner corner = 0;
        if (tl) corner = corner | UIRectCornerTopLeft;
        if (tr) corner = corner | UIRectCornerTopRight;
        if (bl) corner = corner | UIRectCornerBottomLeft;
        if (br) corner = corner | UIRectCornerBottomRight;
        
        UIView *roundedView = view;
        UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:roundedView.bounds byRoundingCorners:corner cornerRadii:CGSizeMake(radius, radius)];
        CAShapeLayer *maskLayer = [CAShapeLayer layer];
        maskLayer.frame = roundedView.bounds;
        maskLayer.path = maskPath.CGPath;
        roundedView.layer.mask = maskLayer;
        return roundedView;
    }
    return view;
}

#pragma mark - DJI SDK
/*
 Register the application with the DJI SDK
 */
- (void)registerApp {
    [DJISDKManager registerAppWithDelegate:self];
}

/*
 Handle application registration response
 */
- (void)appRegisteredWithError:(NSError *)error {
    NSString* message = @"App successfully registered!";
    if (error) {
        message = @"App registration failed. API key configured incorrectly, or network not available.";
    } else {
    #if (TARGET_OS_SIMULATOR)
        [DJISDKManager enableBridgeModeWithBridgeAppIP:@"192.168.0.4"];
        NSLog(@"Debug Bridge Mode Enabled");
    #endif
        NSLog(@"registerAppSuccess");
    }
    
    //[self showAlertViewWithTitle:@"API Registration" withMessage:message];
}

/*
 DJI Calls this method when the drone is connected via the controller to USB.
 */
-(void) productConnected:(DJIBaseProduct* _Nullable) product {
    __weak typeof(self) weakSelf = self;
    if (product) {
        self.product = product;
        [product setDelegate:self];
        DJICamera* camera = [DJIFlightHelpers fetchCamera];
        if (camera != nil) {
            [camera setDelegate:self];
            [camera.playbackManager setDelegate:self];
            NSLog(@"Camera Connected");
            [camera setMode:DJICameraModeShootPhoto withCompletion:nil];
            [camera setFocusMode:DJICameraFocusModeAuto withCompletion:nil];
        }
        
        [self showAlertViewWithTitle:@"Initialized" withMessage:[NSString stringWithFormat:@"Connected to %@", [weakSelf.product model]]];
        [[DJISDKManager videoFeeder].primaryVideoFeed addListener:self withQueue:nil];
        [[VideoPreviewer instance] start];
    }
    
    [self updateStatusBasedOn:product];
}

-(void) resetVideoPreview {
    [[VideoPreviewer instance] unSetView];
    [[DJISDKManager videoFeeder].primaryVideoFeed removeListener:self];
}

-(void) productDisconnected {
    NSString* message = [NSString stringWithFormat:@"Connection lost. Back to root. "];
    [self showAlertViewWithTitle:@"Disconnected" withMessage:message];
    self.product = nil;
     [self updateStatusBasedOn:nil];
    [self resetVideoPreview];
}

-(void) updateStatusBasedOn:(DJIBaseProduct* )newConnectedProduct {
    if (newConnectedProduct){
        _productConnectionStatus.text = NSLocalizedString(@"Status: Product Connected", @"");
        _productModel.text = [NSString stringWithFormat:NSLocalizedString(@"Model: \%@", @""),newConnectedProduct.model];
        _productModel.hidden = NO;
        //WeakRef(target);
        [newConnectedProduct getFirmwarePackageVersionWithCompletion:^(NSString * _Nonnull version, NSError * _Nullable error) {
            //WeakReturn(target);
            if (error == nil) {
                //[target updateFirmwareVersion:version];
            }else {
                //[target updateFirmwareVersion:nil];
            }
        }];
        flightController = [DJIFlightHelpers fetchFlightController];
        __weak typeof(self) weakSelf = self;
        if (flightController) {
            [flightController setMaxFlightHeight:20 withCompletion:^(NSError * _Nullable error) {
                if (error) {
                    [weakSelf showAlertViewWithTitle:@"Error" withMessage:[NSString stringWithFormat:@"Error setting max height: %@.", error]];
                }
            }];
            [flightController setMaxFlightRadius:15  withCompletion:^(NSError * _Nullable error) {
                if (error) {
                    [weakSelf showAlertViewWithTitle:@"Error" withMessage:[NSString stringWithFormat:@"Error setting max radius: %@.", error]];
                }
            }];
            [flightController setGoHomeHeightInMeters:20 withCompletion:nil];
        } else {
            [self showAlertViewWithTitle:@"Error" withMessage:@"Flight controller does not exist."];
        }
    }else {
        _productConnectionStatus.text = NSLocalizedString(@"Status: Product Not Connected", @"");
        _productModel.text = NSLocalizedString(@"Model: Unknown", @"");
        //[self updateFirmwareVersion:nil];
    }
}

#pragma mark - DJIVideoFeedListener
-(void) videoFeed:(DJIVideoFeed *) videoFeed didUpdateVideoData:(nonnull NSData *)videoData {
    [[VideoPreviewer instance] push:(uint8_t *)videoData.bytes length:(int)videoData.length];
    
}

#pragma mark - DJICameraDelegate
-(void) camera:(DJICamera*)camera didUpdateSystemState:(DJICameraSystemState*)systemState
{
    self.cameraSystemState = systemState;
    //BOOL isPlayback = (systemState.mode == DJICameraModePlayback) || (systemState.mode == DJICameraModeMediaDownload);
    
}

#pragma mark - DJIPlaybackDelegate
-(void)playbackManager:(DJIPlaybackManager *)playbackManager didUpdatePlaybackState:(DJICameraPlaybackState *)playbackState {
    self.cameraPlaybackState = playbackState;
}

#pragma mark - UI
- (IBAction)takeOffButtonPressed:(UIButton *)sender {
    [self.takeOffButton setBackgroundColor:[UIColor colorWithRed:0.36 green:0.72 blue:0.36 alpha:1.0]];
    [self.takeOffButton setTitle:@"Taking Off" forState:UIControlStateNormal];
    flightController = [DJIFlightHelpers fetchFlightController];
    if (flightController) {
        [flightController startTakeoffWithCompletion:^(NSError * _Nullable error) {
            if (error) {
                [self resetTakeoffButton];
                [self showAlertViewWithTitle:@"Error" withMessage:@"Takeoff failed."];
                
            } else {
                [self.takeOffButton setBackgroundColor:[UIColor colorWithRed:0.85 green:0.33 blue:0.31 alpha:1.0]];
                [self.takeOffButton setTitle:@"Land" forState:UIControlStateNormal];
                [self moveCameraDown];
            }
        }];
    } else {
        [self showAlertViewWithTitle:@"Error" withMessage:@"Flight Controller not found."];
    }
}

- (IBAction)landButtonPressed:(UIButton *)sender {
    flightController = [DJIFlightHelpers fetchFlightController];
    if (flightController) {
        [flightController startLandingWithCompletion:^(NSError * _Nullable error) {
            if (error) {
                [self showAlertViewWithTitle:@"Error" withMessage:@"Landing failed."];
            } else {
                //[self uploadPhoto];
                //TODO TEST
                [self resetTakeoffButton];
            }
        }];
    } else {
        [self showAlertViewWithTitle:@"Error" withMessage:@"Flight Controller not found."];
    }
    
}

- (void) resetTakeoffButton {
    [self.takeOffButton setBackgroundColor:[UIColor colorWithRed:0.96 green:0.47 blue:0.13 alpha:1.0]];
    [self.takeOffButton setTitle:@"Manual Start" forState:UIControlStateNormal];
}

- (IBAction)takePicturePressed:(UIButton *)sender {
    // to do
}

-(void) moveCameraDown {
    gimbal = [DJIFlightHelpers fetchGimbal];
    if (gimbal) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            DJIGimbalRotation * gimbalRotation = [DJIGimbalRotation gimbalRotationWithPitchValue:@-45.0 rollValue:0 yawValue:0 time:5 mode:DJIGimbalRotationModeAbsoluteAngle];
            [gimbal rotateWithRotation:gimbalRotation completion:^(NSError * _Nullable error) {
                if (error) {
                    [self showAlertViewWithTitle:@"Error" withMessage:@"Gimbal error."];
                } else {
                    [self takePicture];
                }
            }];
        });
    } else {
        [self showAlertViewWithTitle:@"Error" withMessage:@"Gimbal not found."];
    }
}

-(void) moveCameraUp {
    gimbal = [DJIFlightHelpers fetchGimbal];
    if (gimbal) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self downloadButtonAction:nil];
            DJIGimbalRotation * gimbalRotation = [DJIGimbalRotation gimbalRotationWithPitchValue:@0 rollValue:0 yawValue:0 time:5 mode:DJIGimbalRotationModeAbsoluteAngle];
            [gimbal rotateWithRotation:gimbalRotation completion:^(NSError * _Nullable error) {
                if (error) {
                    [self showAlertViewWithTitle:@"Error" withMessage:@"Gimbal error."];
                } else {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self landButtonPressed:nil];
                    });
                }
            }];
        });
    } else {
        [self showAlertViewWithTitle:@"Error" withMessage:@"Gimbal not found."];
    }
}

-(void) takePicture {
    __weak DJICamera* camera = [DJIFlightHelpers fetchCamera];
    [camera setMode:DJICameraModeShootPhoto withCompletion:nil];
    camera.delegate = self;
    if (camera) {
        [camera setShootPhotoMode:DJICameraShootPhotoModeSingle withCompletion:^(NSError * _Nullable error) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                //TODO: Focus Camera
                [camera startShootPhotoWithCompletion:^(NSError * _Nullable error) {
                    if (error) {
                       [self showAlertViewWithTitle:@"Error" withMessage:[NSString stringWithFormat:@"Camera Error: %@", error]];
                    } else {
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [self moveCameraUp];
                        });
                    }
                }];
            });
        }];
    }
}

- (IBAction)refreshButtonPressed:(UIButton *)sender {
    flightController = [DJIFlightHelpers fetchFlightController];
    /*if (flightController) {
        [flightController getMaxFlightHeightWithCompletion:^(float height, NSError * _Nullable error) {
            _maxHeight.text = [NSString stringWithFormat:@"Maximum Height: %.1fm", height];
        }];
        [flightController getMaxFlightRadiusWithCompletion:^(float radius, NSError * _Nullable error) {
            _maxRadius.text = [NSString stringWithFormat:@"Maximum Radius: %.1fm", radius];
        }];
    }*/
}

- (void) getData {
    DJICamera* camera = [DJIFlightHelpers fetchCamera];
    if (camera != nil) {
        [camera setMode:DJICameraModeMediaDownload withCompletion:^(NSError * _Nullable error) {
            if (error) {
                [self showAlertViewWithTitle:@"Camera Error" withMessage:error.description];
            }
        }];
    }
}

-(void) initData {
    self.downloadedImageData = [NSMutableData data];
}

- (void)resetDownloadData
{
    self.downloadImageError = nil;
    self.totalFileSize = 0;
    self.currentDownloadSize = 0;
    self.downloadedFileCount = 0;
    
    [self.downloadedImageData setData:[NSData dataWithBytes:NULL length:0]];
}

- (void)updateDownloadProgress:(NSTimer *)updatedTimer
{
    if (self.downloadImageError) {
        
        [self stopTimer];
        //[self.selectBtn setTitle:@"Select" forState:UIControlStateNormal];
        //[self updateStatusAlertContentWithTitle:@"Download Error" message:[NSString stringWithFormat:@"%@", self.downloadImageError] shouldDismissAfterDelay:YES];
        
    }
    else
    {
        NSString *title = [NSString stringWithFormat:@"Download (%d/%d)", self.downloadedFileCount + 1, self.selectedFileCount];
        NSString *message = [NSString stringWithFormat:@"FileName:%@, FileSize:%0.1fKB, Downloaded:%0.1fKB", self.targetFileName, self.totalFileSize / 1024.0, self.currentDownloadSize / 1024.0];
        //[self updateStatusAlertContentWithTitle:title message:message shouldDismissAfterDelay:NO];
    }
    
}

- (IBAction)downloadButtonAction:(UIButton *)sender {
    self.selectedFileCount = self.cameraPlaybackState.selectedFileCount;
    
    if (self.cameraPlaybackState.playbackMode == DJICameraPlaybackModeMultipleFilesEdit) {
        
        if (self.selectedFileCount == 0) {
            /*[self showStatusAlertView];
            [self updateStatusAlertContentWithTitle:@"Please select files to Download!" message:@"" shouldDismissAfterDelay:YES];*/
            return;
        }else
        {
            NSString *title;
            if (self.selectedFileCount == 1) {
                title = @"Download Selected File?";
            }else
            {
                title = @"Download Selected Files?";
            }
            [self loadMediaListsForMediaDownloadMode];
        }
        
    }else if (self.cameraPlaybackState.playbackMode == DJICameraPlaybackModeSingleFilePreview){
        
        [self loadMediaListsForMediaDownloadMode];
    }
}


-(void)loadMediaListsForMediaDownloadMode {
    DJICamera *camera = [DJIFlightHelpers fetchCamera];
    [camera setMode:DJICameraModeMediaDownload withCompletion:^(NSError * _Nullable error) {
        //[self showDownloadProgressAlert];
        //[self.downloadProgressAlert setTitle:[NSString stringWithFormat:@"Refreshing file list. "]];
        //[self.downloadProgressAlert setMessage:[NSString stringWithFormat:@"Loading..."]];
        NSLog(@"Loading files...");
        //weakSelf(target);
        [camera.mediaManager refreshFileListWithCompletion:^(NSError * _Nullable error) {
            //weakReturn(target);
            if (error) {
                //[target.downloadProgressAlert dismissWithClickedButtonIndex:0 animated:YES];
                //target.downloadProgressAlert = nil;
                NSLog(@"Refresh file list failed: %@", error.description);
            }
            else {
                [self downloadPhotosForMediaDownloadMode];
            }
        }];
    }];
}

-(void)downloadPhotosForMediaDownloadMode {
    __block int finishedFileCount = 0;
    
    DJICamera *camera = [DJIFlightHelpers fetchCamera];
    NSArray<DJIMediaFile *> *files = [camera.mediaManager fileListSnapshot];
    [camera.mediaManager.taskScheduler resumeWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error, %@", error.description);
        }
    }];
    NSLog(@"Downloading");
    DJIMediaFile *file = files.lastObject;
    
    DJIFetchMediaTask *task = [DJIFetchMediaTask taskWithFile:file content:DJIFetchMediaTaskContentPreview andCompletion:^(DJIMediaFile * _Nonnull file, DJIFetchMediaTaskContent content, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error, %@", error.description);
        }
        else {
            [self saveImageToServer:file.preview];
            finishedFileCount++;
            NSLog(@"Finished files: , %d", finishedFileCount);
            if (finishedFileCount == 1) {
                [camera setMode:DJICameraModeShootPhoto withCompletion:^(NSError * _Nullable error) {
                    if (error) {
                        NSLog(@"Error, %@", error.description);
                    }
                    //TODO TEST
                    [self confirmLanding];
                }];
            }
        }
    }];
    [camera.mediaManager.taskScheduler moveTaskToEnd:task];
}

- (void)startUpdateTimer
{
    if (self.updateImageDownloadTimer == nil) {
        self.updateImageDownloadTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateDownloadProgress:) userInfo:nil repeats:YES];
    }
}
- (void)stopTimer
{
    if (self.updateImageDownloadTimer != nil) {
        [self.updateImageDownloadTimer invalidate];
        self.updateImageDownloadTimer = nil;
    }
}

#pragma mark - UI helpers
/*
 Alert View with OK button
 */
- (void)showAlertViewWithTitle:(NSString* )title withMessage:(NSString*)message {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
    
}

#pragma mark - REST Controller
- (void) initializeTimer {
    if (!self.timer) {
        self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    }
    if (self.timer) {
        dispatch_source_set_timer(self.timer, dispatch_walltime(NULL, 0), 1ull*NSEC_PER_SEC, 10ull*NSEC_PER_SEC);
        dispatch_source_set_event_handler(_timer, ^(void) {
            [self tick];
        });
    }
}


-(void) tick {
    // REST HERE
    NSURL *url = [NSURL URLWithString:@"https://flight-services.bp-3cloud.com/flightStatus"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        if (data.length > 0 && connectionError == nil) {
            NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            NSString *responseString = [response objectForKey:@"takeoff"];
            if (![responseString isEqualToString:@"HOLD"]) {
                NSLog([response objectForKey:@"takeoff"]);
                self.pid = [response objectForKey:@"takeoff"];
                NSLog(@"TAKE OFF!");
                [self.restEnabledSwitch setOn:NO];
                [self restSwitchChanged:self.restEnabledSwitch];
                [self takeOffButtonPressed:nil];
                NSURL *url = [NSURL URLWithString:@"https://flight-services.bp-3cloud.com/confirmed"];
                NSURLRequest *request = [NSURLRequest requestWithURL:url];
                [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:nil];
            }
        }
    }];
    
    NSLog(@"REST Timer Fired");
}

-(void) confirmLanding {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://flight-services.bp-3cloud.com/landingConfirmed/%@", self.pid]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:nil];
}

- (IBAction)restSwitchChanged:(UISwitch *)sender {
    if (sender.isOn) {
        dispatch_resume(_timer);
    } else {
        dispatch_suspend(_timer);
    }
}

-(void)saveImageToServer:(UIImage*) downloadImage
{
    PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
    fetchOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:fetchOptions];
    PHAsset *lastAsset = [fetchResult lastObject];
    [[PHImageManager defaultManager] requestImageForAsset:lastAsset
                                               targetSize:self.fpvPreviewView.bounds.size
                                              contentMode:PHImageContentModeAspectFill
                                                  options:PHImageRequestOptionsVersionCurrent
                                            resultHandler:^(UIImage *result, NSDictionary *info) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // convert image to NSData
            NSData *dataImage = UIImageJPEGRepresentation(downloadImage, 100.0f);
            [[self droneImage] setImage:downloadImage];
            // set your URL Where to Upload Image
            NSString *urlString = @"https://flight-services.bp-3cloud.com/img";
            
            // set your Image Name
            NSString *filename = @"INSPECTIONIMG1";
            
            // Create 'POST' MutableRequest with Data and Other Image Attachment.
            NSMutableURLRequest* request= [[NSMutableURLRequest alloc] init];
            [request setURL:[NSURL URLWithString:urlString]];
            [request setHTTPMethod:@"POST"];
            NSString *boundary = @"---------------------------14737809831466499882746641449";
            NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
            [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
            NSMutableData *postbody = [NSMutableData data];
            [postbody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            [postbody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"%@.jpg\"\r\n", filename] dataUsingEncoding:NSUTF8StringEncoding]];
            [postbody appendData:[[NSString stringWithFormat:@"Content-Type: application/octet-stream\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
            [postbody appendData:[NSData dataWithData:dataImage]];
            [postbody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            [request setHTTPBody:postbody];
            
            // Get Response of Your Request
            NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
            NSString *responseString = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding];
            NSLog(@"Response  %@",responseString);
        });
    }];
}



@end
