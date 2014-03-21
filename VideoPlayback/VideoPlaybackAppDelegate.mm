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


@file
    VideoPlaybackAppDelegate.mm

@brief
    This sample application shows how to play a video in AR mode.
    
    Video from local files can be played directly on the image target.  Playback
    of remote files is supported in full screen mode only.
==============================================================================*/
/*
 
 The QCAR sample apps are organised to work with standard iOS view
 controller life cycles.
 
 * QCARutils contains all the code that initialises and manages the QCAR
 lifecycle plus some useful functions for accessing targets etc. This is a
 singleton class that makes QCAR accessible from anywhere within the app.
 
 * AR_EAGLView is a superclass that contains the OpenGL setup for its
 sub-class, EAGLView.
 
 Other classes and view hierarchy exists to establish a robust view life
 cycle:
 
 * ARParentViewController provides a root view for inclusion in other view
 hierarchies  presentModalViewController can present this VC safely. All
 associated views are included within it; it also handles the auto-rotate
 and resizing of the sub-views.
 
 * ARViewController manages the lifecycle of the Camera and Augmentations,
 calling QCAR:createAR, QCAR:destroyAR, QCAR:pauseAR and QCAR:resumeAR
 where required. It also manages the data for the view, such as loading
 textures.
 
 This configuration has been shown to work for iOS Modal and Tabbed views.
 It provides a model for re-usability where you want to produce a
 number of applications sharing code.
 
------------------------------------------------------------------------------*/

#import "VideoPlaybackAppDelegate.h"
#import "VPParentViewController.h"
#import "QCARutils.h"
#import "GAI.h"
#import "GAI-ID.h"
#import "VersionChecker.h"

@implementation VideoPlaybackAppDelegate

@synthesize arParentViewController;

namespace {
    BOOL firstTime = YES;
}

// Set up an information screen for the user
- (void)setupInfoScreen
{
    infoView = [[InfoView alloc] init];
    [window addSubview:infoView];
    
    // Poll to see if the camera video stream has started and, if so, enable the
    // continue button
    [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(enableContinue:) userInfo:nil repeats:YES];
}


// this is the application entry point
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [application setStatusBarHidden:YES];
    
    [[VersionChecker alloc] init];
    
    ////////// CACHE CONTROL ////////////
    {
        NSMutableDictionary * mutDict = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:@"cache control"]];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains
        (NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        long long totalSize;
#define MAX_SIZE 31457280
        do
        {
            totalSize = 0;
            for (NSString * fileName in mutDict)
            {
                NSString *filePath = [NSString stringWithFormat:@"%@/%@",
                                      documentsDirectory, fileName];
                totalSize += [[[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil] objectForKey:NSFileSize] longLongValue];
            }
            
            
            if (totalSize > MAX_SIZE)
            {
                int time = INT_MAX;
                NSString * toDelete;
                for (NSString * fileName in mutDict)
                {
                    if ([[mutDict objectForKey:fileName] integerValue] < time)
                        toDelete = fileName;
                }
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", documentsDirectory, toDelete] error:nil];
                [mutDict removeObjectForKey:toDelete];
            }
        }while (totalSize > MAX_SIZE);
#undef MAX_SIZE
        
        [[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionaryWithDictionary:mutDict] forKey:@"cache control"];
    }
    
    
    
    
    // Optional: automatically send uncaught exceptions to Google Analytics.
    [GAI sharedInstance].trackUncaughtExceptions = YES;
    // Optional: set Google Analytics dispatch interval to e.g. 20 seconds.
    [GAI sharedInstance].dispatchInterval = 20;
    // Optional: set debug to YES for extra debugging information.
    [GAI sharedInstance].debug = YES;
    // Create tracker instance.
    (void)[[GAI sharedInstance] trackerWithTrackingId:GoogleAnalytics_ID];
    
    
    QCARutils *qUtils = [QCARutils getInstance];
    
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    window = [[UIWindow alloc] initWithFrame: screenBounds];
    
    // Provide a list of targets we're expecting - the first in the list is the default
//    [qUtils addTargetName:@"Stones & Chips" atPath:@"ipostal_namorados_2013"];
    [qUtils addTargetName:@"namorados ipostal" atPath:@"iPostal.xml"];
    
    // Add the EAGLView and the overlay view to the window
    arParentViewController = [[VPParentViewController alloc] initWithWindow:window];
    arParentViewController.arViewRect = screenBounds;
    [window setRootViewController:arParentViewController];
    [window makeKeyAndVisible];
    
    return YES;
}



- (void)enableContinue:(NSTimer*)theTimer
{
    // Poll to see if the camera video stream has started and, if so, enable the
    // continue button on the info screen
    if ([QCARutils getInstance].videoStreamStarted == YES)
    {
        [theTimer invalidate];
        [[infoView continueButton] setEnabled:YES];
    }
}


- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // don't do this straight after startup - the view controller will do it
    if (firstTime == NO)
    {
        // do the same as when the view is shown
        [arParentViewController viewDidAppear:NO];
    }
    else {
        // Start playback from the current position on the first run of the app
        for (int i = 0; i < NUM_VIDEO_TARGETS; ++i) {
            videoPlaybackTime[i] = VIDEO_PLAYBACK_CURRENT_POSITION;
        }
    }
    
    // Load the video for use with the EAGLView
//    EAGLView* arView =
    [arParentViewController getARView];
    firstTime = NO;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    exit(0);
    // Remove the native movie player view (if it is displayed).  This gives us
    // a clean restart on iOS 4 and 5
    [arParentViewController removeMoviePlayerView];
    
    EAGLView* arView = [arParentViewController getARView];
    
    for (int i = 0; i < NUM_VIDEO_TARGETS; ++i) {
        VideoPlayerHelper* player = [arView getVideoPlayerHelper:i];
        
        // If the video is playing, pause it and store the index of the player
        // so playback can be resumed
        if (PLAYING == [player getStatus]) {
            [player pause];
        }
        
        // Store the current video playback time for use when resuming (even if
        // the player is currently paused)
        videoPlaybackTime[i] = [player getCurrentPosition];
        
        // Unload the video
        if (NO == [player unload]) {
            NSLog(@"Failed to unload media");
        }
    }
    
    // do the same as when the view has dissappeared
    [arParentViewController viewDidDisappear:NO];
    
    // Remove the info screen (if it's displayed)
    [infoView removeFromSuperview];
}


- (void)applicationWillTerminate:(UIApplication *)application
{
    // AR-specific actions
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Handle any background procedures not related to animation here.
    
    // Inform the AR parent view controller that the AR view should free any
    // easily recreated OpenGL ES resources
    [arParentViewController freeOpenGLESResources];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Handle any foreground procedures not related to animation here.
}

- (void)dealloc
{
    [infoView release];
    [arParentViewController release];
    [window release];
    
    [super dealloc];
}

@end
