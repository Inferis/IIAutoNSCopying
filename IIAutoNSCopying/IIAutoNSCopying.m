//
//  IIAutoNSCopying.m
//  AutoNSCopyingDemo
//
//  Created by Tom Adriaenssen on 29/05/15.
//  Copyright (c) 2015 Tom Adriaenssen. All rights reserved.
//

#import "IIAutoNSCopying.h"

#import <objc/message.h>
#import <objc/runtime.h>

void IIAutoNSCopyingAdoptCopying(Class class);
NSArray *IIAutoNSCopyingDiscoverMapping(Class class);
void IIAutoNSCopyingAddMethod(Class class, SEL selector, id block);
void IIAutoNSCopyingCopier(Class class, NSArray *mapping, id source, id target, NSZone *zone, NSString *options);

@implementation IIAutoNSCopying

+ (void)inject:(Class)class
{
    [self inject:class options:nil];
}

#define AntiARCRetain(...) { void *retainedThing = (__bridge_retained void *)__VA_ARGS__; retainedThing = retainedThing; }

+ (void)inject:(Class)class options:(id)options
{
    // don't inject if already nscoding
    if (!class || class_conformsToProtocol(class, @protocol(NSCopying))) {
        return;
    }
    
    // only do stuff in our app bundle
    NSString *name = [[NSString alloc] initWithUTF8String:class_getImageName(class)];
    if ([name rangeOfString:[[NSBundle mainBundle] bundlePath]].location == NSNotFound) {
        return;
    }
    
    Class superclass = class_getSuperclass(class);
    if (!class_conformsToProtocol(superclass, @protocol(NSCopying))) {
        [self inject:superclass options:options];
    }
    
    IIAutoNSCopyingAdoptCopying(class);
    NSArray *mapping = IIAutoNSCopyingDiscoverMapping(class);
    IIAutoNSCopyingAddMethod(class, @selector(copyWithZone:), ^(id self, NSZone* zone) {
        id copy = nil;
        
        if (class_conformsToProtocol(superclass, @protocol(NSCopying))) {
            struct objc_super mySuper = {
                .receiver = self,
                .super_class = superclass
            };
            
            id (*objc_superCopyWithZone)(struct objc_super *, SEL, NSZone *) = (void *)&objc_msgSendSuper;
            copy = (*objc_superCopyWithZone)(&mySuper, @selector(copyWithZone:), zone);
        }
        else {
            copy = [[[self class] allocWithZone:zone] init];
        }
        
        IIAutoNSCopyingCopier(class, mapping, self, copy, zone, options);
        AntiARCRetain(copy);
        return copy;
    });
}

@end


void IIAutoNSCopyingAdoptCopying(Class class) {
    // add the NSCopying protocol
    class_addProtocol(class, @protocol(NSCopying));
}

void IIAutoNSCopyingAddMethod(Class class, SEL selector, id block) {
    struct objc_method_description method = protocol_getMethodDescription(@protocol(NSCopying), selector, YES, YES);
    IMP impl = imp_implementationWithBlock(block);
    class_addMethod(class, selector, impl, method.types);
}

NSArray *IIAutoNSCopyingDiscoverMapping(Class class) {
    NSMutableArray *mapping = [NSMutableArray new];
    
    uint count = 0;
    objc_property_t *properties = class_copyPropertyList(class, &count);
    for (uint i=0; i<count; ++i) {
        objc_property_t property = properties[i];
        
        char *attrValue = NULL;
        attrValue = property_copyAttributeValue(property, "R");
        BOOL readonly = attrValue != NULL;
        free(attrValue);
        
        if (readonly) { continue; }
        
        attrValue = property_copyAttributeValue(property, "T");
        NSString *type = [NSString stringWithUTF8String:attrValue];
        free(attrValue);
        
        if (!type) { continue; }
        
        NSString *name = [NSString stringWithUTF8String:property_getName(property)];
        
        attrValue = property_copyAttributeValue(property, "G");
        NSString *getter = attrValue ? [NSString stringWithUTF8String:attrValue] : name;
        free(attrValue);
        
        attrValue = property_copyAttributeValue(property, "S");
        NSString *setter = attrValue ? [NSString stringWithUTF8String:attrValue] : [NSString stringWithFormat:@"set%@%@:", [[name substringToIndex:1] uppercaseString], [name substringFromIndex:1]];
        free(attrValue);
        
        if ([type characterAtIndex:0] == '@' && type.length >= 3) {
            NSString *className = [type substringWithRange:NSMakeRange(2, type.length-3)];
            Class class = NSClassFromString(className);
            if (class) {
                [mapping addObject:@{ @"n": name,
                                      @"c": class,
                                      @"g": [NSValue valueWithPointer:NSSelectorFromString(getter)],
                                      @"s": [NSValue valueWithPointer:NSSelectorFromString(setter)] }];
            }
            else if ([type rangeOfString:@"<"].location != NSNotFound) { // protocol
                [mapping addObject:@{ @"n": name,
                                      @"p": @YES, // we don't care which
                                      @"g": [NSValue valueWithPointer:NSSelectorFromString(getter)],
                                      @"s": [NSValue valueWithPointer:NSSelectorFromString(setter)] }];
            }
            else {
                @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                               reason:@"NOT SUPPORTED" userInfo:nil];
            }
        }
        else {
            [mapping addObject:@{ @"n": name,
                                  @"t": type,
                                  @"g": [NSValue valueWithPointer:NSSelectorFromString(getter)],
                                  @"s": [NSValue valueWithPointer:NSSelectorFromString(setter)] }];
        }
    }
    free(properties);
    
    return [mapping copy];
}

#define GET_VALUE(source, getterSelector, type) ({ \
type(*objc_msgSendGetter)(id, SEL) = (void *)objc_msgSend; \
objc_msgSendGetter(source, getterSelector); })

#define SET_VALUE(target, setterSelector, type, value) ({ \
void(*objc_msgSendSetter)(id, SEL, type) = (void *)objc_msgSend; \
objc_msgSendSetter(target, setterSelector, [value copy]); })

#define COPY_VALUE(source, getterSelector, target, setterSelector, type) ({ \
type(*objc_msgSendGetter)(id, SEL) = (void *)objc_msgSend; \
type value = objc_msgSendGetter(source, getterSelector); \
void(*objc_msgSendSetter)(id, SEL, type) = (void *)objc_msgSend; \
objc_msgSendSetter(target, setterSelector, value); })

#define COPY_OBJECT(source, getterSelector, target, setterSelector, type) ({ \
type(*objc_msgSendGetter)(id, SEL) = (void *)objc_msgSend; \
type value = objc_msgSendGetter(source, getterSelector); \
void(*objc_msgSendSetter)(id, SEL, type) = (void *)objc_msgSend; \
objc_msgSendSetter(target, setterSelector, [value copy]); })

void IIAutoNSCopyingCopier(Class sourceClass, NSArray *mapping, id source, id target, NSZone *zone, NSString *options) {
    for (NSDictionary *map in mapping) {
        Class class = map[@"c"];
        BOOL isProtocol = [map[@"p"] boolValue];
        SEL getter = [map[@"g"] pointerValue];
        SEL setter = [map[@"s"] pointerValue];

        if (class) {
            if ([class isSubclassOfClass:[NSArray class]]) {
                NSArray *original = GET_VALUE(source, getter, id);
                NSMutableArray *copy = [original mutableCopy];
                for (NSUInteger i=0; i<original.count; ++i) {
                    copy[i] = [copy[i] copy];
                }
                SET_VALUE(target, setter, id, copy);
            }
            else if ([class isSubclassOfClass:[NSDictionary class]]) {
                NSDictionary *original = GET_VALUE(source, getter, id);
                NSMutableDictionary *copy = [original mutableCopy];
                for (id key in original) {
                    copy[key] = [copy[key] copy]; // key is automatically copied
                }
                SET_VALUE(target, setter, id, copy);
            }
            else if ([class isSubclassOfClass:[NSSet class]]) {
                NSSet *original = GET_VALUE(source, getter, id);
                NSMutableSet *copy = [NSMutableSet mutableCopy];
                [copy removeAllObjects];
                for (id object in original) {
                    [copy addObject:[object copy]];
                }
                SET_VALUE(target, setter, id, copy);
            }
            else {
                COPY_OBJECT(source, getter, target, setter, id);
            }
        }
        else if (isProtocol) {
            COPY_OBJECT(source, getter, target, setter, id);
        }
        else {
            char type = [map[@"t"] characterAtIndex:0];
            switch (type) {
                case ':': { // selector
                    COPY_VALUE(source, getter, target, setter, SEL);
                    break;
                }
                    
                case '#': { // class
                    COPY_VALUE(source, getter, target, setter, Class);
                    break;
                }
                    
                case 'i': { // int
                    COPY_VALUE(source, getter, target, setter, int);
                    break;
                }
                    
                case 's': { // short
                    COPY_VALUE(source, getter, target, setter, short);
                    break;
                }
                    
                case 'l': { // long
                    COPY_VALUE(source, getter, target, setter, long);
                    break;
                }
                    
                case 'q': { // long long
                    COPY_VALUE(source, getter, target, setter, long long);
                    break;
                }
                    
                case 'I': { // unsigned int
                    COPY_VALUE(source, getter, target, setter, unsigned int);
                    break;
                }
                    
                case 'S': { // unsigned short
                    COPY_VALUE(source, getter, target, setter, unsigned short);
                    break;
                }
                    
                case 'L': { // unsigned long
                    COPY_VALUE(source, getter, target, setter, unsigned long);
                    break;
                }
                    
                case 'Q': { // unsigned long long
                    COPY_VALUE(source, getter, target, setter, unsigned long long);
                    break;
                }
                    
                case 'f': { // float
                    COPY_VALUE(source, getter, target, setter, float);
                    break;
                }
                    
                case 'd': { // double
                    COPY_VALUE(source, getter, target, setter, double);
                    break;
                }
                    
                case 'B': { // BOOL
                    COPY_VALUE(source, getter, target, setter, BOOL);
                    break;
                }
                    
                case 'c': { // char
                    COPY_VALUE(source, getter, target, setter, char);
                    break;
                }
                    
                case 'C': { // unsigned char
                    COPY_VALUE(source, getter, target, setter, unsigned char);
                    break;
                }
                    
                case '{': { // struct
                    // ¯\_(ツ)_/¯ 
                    break;
                }
                    
                case '^': { // pointer
                    COPY_VALUE(source, getter, target, setter, void*);
                    break;
                }
                    
                case '@': { // block
                    COPY_OBJECT(source, getter, target, setter, id);
                    break;
                }
                    
                default:
                    break;
            }
        }
    }
}
