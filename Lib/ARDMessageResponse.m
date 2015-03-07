/*
 * libjingle
 * Copyright 2014, Google Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ARDMessageResponse.h"

#import "ARDUtilities.h"

static NSString const *kARDMessageResultKey = @"result";

@interface ARDMessageResponse ()

@property(nonatomic, assign) ARDMessageResultType result;

@end

@implementation ARDMessageResponse

@synthesize result = _result;

+ (ARDMessageResponse *)responseFromJSONData:(NSData *)data {
  NSDictionary *responseJSON = [NSDictionary dictionaryWithJSONData:data];
  if (!responseJSON) {
    return nil;
  }
  ARDMessageResponse *response = [[ARDMessageResponse alloc] init];
  response.result =
      [[self class] resultTypeFromString:responseJSON[kARDMessageResultKey]];
  return response;
}

#pragma mark - Private

+ (ARDMessageResultType)resultTypeFromString:(NSString *)resultString {
  ARDMessageResultType result = kARDMessageResultTypeUnknown;
  if ([resultString isEqualToString:@"SUCCESS"]) {
    result = kARDMessageResultTypeSuccess;
  } else if ([resultString isEqualToString:@"INVALID_CLIENT"]) {
    result = kARDMessageResultTypeInvalidClient;
  } else if ([resultString isEqualToString:@"INVALID_ROOM"]) {
    result = kARDMessageResultTypeInvalidRoom;
  }
  return result;
}

@end
