//
//  TestModels.m
//  AutoNSCodingDemo
//
//  Created by Tom Adriaenssen on 27/05/15.
//  Copyright (c) 2015 Tom Adriaenssen. All rights reserved.
//

#import "TestModels.h"
#import "NSObject+PropertyDescription.h"
#import "IIAutoNSCopying.h"

@implementation TestModel {
    NSTimeInterval _interval;
}

II_AUTO_NSCOPYING()

- (NSString *)suchReadOnly
{
    return @"readonly";
}

- (void)setADate:(NSDate *)aDate
{
    _interval = [aDate timeIntervalSinceReferenceDate];
}

- (NSDate *)aDate
{
    return _interval == 0 ? nil : [NSDate dateWithTimeIntervalSinceReferenceDate:_interval];
}

- (NSString *)description
{
    return [self propertyDescription];
}

- (void)dealloc
{
    
}

@end

@implementation SubModel

@synthesize aNumber = _aNumber;

II_AUTO_NSCOPYING()

- (NSString *)description
{
    return [self propertyDescription];
}

@end

@implementation AnotherModel

II_AUTO_NSCOPYING()

- (NSString *)description
{
    return [self propertyDescription];
}

@end

@implementation ThirdModel

II_AUTO_NSCOPYING()

- (NSString *)description
{
    return [self propertyDescription];
}

@end
