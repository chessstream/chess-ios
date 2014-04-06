//
//  CSMViewController.m
//  Chess Stream
//
//  Created by Daylen Yang on 4/5/14.
//  Copyright (c) 2014 Daylen Yang. All rights reserved.
//

#import "CSMViewController.h"
#import "CSMCaptureAndUploadVC.h"
#import "AVCamPreviewView.h"
#import "CSMImageUtils.h"
#import <AFNetworking/AFNetworking.h>
#import <GPUImage/GPUImage.h>

@interface CSMViewController ()

@property (strong, nonatomic) IBOutlet AVCamPreviewView *cameraPreview;

@property NSInteger gameID;

@property (strong, nonatomic) AVCaptureSession *session;
@property (strong, nonatomic) AVCaptureDevice *device;
@property (strong, nonatomic) AVCaptureDeviceInput *input;
@property (strong, nonatomic) AVCaptureVideoDataOutput *output;

@property (strong, nonatomic) AFHTTPRequestOperationManager *netMan;

@property NSInteger counter;
@property BOOL shouldUpload;

@end

@implementation CSMViewController

#define BASE_URL @"http://107.170.1.232/"
#define ID_ENDPOINT @"create"
#define UPLOAD_ENDPOINT @"update"

#define FRAMES_BETWEEN_UPLOADS 15

- (IBAction)lockUnlockFocusExposure:(UIBarButtonItem *)sender {
    if ([sender.title isEqualToString:@"Lock"]) {
        // Lock focus and exposure
        
        [self.device lockForConfiguration:NULL];
        
        CGPoint autofocusPoint = CGPointMake(0.5f, 0.5f);
        [self.device setFocusPointOfInterest:autofocusPoint];
        [self.device setFocusMode:AVCaptureFocusModeLocked];
        
        CGPoint exposurePoint = CGPointMake(0.5f, 0.5f);
        [self.device setExposurePointOfInterest:exposurePoint];
        [self.device setExposureMode:AVCaptureExposureModeLocked];
        
        [self.device unlockForConfiguration];
        
        sender.title = @"Unlock";
    } else {
        // Reset focus and exposure to default
        
        [self.device lockForConfiguration:NULL];
        
        CGPoint autofocusPoint = CGPointMake(0.5f, 0.5f);
        [self.device setFocusPointOfInterest:autofocusPoint];
        [self.device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        
        CGPoint exposurePoint = CGPointMake(0.5f, 0.5f);
        [self.device setExposurePointOfInterest:exposurePoint];
        [self.device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        
        [self.device unlockForConfiguration];
        
        sender.title = @"Lock";
    }
}


- (IBAction)toggleLight:(UIBarButtonItem *)sender {
    [self.device lockForConfiguration:NULL];
    if ([self.device torchMode] == AVCaptureTorchModeOff) {
        [self.device setTorchMode:AVCaptureTorchModeOn];
    } else {
        [self.device setTorchMode:AVCaptureTorchModeOff];
    }
    [self.device unlockForConfiguration];
}

- (IBAction)pressedButton:(UIBarButtonItem *)sender {
    if ([sender.title isEqualToString:@"Record"]) {
        BOOL success = [self askServerForNewID];
        if (success) {
            sender.title = @"Stop";
            NSLog(@"Created game. ID=%li", (long)self.gameID);
            self.shouldUpload = YES;
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Uh-oh" message:@"Could not contact the chess server." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
    } else {
        sender.title = @"Record";
        self.shouldUpload = NO;
    }
}

- (BOOL)askServerForNewID {
    NSString *str = [NSString stringWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", BASE_URL, ID_ENDPOINT]] usedEncoding:nil error:NULL];
    if (!str) {
        return NO;
    }
    self.gameID = [str integerValue];
    return self.gameID != 0;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.counter = 0;
    self.shouldUpload = NO;
    
    // Set up the session
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPresetHigh;
    
    // Set up the preview thingy
    self.cameraPreview.session = self.session;
    
    // Set up device
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // Input
    NSError *error = nil;
    self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:&error];
    if (!self.input) {
        NSLog(@"problem");
    }
    [self.session addInput:self.input];
    
    // Output
    self.output = [[AVCaptureVideoDataOutput alloc] init];
    [self.session addOutput:self.output];
    self.output.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA) };
    
    dispatch_queue_t queue = dispatch_queue_create("MyQueue", NULL);
    [self.output setSampleBufferDelegate:self queue:queue];
    
    // Start the camera
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        if (granted)
        {
            //Granted access to mediaType
            [self.session startRunning];
        }
        else
        {
            //Not granted access to mediaType
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIAlertView alloc] initWithTitle:@"AVCam!"
                                            message:@"AVCam doesn't have permission to use Camera, please change privacy settings"
                                           delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil] show];
            });
        }
    }];
    
    // Networking
    self.netMan = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:BASE_URL]];
    
}

/*
 * This method is called every time we get a new video frame.
 */
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (self.shouldUpload) {
        if (self.counter++ >= FRAMES_BETWEEN_UPLOADS) {
            // Reset the counter
            self.counter = 0;
            
            // Original image
            UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
            
            // Create sobel
            UIImage *sobel = [CSMImageUtils sobelImage:image];
            
            // Form the URL request
            NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST" URLString:[NSString stringWithFormat:@"%@%@", BASE_URL, UPLOAD_ENDPOINT] parameters:@{@"id" : [NSString stringWithFormat:@"%li", (long)self.gameID]} constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                [formData appendPartWithFileData:UIImageJPEGRepresentation(image, 1.0) name:@"original" fileName:@"original.jpg" mimeType:@"image/jpeg"];
                [formData appendPartWithFileData:UIImageJPEGRepresentation(sobel, 1.0) name:@"sobel" fileName:@"sobel.jpg" mimeType:@"image/jpeg"];
            } error:nil];
                      
            // Add the operations
            AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
            [self.netMan.operationQueue addOperation:operation];
            
            NSLog(@"Uploading");
        }
        
    }
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
}

@end
