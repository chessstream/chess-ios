//
//  CSMViewController.m
//  Chess Stream
//
//  Created by Daylen Yang on 4/5/14.
//  Copyright (c) 2014 Daylen Yang. All rights reserved.
//

#import "CSMViewController.h"

@interface CSMViewController ()

@property NSInteger gameID;

@end

@implementation CSMViewController

#define GET_ID_URL @"http://107.170.1.232/id"

- (IBAction)didPressStartCapture:(id)sender {
    NSLog(@"Asking server for an ID");
    NSString *str = [NSString stringWithContentsOfURL:[NSURL URLWithString:GET_ID_URL] usedEncoding:nil error:NULL];
    self.gameID = [str integerValue];
    NSLog(@"id=%@", str);
}

@end
