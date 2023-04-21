//
//  CustomCameraHelper.m
//  TRTC-API-Example-OC
//
//  Created by abyyxwang on 2021/4/22.
//  Copyright © 2021 Tencent. All rights reserved.
//

#import "CustomCameraHelper.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import <GPUImage/GPUImage.h>

@interface CustomCameraSampler : GPUImageRawDataOutput

@property (nonatomic, strong) void(^processing)(CVPixelBufferRef pixelBuffer, CMTime frameTime);

@end

@implementation CustomCameraSampler

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex {
    [super newFrameReadyAtTime:frameTime atIndex:textureIndex];
    
    if (self.processing) {
        [self lockFramebufferForReading];
        
        CVPixelBufferRef pb;
        CVReturn result = CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                     imageSize.width,
                                     imageSize.height,
                                     kCVPixelFormatType_32BGRA,
                                     [self rawBytesForImage],
                                     [self bytesPerRowInOutput],
                                     nil, nil, nil,
                                     &pb);
        [self unlockFramebufferAfterReading];
        if (kCVReturnSuccess != result) {
            NSLog(@"采集错误");
        }
        self.processing(pb, frameTime);
        CVPixelBufferRelease(pb);
    }
}

@end

typedef NS_ENUM(NSInteger, AVCamSetupResult) {
    AVCamSetupResultSuccess,
    AVCamSetupResultCameraNotAuthorized,
    AVCamSetupResultSessionConfigurationFailed
};

@interface CustomCameraHelper ()

@property (nonatomic, strong) GPUImageVideoCamera *camera;
@property (nonatomic, strong) CustomCameraSampler *sampler;

@property (nonatomic, strong) dispatch_queue_t cameraDelegateQueue;

@end

@implementation CustomCameraHelper

- (instancetype)init
{
    self = [super init];
    if (self) {
        // Communicate with the session and other session objects on this queue.
        self.cameraDelegateQueue = dispatch_queue_create("com.txc.CameraDelegateQueue", DISPATCH_QUEUE_SERIAL);
        self.camera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront];
        self.camera.outputImageOrientation = UIInterfaceOrientationPortrait;
        self.sampler = [[CustomCameraSampler alloc] initWithImageSize:CGSizeMake(720, 1280) resultsInBGRAFormat:YES];
        [self.camera addTarget:self.sampler];
        __weak typeof(self) weakself = self;
        self.sampler.processing = ^(CVPixelBufferRef pixelBuffer, CMTime frameTime) {
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            CMSampleBufferRef sb;
            CMVideoFormatDescriptionRef fd;
            CMVideoFormatDescriptionCreateForImageBuffer(nil, pixelBuffer, &fd);
            CMSampleTimingInfo timingInfo = { CMTimeMake(1, weakself.camera.frameRate), frameTime, kCMTimeInvalid };
            CMSampleBufferCreateReadyWithImageBuffer(nil, pixelBuffer, fd, &timingInfo, &sb);
            [weakself.delegate onVideoSampleBuffer:sb];
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            CFRelease(sb);
            CFRelease(fd);
        };
    }
    return self;
}

- (void)checkPermission {
    /*
     Check video authorization status. Video access is required and audio
     access is optional. If audio access is denied, audio is not recorded
     during movie recording.
    */
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo])
    {
        case AVAuthorizationStatusAuthorized:
        {
            // The user has previously granted access to the camera.
            break;
        }
        case AVAuthorizationStatusNotDetermined:
        {
            /*
             The user has not yet been presented with the option to grant
             video access. We suspend the session queue to delay session
             setup until the access request has completed.
             
             Note that audio access will be implicitly requested when we
             create an AVCaptureDeviceInput for audio during session setup.
            */
            break;
        }
        default:
        {
            // The user has previously denied access.
            break;
        }
    }
}

- (void)createSession {
    [self startCameraCapture];
}

- (void)startCameraCapture {
    if (!self.camera) {
        return;
    }
    [self.camera startCameraCapture];
}

- (void)stopCameraCapture {
    if (!self.camera) {
        return;
    }
    [self.camera stopCameraCapture];
}

@end
