//
//  CSMImageUtils.m
//  Chess Stream
//
//  Created by Daylen Yang on 4/5/14.
//  Copyright (c) 2014 Daylen Yang. All rights reserved.
//

#import "CSMImageUtils.h"
#import <GPUImage/GPUImage.h>

@implementation CSMImageUtils



+ (UIImage *)sobelImage:(UIImage *)image
{
    return [[[GPUImageSobelEdgeDetectionFilter alloc] init] imageByFilteringImage:image];
}


@end
