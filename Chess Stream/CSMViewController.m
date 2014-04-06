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
#import <AFNetworking/AFNetworking.h>

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

- (IBAction)pressedButton:(UIBarButtonItem *)sender {
    if ([sender.title isEqualToString:@"Start"]) {
        BOOL success = [self askServerForNewID];
        if (success) {
            sender.title = @"Stop";
            NSLog(@"created game. ID=%i", self.gameID);
            self.shouldUpload = YES;
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Uh-oh" message:@"Could not contact the chess server." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
    } else {
        sender.title = @"Start";
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
    self.counter = 30;
    self.shouldUpload = NO;
    
    // Set up the session
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPreset1920x1080;
    
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
        NSLog(@"%@", granted ? @"granted" : @"nope");
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

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (self.shouldUpload) {
        if (self.counter++ >= 30) {
            self.counter = 0;
            UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
            NSError *error = nil;
            NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST" URLString:[NSString stringWithFormat:@"%@%@", BASE_URL, UPLOAD_ENDPOINT] parameters:@{@"id" : [NSString stringWithFormat:@"%i", self.gameID]} constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                [formData appendPartWithFileData:UIImageJPEGRepresentation(image, 1.0) name:@"img" fileName:@"image.jpg" mimeType:@"image/jpeg"];
            } error:&error];
            NSLog([[request allHTTPHeaderFields] description]);
            
            AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
            [self.netMan.operationQueue addOperation:operation];
            NSLog(@"Uploading");
        }
        
        /*
        if (self.counter++ <= 50) {
            self.counter = 1000;
            UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
            NSLog([image description]);
            NSLog(@"UPLOADING");
            // Create an operation
            NSError *error = nil;
            NSURLRequest *req = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST" URLString:[NSString stringWithFormat:@"%@%@", BASE_URL, UPLOAD_ENDPOINT] parameters:@{@"id": [NSString stringWithFormat:@"%i", self.gameID]} constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                NSData *imgDat = UIImageJPEGRepresentation(image, 1);
                assert(imgDat);
                [formData appendPartWithFileData:imgDat name:@"img" fileName:@"blahblahtroll.jpg" mimeType:@"image/jpeg"];
            } error:&error];
            if (!req) {
                NSLog([error description]);
            }
            NSLog(@"%@", [req allHTTPHeaderFields]);
            NSData *bodyD = [req HTTPBody];
//            [bodyD length];
            NSString *body = [[NSString alloc] initWithData:[req HTTPBody] encoding:NSUTF16StringEncoding];
            NSLog(@"bytes=%i", [bodyD length]);
            
            AFHTTPRequestOperation *op = [[AFHTTPRequestOperation alloc] initWithRequest:req];
            [self.netMan.operationQueue addOperation:op];
            
        }*/
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
