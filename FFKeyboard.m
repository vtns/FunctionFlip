//
//  FFKeyboard.m
//  FunctionFlip
//
//  Created by Kevin Gessner on 10/25/08.
//  Copyright (c) 2008-2010, Kevin Gessner, http://kevingessner.com
//  
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//  
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "FFKeyboard.h"
#import "FFPreferenceManager.h"
#import "FFKey.h"
#import "FFKeyLibrary.h"
#import "DDHidLib.h"

@implementation FFKeyboard

static NSMutableDictionary *keyboards;

// just create one keyboard per device, returning it if it already exists
+ (FFKeyboard *)keyboardWithDevice:(DDHidKeyboard *)aDevice {
	if(!keyboards) keyboards = [[NSMutableDictionary alloc] init];
	if(![keyboards objectForKey:[aDevice productName]]) { // use product name since DDHidKeyboard's aren't copyable
		FFKeyboard *keyboard = [[FFKeyboard alloc] initWithDevice:aDevice];
//		NSLog(@"kbFF: %@", keyboard);
		[keyboards setObject:keyboard forKey:([aDevice productName] ? [aDevice productName] : [NSString stringWithFormat:@"%lx-%lx", [aDevice vendorId], [aDevice productId]])];
	}
	return [keyboards objectForKey:([aDevice productName] ? [aDevice productName] : [NSString stringWithFormat:@"%lx-%lx", [aDevice vendorId], [aDevice productId]])];
}

- (id)initWithDevice:(DDHidKeyboard *)aDevice {
	if(self = [super init]) {
		self.device = aDevice;
		
		// extract the FN key map
		// it's a comma-separated string of hex values: <first fkey code>,<first special code>,<second fkey code>,etc...
		CFStringRef fnusagemap = IORegistryEntrySearchCFProperty([self.device ioDevice], kIOServicePlane, (CFStringRef)@"FnFunctionUsageMap", kCFAllocatorDefault, kIORegistryIterateRecursively);
        if (!fnusagemap || CFStringGetLength(fnusagemap)==0) {
            if ([aDevice.productName hasPrefix:@"REALFORCE"]) {
                fnusagemap = CFSTR("0x0007003a,0xff010021,0x0007003b,0xff010020,"
                                   //"0x0007003c,0xff010010,0x0007003d,0xff010002,"
                                   "0x00070040,0x000C00B4,0x00070041,0x000C00CD,"
                                   "0x00070042,0x000C00B3,0x00070043,0x000C00E2,"
                                   "0x00070044,0x000C00EA,0x00070045,0x000C00E9");
            }
        }
		if(fnusagemap) { // if we've got a non-special keyboard, this won't be set
			NSArray *codes = [(__bridge NSString *)fnusagemap componentsSeparatedByString:@","];
			NSMutableArray *fkeyCodes = [NSMutableArray array];
			NSMutableArray *specialCodes = [NSMutableArray array];
			NSInteger index = 0;
			// even indices (0,2,...) go in fkeyCodes, odd indices in specialCodes
			for(NSString *code in codes) {
				if(index % 2 == 0)
					[fkeyCodes addObject:code];
				else
					[specialCodes addObject:code];
				index++;
			}
			fkeyMap = [NSDictionary dictionaryWithObjects:specialCodes forKeys:fkeyCodes];
		}
	}
	return self;
}

- (BOOL)hasSpecialFkeys {
	return ([fkeyMap count] > 0);
}

- (NSDictionary *)fkeyMap {
	return fkeyMap;
}

- (NSString *)specialIdForKeyId:(NSString *)keyId {
	return [fkeyMap objectForKey:keyId];
}

- (NSArray *)fkeys {
	if(![self hasSpecialFkeys]) return NSNotApplicableMarker;
	NSMutableArray *keys = [NSMutableArray array];
	for(NSString *keyId in [[fkeyMap allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
		if (![FFKeyLibrary descriptionForSpecialId:[self specialIdForKeyId:keyId]]) continue;
		[keys addObject:[FFKey keyWithKeyId:keyId ofKeyboard:self]];
	}
	return keys;
}
						 
- (BOOL)isKeyFlipped:(FFKey *)key {
    NSString *lookupKey = [NSString stringWithFormat:@"flipped.%@.%@", [self.device productName], [key keyId]];
	return [[[FFPreferenceManager sharedInstance] valueForKey:lookupKey] boolValue];
}
- (void)setKey:(FFKey *)key isFlipped:(BOOL)flag {
//	NSLog(@"sets flipped %@", key);
	[[FFPreferenceManager sharedInstance] setValue:[NSNumber numberWithBool:flag] forKey:[NSString stringWithFormat:@"flipped.%@.%@", [self.device productName], [key keyId]]];
}

- (NSString *)description {
	return [[self device] productName] ? [[self device] productName] : @"Unidentified keyboard";
}

@synthesize device;

@end
