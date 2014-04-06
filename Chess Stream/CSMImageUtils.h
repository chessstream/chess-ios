//
//  CSMImageUtils.h
//  Chess Stream
//
//  Created by Daylen Yang on 4/5/14.
//  Copyright (c) 2014 Daylen Yang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CSMImageUtils : NSObject



/*
 Returns a cropped sobel image.
 */
+ (UIImage *)sobelImage:(UIImage *)image;

@end
