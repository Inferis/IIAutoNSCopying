//
//  IIAutoNSCopying.h
//  AutoNSCopyingDemo
//
//  Created by Tom Adriaenssen on 29/05/15.
//  Copyright (c) 2015 Tom Adriaenssen. All rights reserved.
//

#import <Foundation/Foundation.h>

#define II_AUTO_NSCOPYING(opts) \
+ (void)load { \
[IIAutoNSCopying inject:self options:@#opts]; \
}

@interface IIAutoNSCopying : NSObject

+ (void)inject:(Class)class;
+ (void)inject:(Class)class options:(id)options;

@end
