/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>

@class UAHTTPRequestEngine;
@class UAChannelRegistrationPayload;
@class UAHTTPRequest;

typedef void (^UAChannelAPIClientCreateSuccessBlock)(NSString *channelID);

typedef void (^UAChannelAPIClientUpdateSuccessBlock)();

typedef void (^UAChannelAPIClientFailureBlock)(UAHTTPRequest *request);

/**
 * A high level abstraction for performing Channel API creation and updates.
 */
@interface UAChannelAPIClient : NSObject

/**
 * Factory method to create a UAChannelAPIClient.
 * @param requestEngine The specified UAHTTPRequestEngine.
 * @return UAChannelAPIClient with the specified requestEngine.
 */
+ (UAChannelAPIClient *)clientWithRequestEngine:(UAHTTPRequestEngine *)requestEngine;

/**
 * Factory method to create a UAChannelAPIClient.
 * @return UAChannelAPIClient with a default requestEngine.
 */
+ (UAChannelAPIClient *)client;

/**
 * Create the channel ID.
 *
 * @param payload An instance of UAChannelRegistrationPayload.
 * @param successBlock A UAChannelAPIClientCreateSuccessBlock that will be called
 *        if the channel ID was created successfully.
 * @param failureBlock A UAChannelAPIClientFailureBlock that will be called if
 *        the channel ID creation was unsuccessful.
 *
 */
- (void)createChannelWithPayload:(UAChannelRegistrationPayload *)payload
                      onSuccess:(UAChannelAPIClientCreateSuccessBlock)successBlock
                      onFailure:(UAChannelAPIClientFailureBlock)failureBlock;

/**
 * Update the channel.
 *
 * @param channelID The channel to be updated.
 * @param payload An instance of UAChannelRegistrationPayload.
 * @param successBlock A UAChannelAPIClientUpdateSuccessBlock that will be called
 *        if the channel was updated successfully.
 * @param failureBlock A UAChannelAPIClientFailureBlock that will be called if
 *        the channel update was unsuccessful.
 *
 */
- (void)updateChannel:(NSString *)channelID
          withPayload:(UAChannelRegistrationPayload *)payload
            onSuccess:(UAChannelAPIClientUpdateSuccessBlock)successBlock
            onFailure:(UAChannelAPIClientFailureBlock)failureBlock;

/**
 * Cancel all current and pending requests.
 */
- (void)cancelAllRequests;


@end
