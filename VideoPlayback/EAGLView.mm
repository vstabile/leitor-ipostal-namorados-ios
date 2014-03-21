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
#import "CERoundProgressLayer.h"
#import "CERoundProgressView.h"
#import <QCAR/Renderer.h>
#import <QCAR/ImageTarget.h>
#import <QCAR/Vectors.h>
#import <QCAR/VideoBackgroundConfig.h>

#import "QCARutils.h"
#import "ShaderUtils.h"

#warning CHANGE HERE 2
namespace {
    // Texture filenames (an Object3D object is created for each texture)
    const char* textureFilenames[] = {
        "icon_play.png",
        "icon_loading.png",
        "icon_error.png",

        "bebendo_leite_thumbnail.jpg",
        "comemorar_thumbnail.jpg",
        "loro.jpg",
        "bolo_rotatorio_thumbnail.jpg",
        "Over_Rainbow.jpg",
        "Better_Together.jpg",
        "StopMotion.jpg",
        "happy_fathers_day.jpg",
        "all_you_need.jpg",
        "dia_de_parabens_thumbnail.jpg",
        "super_hero.jpg",
        "rena_cantando.jpg",
        "pascoa.jpg",
        "dia_das_maes.jpg",
        "dia_dos_namorados.jpg"
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
    const float SCALE_ICON = 2.0f;  //2.0f
    const float SCALE_ICON_TRANSLATION = 1.4f;  //1.98f;
    
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
        isDownloadedArray = [[NSMutableArray alloc] initWithCapacity:NUM_VIDEO_TARGETS];
        isDownloadingArray = [[NSMutableArray alloc] initWithCapacity:NUM_VIDEO_TARGETS];
        for (int i = 0; i < NUM_VIDEO_TARGETS; i ++)
        {
            [isDownloadedArray addObject:@NO];
            [isDownloadingArray addObject:@NO];
        }
        // create list of textures we want loading - ARViewController will do this for us
        int nTextures = sizeof(textureFilenames) / sizeof(textureFilenames[0]);
        for (int i = 0; i < nTextures; ++i)
        {
            [textureList addObject: [NSString stringWithUTF8String:textureFilenames[i]]];
            NSLog(@"texture list filename:%@", [NSString stringWithUTF8String:textureFilenames[i]]);
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
        
        // If any on-texture video is playing, pause it
        for (int i = 0; i < NUM_VIDEO_TARGETS; ++i) {
            if (PLAYING == [videoPlayerHelper[i] getStatus]) {
                [videoPlayerHelper[i] pause];
            }
        }
        
        // For the target the user touched
        if (ERROR != mediaState /* && NOT_READY != mediaState */ && PLAYING != mediaState) {
            // Play the video
            NSLog(@"Playing video with on-texture player");
            if ([[isDownloadedArray objectAtIndex:touchedTarget] boolValue])
            {
                [videoPlayerHelper[touchedTarget] play:NO fromPosition:VIDEO_PLAYBACK_CURRENT_POSITION];
            }
            else
            {

#warning CHANGE HERE 3
                NSString * fileName;
                switch (touchedTarget) {
                    case 0:
                        fileName = @"bebendo_leite.mp4";
                        break;
                    case 1:
                        fileName = @"comemorar.mp4";
                        break;
                    case 2:
                        fileName = @"loro.mp4";
                        break;
                    case 3:
                        fileName = @"bolo_rotatorio.mp4";
                        break;
                    case 4:
                        fileName = @"over_the_rainbow.mp4";
                        break;
                    case 5:
                        fileName = @"better_together.mp4";
                        break;
                    case 6:
                        fileName = @"stopmotion.mp4";
                        break;
                    case 7:
                        fileName = @"happy_fathers_day.mp4";
                        break;
                    case 8:
                        fileName = @"all_you_need.mp4";
                        break;
                    case 9:
                        fileName = @"dia_de_parabens.mp4";
                        break;
                    case 10:
                        fileName = @"super_hero.mp4";
                        break;
                    case 11:
                        fileName = @"rena_cantando.mp4";
                        break;
                    case 12:
                        fileName = @"pascoa.mp4";
                        break;
                    case 13:
                        fileName = @"dia_das_maes.mp4";
                        break;
                    case 14:
                        fileName = @"dia_dos_namorados.mp4";
                        break;
                    default:
                        break;
                }
                

                NSArray *paths = NSSearchPathForDirectoriesInDomains
                (NSDocumentDirectory, NSUserDomainMask, YES);
                NSString *documentsDirectory = [paths objectAtIndex:0];

                NSString *filePath = [NSString stringWithFormat:@"%@/%@",
                                      documentsDirectory, fileName];
                
                
                if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
                {
                    UIView * myProgressView;
                    CERoundProgressView * progressPie;
                    if(UIUserInterfaceIdiomPad == [[UIDevice currentDevice] userInterfaceIdiom])
                    {
                        myProgressView = (UIView*)[[UIView alloc] initWithFrame:CGRectMake(320/2 - 180/2, 480/2 - 180/2, 180 * 2, 180 * 2)];
                        myProgressView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5f];
                        progressPie = [[CERoundProgressView alloc] initWithFrame:CGRectMake(59 * 2, 55 * 2, 70 * 2, 70 * 2)];
                        
                        UILabel * label = [[UILabel alloc] initWithFrame:CGRectMake(0,0, 180 * 2, 50)];
                        label.font = [UIFont systemFontOfSize:30.0f];
                        label.textAlignment = NSTextAlignmentCenter;
                        label.text = @"Downloading video";
                        label.textColor = [UIColor lightTextColor];
                        label.backgroundColor = [UIColor clearColor];
                        [myProgressView addSubview:label];
                        
                        
                        //    progressPie.animationDuration = 3.0f;
                        //    progressPie.progress = 0.0f;
                        progressPie.trackColor = [UIColor colorWithWhite:0.80 alpha:0.0];
                        progressPie.tintColor = [UIColor orangeColor];
                        progressPie.startAngle = (3.0*M_PI)/2.0;
                        progressPie.progress = .0;
                        progressPie.backgroundColor = [UIColor clearColor];
                        [myProgressView addSubview:progressPie];
                        myProgressView.center = [[[UIApplication sharedApplication] keyWindow] center];
                        [[[UIApplication sharedApplication] keyWindow] addSubview:myProgressView];
                    }
                    else
                    {
                        myProgressView = (UIView*)[[UIView alloc] initWithFrame:CGRectMake(320/2 - 180/2, 480/2 - 180/2, 180, 180)];
                        myProgressView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5f];
                        progressPie = [[CERoundProgressView alloc] initWithFrame:CGRectMake(59, 55, 70, 70)];
                        
                        UILabel * label = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 180, 30)];
                        label.textAlignment = NSTextAlignmentCenter;
                        label.text = @"Downloading video";
                        label.textColor = [UIColor lightTextColor];
                        label.backgroundColor = [UIColor clearColor];
                        [myProgressView addSubview:label];
                        
                        
                        //    progressPie.animationDuration = 3.0f;
                        //    progressPie.progress = 0.0f;
                        progressPie.trackColor = [UIColor colorWithWhite:0.80 alpha:0.0];
                        progressPie.tintColor = [UIColor orangeColor];
                        progressPie.startAngle = (3.0*M_PI)/2.0;
                        progressPie.progress = .0;
                        progressPie.backgroundColor = [UIColor clearColor];
                        [myProgressView addSubview:progressPie];
                        myProgressView.center = [[[UIApplication sharedApplication] keyWindow] center];
                        [[[UIApplication sharedApplication] keyWindow] addSubview:myProgressView];
                    }
                    
                    videoDownloader * vd = [[videoDownloader alloc] init];
                    [isDownloadingArray setObject:@YES atIndexedSubscript:touchedTarget];
                    [vd getVideo:[NSURL URLWithString:[NSString stringWithFormat:@"https://s3-sa-east-1.amazonaws.com/ipostal.videos/production/%@", fileName]] progress:^(float progress)
                    {
                        NSLog(@"progress:%f", progress);
                        progressPie.progress = progress;
                    } completion:^(NSData *videoData) {
                        NSArray *paths = NSSearchPathForDirectoriesInDomains
                        (NSDocumentDirectory, NSUserDomainMask, YES);
                        NSString *documentsDirectory = [paths objectAtIndex:0];
                        //make a file name to write the data to using the documents directory:
                        
                        NSString *filePath = [NSString stringWithFormat:@"%@/%@",
                                              documentsDirectory, fileName];
                        
                        [videoData writeToFile:filePath options:kNilOptions error:nil];
                        NSLog(@"filePath:%@", filePath);
                        NSLog(@"dataLength:%u", [videoData length]);
                        NSLog(@"dataLength:%u", [[NSData dataWithContentsOfFile:filePath] length]);
                        [videoPlayerHelper[touchedTarget] unload];
                        NSLog(@"loadVideo:%@", ([videoPlayerHelper[touchedTarget] load:filePath playImmediately:YES fromPosition:-1.0f])? @"YES":@"NO");
                        [isDownloadedArray setObject:@YES atIndexedSubscript:touchedTarget];
                        [isDownloadingArray setObject:@NO atIndexedSubscript:touchedTarget];
                        [myProgressView removeFromSuperview];
                        NSMutableDictionary * mutDict = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:@"cache control"]];
                        if (!mutDict)
                        {
                            mutDict = [NSMutableDictionary dictionary];
                        }
                        [mutDict setObject:[NSNumber numberWithInt:[[NSDate date] timeIntervalSince1970]] forKey:fileName];
                        [[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionaryWithDictionary:mutDict] forKey:@"cache control"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                    }
                     error:^(NSString *error)
                    {
                         [myProgressView removeFromSuperview];
                         [[[UIAlertView alloc] initWithTitle:@"Falta de conexão" message:error delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                    }];
                }
                else
                {
                    NSMutableDictionary * mutDict = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:@"cache control"]];
                    if (!mutDict)
                    {
                        mutDict = [NSMutableDictionary dictionary];
                    }
                    [mutDict setObject:[NSNumber numberWithInt:[[NSDate date] timeIntervalSince1970]] forKey:fileName];
                    [[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionaryWithDictionary:mutDict] forKey:@"cache control"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    NSLog(@"cache control:%@", mutDict);
                    [videoPlayerHelper[touchedTarget] unload];
                    NSLog(@"load moview:%@", ([videoPlayerHelper[touchedTarget] load:filePath playImmediately:YES fromPosition:-1.0f])?@"YES":@"NO");
                    [isDownloadedArray setObject:@YES atIndexedSubscript:touchedTarget];
                    [isDownloadingArray setObject:@(NO) atIndexedSubscript:touchedTarget];
                }
            }
        }
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
//    NSLog(@"renderFrameQCAR");
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


#warning CHANGE HERE 4
        int playerIndex = 0x0;
        if      (strcmp(imageTarget.getName(), "bebendo_leite"     ) == 0)  playerIndex = 0x0;
        else if (strcmp(imageTarget.getName(), "comemorar"         ) == 0)  playerIndex = 0x1;
        else if (strcmp(imageTarget.getName(), "Loro"              ) == 0)  playerIndex = 0x2;
        else if (strcmp(imageTarget.getName(), "bolo_rotatorio"    ) == 0)  playerIndex = 0x3;
        else if (strcmp(imageTarget.getName(), "over_the_rainbow"  ) == 0)  playerIndex = 0x4;
        else if (strcmp(imageTarget.getName(), "better_together"   ) == 0)  playerIndex = 0x5;
        else if (strcmp(imageTarget.getName(), "stopmotion"        ) == 0)  playerIndex = 0x6;
        else if (strcmp(imageTarget.getName(), "happy_fathers_day" ) == 0)  playerIndex = 0x7;
        else if (strcmp(imageTarget.getName(), "all_you_need"      ) == 0)  playerIndex = 0x8;
        else if (strcmp(imageTarget.getName(), "dia_de_parabens"   ) == 0)  playerIndex = 0x9;
        else if (strcmp(imageTarget.getName(), "super_hero"        ) == 0)  playerIndex = 0xa;
        else if (strcmp(imageTarget.getName(), "rena_cantando"     ) == 0)  playerIndex = 0xb;
        else if (strcmp(imageTarget.getName(), "pascoa"            ) == 0)  playerIndex = 0xc;
        else if (strcmp(imageTarget.getName(), "dia_das_maes"      ) == 0)  playerIndex = 0xd;
        else if (strcmp(imageTarget.getName(), "dia_dos_namorados" ) == 0)  playerIndex = 0xe;
        
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
//            NSLog(@"keyframe:\n%u, %f", frameTextureID, (float)[[obj3D texture] height] / (float)[[obj3D texture] width]);
        }
        
        // If the current status is valid (not NOT_READY or ERROR), render the
        // video quad with the texture we've just selected
//        if (NOT_READY != currentStatus || ![[isDownloadedArray objectAtIndex:playerIndex] boolValue])
        {
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
//            static int counter = 0;
//            if (counter % 30 == 0)
//            {
//                NSLog(@"\nframeTextureID:%u\n%f\n%i\n%i", frameTextureID, modelViewProjectionVideo.data[0], mvpMatrixHandle, texSampler2DHandle);
//                
//                NSLog(@"videoData:%f, %f", videoData[playerIndex].targetPositiveDimensions.data[0], videoData[playerIndex].targetPositiveDimensions.data[1]);
//                NSLog(@"aspectRatio:%f", aspectRatio);
//                NSLog(@"trackablePose:\n%f,%f,%f\n%f,%f,%f\n%f,%f,%f\n%f,%f,%f",
//                      trackablePose.data[0],
//                      trackablePose.data[1],
//                      trackablePose.data[2],
//                      trackablePose.data[3],
//                      trackablePose.data[4],
//                      trackablePose.data[5],
//                      trackablePose.data[6],
//                      trackablePose.data[7],
//                      trackablePose.data[8],
//                      trackablePose.data[9],
//                      trackablePose.data[10],
//                      trackablePose.data[11]);
//                
//            }
//            counter++;
            glDrawElements(GL_TRIANGLES, NUM_QUAD_INDEX, GL_UNSIGNED_SHORT, quadIndices);
            
            glDisableVertexAttribArray(vertexHandle);
            glDisableVertexAttribArray(normalHandle);
            glDisableVertexAttribArray(textureCoordHandle);
            
            glUseProgram(0);
        }
        
        // If the current status is not PLAYING, render an icon
        if (PLAYING != currentStatus) {
            GLuint iconTextureID;
            
            if ([[isDownloadingArray objectAtIndex:playerIndex] boolValue])
            {
                // ----- Display busy icon -----
                Object3D* obj3D = [objects3D objectAtIndex:OBJECT_BUSY_ICON];
                iconTextureID = [[obj3D texture] textureID];
            }
            else if(![[isDownloadedArray objectAtIndex:playerIndex] boolValue])
            {
                Object3D* obj3D = [objects3D objectAtIndex:OBJECT_PLAY_ICON];
                iconTextureID = [[obj3D texture] textureID];
            }
            else
            {
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
