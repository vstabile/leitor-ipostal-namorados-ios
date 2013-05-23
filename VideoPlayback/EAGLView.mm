/*==============================================================================
            Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
            All Rights Reserved.
            Qualcomm Confidential and Proprietary

This Vuforia(TM) sample application in source code form ("Sample Code") for the
Vuforia Software Development Kit and/or Vuforia Extension for Unity
(collectively, the "Vuforia SDK") may in all cases only be used in conjunction
with use of the Vuforia SDK, and is subject in all respects to all of the terms
and conditions of the Vuforia SDK License Agreement, which may be found at
https://developer.vuforia.com/legal/license.

By retaining or using the Sample Code in any manner, you confirm your agreement
to all the terms and conditions of the Vuforia SDK License Agreement.  If you do
not agree to all the terms and conditions of the Vuforia SDK License Agreement,
then you may not retain or use any of the Sample Code in any manner.
==============================================================================*/

// Subclassed from AR_EAGLView
#import "EAGLView.h"
#import "Texture.h"
#import "Quad.h"
#import "SampleMath.h"

#import <QCAR/Renderer.h>
#import <QCAR/ImageTarget.h>
#import <QCAR/Vectors.h>
#import <QCAR/VideoBackgroundConfig.h>

#import "QCARutils.h"
#import "ShaderUtils.h"

namespace {
    // Texture filenames (an Object3D object is created for each texture)
    const char* textureFilenames[] = {
        "icon_play.png",
        "icon_loading.png",
        "icon_error.png",
        "StopMotion.jpg",
        "Over_Rainbow.jpg",
        "Better_Together.jpg",
        "all_you_need.jpg"
    };
    
    enum tagObjectIndex {
        OBJECT_PLAY_ICON,
        OBJECT_BUSY_ICON,
        OBJECT_ERROR_ICON,
        OBJECT_KEYFRAME_1,
        OBJECT_KEYFRAME_2,
    };
    
    const NSTimeInterval DOUBLE_TAP_INTERVAL = 0.3f;
    const NSTimeInterval TRACKING_LOST_TIMEOUT = 2.0f;
    
    // Playback icon scale factors
    const float SCALE_ICON = 2.0f;
    const float SCALE_ICON_TRANSLATION = 1.98f;
    
    // Video quad texture coordinates
    const GLfloat videoQuadTextureCoords[] = {
        0.0, 1.0,
        1.0, 1.0,
        1.0, 0.0,
        0.0, 0.0,
    };
    
    struct tagVideoData {
        // Needed to calculate whether a screen tap is inside the target
        QCAR::Matrix44F modelViewMatrix;
        
        // Trackable dimensions
        QCAR::Vec2F targetPositiveDimensions;
        
        // Currently active flag
        BOOL isActive;
    } videoData[NUM_VIDEO_TARGETS];
    
    int touchedTarget = 0;
}


@interface EAGLView (PrivateMethods)
- (void)tapTimerFired:(NSTimer*)timer;
- (void)createTrackingLostTimer;
- (void)terminateTrackingLostTimer;
- (void)trackingLostTimerFired:(NSTimer*)timer;
@end


@implementation EAGLView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
	if (self)
    {
        // create list of textures we want loading - ARViewController will do this for us
        int nTextures = sizeof(textureFilenames) / sizeof(textureFilenames[0]);
        for (int i = 0; i < nTextures; ++i) {
            [textureList addObject: [NSString stringWithUTF8String:textureFilenames[i]]];
        }
        
        // Ensure touch events go to the view controller, rather than directly
        // to this view
        self.userInteractionEnabled = NO;
        
        // For each target, create a VideoPlayerHelper object and zero the
        // target dimensions
        for (int i = 0; i < NUM_VIDEO_TARGETS; ++i) {
            videoPlayerHelper[i] = [[VideoPlayerHelper alloc] init];
            
            videoData[i].targetPositiveDimensions.data[0] = 0.0f;
            videoData[i].targetPositiveDimensions.data[1] = 0.0f;
        }
        
        dataLock = [[NSLock alloc] init];
    }
    
    return self;
}


- (void)dealloc
{
    for (int i = 0; i < NUM_VIDEO_TARGETS; ++i) {
        [videoPlayerHelper[i] release];
    }
    
    [dataLock release];
    
    [super dealloc];
}


// The user touched the screen
- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
    UITouch* touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    
    // Store the current touch location
    touchLocation_X = point.x;
    touchLocation_Y = point.y;
    
    // Determine which target was touched (if no target was touch, touchedTarget
    // will be -1)
    touchedTarget = [self tapInsideTargetWithID];
    
    // Ignore touches when videoPlayerHelper is playing in fullscreen mode
    if (-1 != touchedTarget && PLAYING_FULLSCREEN != [videoPlayerHelper[touchedTarget] getStatus]) {
        if (NO == tapPending) {
            [NSTimer scheduledTimerWithTimeInterval:DOUBLE_TAP_INTERVAL target:self selector:@selector(tapTimerFired:) userInfo:nil repeats:NO];
        }
    }
}


- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{
    // Ignore touches when videoPlayerHelper is playing in fullscreen mode
    if (-1 != touchedTarget && PLAYING_FULLSCREEN != [videoPlayerHelper[touchedTarget] getStatus]) {
        // If the user double-tapped the screen
        if (YES == tapPending) {
            tapPending = NO;
            MEDIA_STATE mediaState = [videoPlayerHelper[touchedTarget] getStatus];
            
            if (ERROR != mediaState && NOT_READY != mediaState) {
                // Play the video
                NSLog(@"Playing video with native player");
                [videoPlayerHelper[touchedTarget] play:YES fromPosition:VIDEO_PLAYBACK_CURRENT_POSITION];
            }
            
            // If any on-texture video is playing, pause it
            for (int i = 0; i < NUM_VIDEO_TARGETS; ++i) {
                if (PLAYING == [videoPlayerHelper[i] getStatus]) {
                    [videoPlayerHelper[i] pause];
                }
            }
        }
        else {
            tapPending = YES;
        }
    }
}


// Fires if the user tapped the screen (no double tap)
- (void)tapTimerFired:(NSTimer*)timer
{
    if (YES == tapPending) {
        tapPending = NO;
        
        // Get the state of the video player for the target the user touched
        MEDIA_STATE mediaState = [videoPlayerHelper[touchedTarget] getStatus];
        
#ifdef EXAMPLE_CODE_REMOTE_FILE
        // With remote files, single tap starts playback using the native player
        if (ERROR != mediaState && NOT_READY != mediaState) {
            // Play the video
            NSLog(@"Playing video with native player");
            [videoPlayerHelper[touchedTarget] play:YES fromPosition:VIDEO_PLAYBACK_CURRENT_POSITION];
        }
#else
        // If any on-texture video is playing, pause it
        for (int i = 0; i < NUM_VIDEO_TARGETS; ++i) {
            if (PLAYING == [videoPlayerHelper[i] getStatus]) {
                [videoPlayerHelper[i] pause];
            }
        }
        
        // For the target the user touched
        if (ERROR != mediaState && NOT_READY != mediaState && PLAYING != mediaState) {
            // Play the video
            NSLog(@"Playing video with on-texture player");
            [videoPlayerHelper[touchedTarget] play:NO fromPosition:VIDEO_PLAYBACK_CURRENT_POSITION];
        }
#endif
    }
}


// Determine whether a screen tap is inside the target
- (int)tapInsideTargetWithID
{
    QCAR::Vec3F intersection, lineStart, lineEnd;
    QCAR::Matrix44F projectionMatrix = [QCARutils getInstance].projectionMatrix;
    QCAR::Matrix44F inverseProjMatrix = SampleMath::Matrix44FInverse(projectionMatrix);
    CGRect rect = [self bounds];
    int touchInTarget = -1;
    
    // ----- Synchronise data access -----
    [dataLock lock];
    
    // The target returns as pose the centre of the trackable.  Thus its
    // dimensions go from -width / 2 to width / 2 and from -height / 2 to
    // height / 2.  The following if statement simply checks that the tap is
    // within this range
    for (int i = 0; i < NUM_VIDEO_TARGETS; ++i) {
        SampleMath::projectScreenPointToPlane(inverseProjMatrix, videoData[i].modelViewMatrix, rect.size.width, rect.size.height, 
                                              QCAR::Vec2F(touchLocation_X, touchLocation_Y), QCAR::Vec3F(0, 0, 0), QCAR::Vec3F(0, 0, 1), intersection, lineStart, lineEnd);
        
        if ((intersection.data[0] >= -videoData[i].targetPositiveDimensions.data[0]) && (intersection.data[0] <= videoData[i].targetPositiveDimensions.data[0]) &&
            (intersection.data[1] >= -videoData[i].targetPositiveDimensions.data[1]) && (intersection.data[1] <= videoData[i].targetPositiveDimensions.data[1])) {
            // The tap is only valid if it is inside an active target
            if (YES == videoData[i].isActive) {
                touchInTarget = i;
                break;
            }
        }
    }
    
    [dataLock unlock];
    // ----- End synchronise data access -----
    
    return touchInTarget;
}


// Get a pointer to a VideoPlayerHelper object held by this EAGLView
- (VideoPlayerHelper*)getVideoPlayerHelper:(int)index
{
    return videoPlayerHelper[index];
}


////////////////////////////////////////////////////////////////////////////////
// Set up 3D objects (overriding AR_EAGLView method)
- (void)setup3dObjects
{
    // Build the array of objects we want to draw.  In this example, all we need
    // to store is the OpenGL texture ID for each object (we use the data in
    // Quad.h for object vertices, indices, etc.)
    for (int i=0; i < [textures count]; ++i) {
        Object3D* obj3D = [[Object3D alloc] init];
        obj3D.texture = [textures objectAtIndex:i];
        [objects3D addObject:obj3D];
        [obj3D release];
    }
}


////////////////////////////////////////////////////////////////////////////////
// Initialise OpenGL rendering (overriding AR_EAGLView method)
- (void)initRendering
{
    if (renderingInited) {
        return;
    }
    
    // The super class does most of the initialisation
    [super initRendering];
    
    // For each OpenGL texture object, set appropriate texture parameters
    for (Texture* texture in textures) {
        glBindTexture(GL_TEXTURE_2D, [texture textureID]);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
}


// called after QCAR is initialised but before the camera starts
- (void) postInitQCAR
{
    // Set the number of simultaneous trackables to two
    QCAR::setHint(QCAR::HINT_MAX_SIMULTANEOUS_IMAGE_TARGETS, NUM_VIDEO_TARGETS);
}

// modify renderFrameQCAR here if you want a different 3D rendering model
////////////////////////////////////////////////////////////////////////////////
// Draw the current frame using OpenGL
//
// This method is called by QCAR when it wishes to render the current frame to
// the screen.
//
// *** QCAR will call this method on a single background thread ***
- (void)renderFrameQCAR
{
    [self setFramebuffer];
    
    // Clear colour and depth buffers
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Render video background and retrieve tracking state
    QCAR::State state = QCAR::Renderer::getInstance().begin();
    QCAR::Renderer::getInstance().drawVideoBackground();
    
    glEnable(GL_DEPTH_TEST);
    // We must detect if background reflection is active and adjust the culling direction. 
    // If the reflection is active, this means the pose matrix has been reflected as well,
    // therefore standard counter clockwise face culling will result in "inside out" models. 
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    if(QCAR::Renderer::getInstance().getVideoBackgroundConfig().mReflection == QCAR::VIDEO_BACKGROUND_REFLECTION_ON)
        glFrontFace(GL_CW);  //Front camera
    else
        glFrontFace(GL_CCW);   //Back camera
    
    // Get the active trackables
    int numActiveTrackables = state.getNumTrackableResults();
    
    // ----- Synchronise data access -----
    [dataLock lock];
    
    // Assume all targets are inactive (used when determining tap locations)
    for (int i = 0; i < NUM_VIDEO_TARGETS; ++i) {
        videoData[i].isActive = NO;
    }
    
    // Did we find any trackables this frame?
    for (int i = 0; i < numActiveTrackables; ++i) {
        // Get the trackable
        const QCAR::TrackableResult* trackableResult = state.getTrackableResult(i);
        const QCAR::ImageTarget& imageTarget = (const QCAR::ImageTarget&) trackableResult->getTrackable();

        // VideoPlayerHelper to use for current target
        int playerIndex = 0;    // stones
        if (strcmp(imageTarget.getName(), "all_you_need") == 0){ playerIndex = 3; }
        else if (strcmp(imageTarget.getName(), "over_the_rainbow") == 0) { playerIndex = 1; }
        else if (strcmp(imageTarget.getName(), "better_together") == 0) { playerIndex = 2; }
        else if (strcmp(imageTarget.getName(), "stopmotion") == 0) { playerIndex = 0; }
        
        // Mark this video (target) as active
        videoData[playerIndex].isActive = YES;
        
        // Get the target size (used to determine if taps are within the target)
        if (0.0f == videoData[playerIndex].targetPositiveDimensions.data[0] ||
            0.0f == videoData[playerIndex].targetPositiveDimensions.data[1]) {
            const QCAR::ImageTarget& imageTarget = (const QCAR::ImageTarget&) trackableResult->getTrackable();
            
            videoData[playerIndex].targetPositiveDimensions = imageTarget.getSize();
            // The pose delivers the centre of the target, thus the dimensions
            // go from -width / 2 to width / 2, and -height / 2 to height / 2
            videoData[playerIndex].targetPositiveDimensions.data[0] /= 2.0f;
            videoData[playerIndex].targetPositiveDimensions.data[1] /= 2.0f;
        }
        
        // Get the current trackable pose
        const QCAR::Matrix34F& trackablePose = trackableResult->getPose();
        
        // This matrix is used to calculate the location of the screen tap
        videoData[playerIndex].modelViewMatrix = QCAR::Tool::convertPose2GLMatrix(trackablePose);
        
        float aspectRatio;
        const GLvoid* texCoords;
        GLuint frameTextureID;
        BOOL displayVideoFrame = YES;
        
        // Retain value between calls
        static GLuint videoTextureID[NUM_VIDEO_TARGETS] = {0};
        
        MEDIA_STATE currentStatus = [videoPlayerHelper[playerIndex] getStatus];
        
        // --- INFORMATION ---
        // One could trigger automatic playback of a video at this point.  This
        // could be achieved by calling the play method of the VideoPlayerHelper
        // object if currentStatus is not PLAYING.  You should also call
        // getStatus again after making the call to play, in order to update the
        // value held in currentStatus.
        // --- END INFORMATION ---
        
        switch (currentStatus) {
            case PLAYING: {
                // If the tracking lost timer is scheduled, terminate it
                if (nil != trackingLostTimer) {
                    // Timer termination must occur on the same thread on which
                    // it was installed
                    [self performSelectorOnMainThread:@selector(terminateTrackingLostTimer) withObject:nil waitUntilDone:YES];
                }
                
                // Upload the decoded video data for the latest frame to OpenGL
                // and obtain the video texture ID
                GLuint videoTexID = [videoPlayerHelper[playerIndex] updateVideoData];
                
                if (0 == videoTextureID[playerIndex]) {
                    videoTextureID[playerIndex] = videoTexID;
                }
                
                // Fallthrough
            }
            case PAUSED:
                if (0 == videoTextureID[playerIndex]) {
                    // No video texture available, display keyframe
                    displayVideoFrame = NO;
                }
                else {
                    // Display the texture most recently returned from the call
                    // to [videoPlayerHelper updateVideoData]
                    frameTextureID = videoTextureID[playerIndex];
                }
                
                break;
                
            default:
                videoTextureID[playerIndex] = 0;
                displayVideoFrame = NO;
                break;
        }
        
        if (YES == displayVideoFrame) {
            // ---- Display the video frame -----
            aspectRatio = (float)[videoPlayerHelper[playerIndex] getVideoHeight] / (float)[videoPlayerHelper[playerIndex] getVideoWidth];
            texCoords = videoQuadTextureCoords;
        }
        else {
            // ----- Display the keyframe -----
            Object3D* obj3D = [objects3D objectAtIndex:OBJECT_KEYFRAME_1 + playerIndex];
            frameTextureID = [[obj3D texture] textureID];
            aspectRatio = (float)[[obj3D texture] height] / (float)[[obj3D texture] width];
            texCoords = quadTexCoords;
        }
        
        // If the current status is valid (not NOT_READY or ERROR), render the
        // video quad with the texture we've just selected
        if (NOT_READY != currentStatus) {
            // Convert trackable pose to matrix for use with OpenGL
            QCAR::Matrix44F modelViewMatrixVideo = QCAR::Tool::convertPose2GLMatrix(trackablePose);
            QCAR::Matrix44F modelViewProjectionVideo;
            
            ShaderUtils::translatePoseMatrix(0.0f, 0.0f, videoData[playerIndex].targetPositiveDimensions.data[0],
                                             &modelViewMatrixVideo.data[0]);
            
            ShaderUtils::scalePoseMatrix(videoData[playerIndex].targetPositiveDimensions.data[0], 
                                         videoData[playerIndex].targetPositiveDimensions.data[0] * aspectRatio, 
                                         videoData[playerIndex].targetPositiveDimensions.data[0],
                                         &modelViewMatrixVideo.data[0]);
            
            ShaderUtils::multiplyMatrix(&qUtils.projectionMatrix.data[0],
                                        &modelViewMatrixVideo.data[0] ,
                                        &modelViewProjectionVideo.data[0]);
            
            glUseProgram(shaderProgramID);
            
            glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0, quadVertices);
            glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0, quadNormals);
            glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0, texCoords);
            
            glEnableVertexAttribArray(vertexHandle);
            glEnableVertexAttribArray(normalHandle);
            glEnableVertexAttribArray(textureCoordHandle);
            
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, frameTextureID);
            glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE, (GLfloat*)&modelViewProjectionVideo.data[0]);
            glUniform1i(texSampler2DHandle, 0 /*GL_TEXTURE0*/);
            glDrawElements(GL_TRIANGLES, NUM_QUAD_INDEX, GL_UNSIGNED_SHORT, quadIndices);
            
            glDisableVertexAttribArray(vertexHandle);
            glDisableVertexAttribArray(normalHandle);
            glDisableVertexAttribArray(textureCoordHandle);
            
            glUseProgram(0);
        }
        
        // If the current status is not PLAYING, render an icon
        if (PLAYING != currentStatus) {
            GLuint iconTextureID;
            
            switch (currentStatus) {
                case READY:
                case REACHED_END:
                case PAUSED:
                case STOPPED: {
                    // ----- Display play icon -----
                    Object3D* obj3D = [objects3D objectAtIndex:OBJECT_PLAY_ICON];
                    iconTextureID = [[obj3D texture] textureID];
                    break;
                }
                    
                case ERROR: {
                    // ----- Display error icon -----
                    Object3D* obj3D = [objects3D objectAtIndex:OBJECT_ERROR_ICON];
                    iconTextureID = [[obj3D texture] textureID];
                    break;
                }
                    
                default: {
                    // ----- Display busy icon -----
                    Object3D* obj3D = [objects3D objectAtIndex:OBJECT_BUSY_ICON];
                    iconTextureID = [[obj3D texture] textureID];
                    break;
                }
            }
            
            // Convert trackable pose to matrix for use with OpenGL
            QCAR::Matrix44F modelViewMatrixButton = QCAR::Tool::convertPose2GLMatrix(trackablePose);
            QCAR::Matrix44F modelViewProjectionButton;
            
            ShaderUtils::translatePoseMatrix(0.0f, 0.0f, videoData[playerIndex].targetPositiveDimensions.data[1] / SCALE_ICON_TRANSLATION, &modelViewMatrixButton.data[0]);
            
            ShaderUtils::scalePoseMatrix(videoData[playerIndex].targetPositiveDimensions.data[1] / SCALE_ICON,
                                         videoData[playerIndex].targetPositiveDimensions.data[1] / SCALE_ICON,
                                         videoData[playerIndex].targetPositiveDimensions.data[1] / SCALE_ICON,
                                         &modelViewMatrixButton.data[0]);
            
            ShaderUtils::multiplyMatrix(&qUtils.projectionMatrix.data[0],
                                        &modelViewMatrixButton.data[0] ,
                                        &modelViewProjectionButton.data[0]);
            
            glDepthFunc(GL_LEQUAL);
            
            glUseProgram(shaderProgramID);
            
            glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0, quadVertices);
            glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0, quadNormals);
            glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0, quadTexCoords);
            
            glEnableVertexAttribArray(vertexHandle);
            glEnableVertexAttribArray(normalHandle);
            glEnableVertexAttribArray(textureCoordHandle);
            
            // Blend the icon over the background
            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, iconTextureID);
            glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE, (GLfloat*)&modelViewProjectionButton.data[0] );
            glDrawElements(GL_TRIANGLES, NUM_QUAD_INDEX, GL_UNSIGNED_SHORT, quadIndices);
            
            glDisable(GL_BLEND);
            
            glDisableVertexAttribArray(vertexHandle);
            glDisableVertexAttribArray(normalHandle);
            glDisableVertexAttribArray(textureCoordHandle);
            
            glUseProgram(0);
            
            glDepthFunc(GL_LESS);
        }
        
        ShaderUtils::checkGlError("VideoPlayback renderFrameQCAR");
    }
    
    // --- INFORMATION ---
    // One could pause automatic playback of a video at this point.  Simply call
    // the pause method of the VideoPlayerHelper object without setting the
    // timer (as below).
    // --- END INFORMATION ---
    
    // If a video is playing on texture and we have lost tracking, create a
    // timer on the main thread that will pause video playback after
    // TRACKING_LOST_TIMEOUT seconds
    for (int i = 0; i < NUM_VIDEO_TARGETS; ++i) {
        if (nil == trackingLostTimer && NO == videoData[i].isActive && PLAYING == [videoPlayerHelper[i] getStatus]) {
            [self performSelectorOnMainThread:@selector(createTrackingLostTimer) withObject:nil waitUntilDone:YES];
            break;
        }
    }
    
    [dataLock unlock];
    // ----- End synchronise data access -----
    
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    
    QCAR::Renderer::getInstance().end();
    [self presentFramebuffer];
}


// Create the tracking lost timer
- (void)createTrackingLostTimer
{
    trackingLostTimer = [NSTimer scheduledTimerWithTimeInterval:TRACKING_LOST_TIMEOUT target:self selector:@selector(trackingLostTimerFired:) userInfo:nil repeats:NO];
}


// Terminate the tracking lost timer
- (void)terminateTrackingLostTimer
{
    [trackingLostTimer invalidate];
    trackingLostTimer = nil;
}


// Tracking lost timer fired, pause video playback
- (void)trackingLostTimerFired:(NSTimer*)timer
{
    // Tracking has been lost for TRACKING_LOST_TIMEOUT seconds, pause playback
    // (we can safely do this on all our VideoPlayerHelpers objects)
    for (int i = 0; i < NUM_VIDEO_TARGETS; ++i) {
        [videoPlayerHelper[i] pause];
    }
    trackingLostTimer = nil;
}

@end
