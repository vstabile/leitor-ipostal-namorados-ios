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

#import "VPParentViewController.h"
#import "ARViewController.h"
#import "OverlayViewController.h"
#import "EAGLView.h"
#import "iPostalModalViewController.h"


@implementation VPParentViewController // subclass of ARParentViewController

- (void) viewDidLoad{
    
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    static bool modalActived = NO;
    if(!modalActived){
        NSString * xibName = @"iPostalModalView";
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            xibName = @"iPostalModalView~ipad";
        iPostalModalViewController *target = [[iPostalModalViewController alloc] initWithNibName:xibName bundle:[NSBundle mainBundle]];
        [self presentModalViewController:target animated:NO];
        modalActived = YES;
    }
}

// Pass touches on to the AR view (EAGLView)
- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
    [arViewController.arView touchesBegan:touches withEvent:event];
}


- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{
    [arViewController.arView touchesEnded:touches withEvent:event];
}


- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Implemented only to prevent the super class methods from executing
}


- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Implemented only to prevent the super class methods from executing
}


// Add a movie player view as a subview of the main (parent) view
- (void)addMoviePlayerToMainView:(MPMoviePlayerController*)player
{
    [parentView addSubview:player.view];
    [player retain];
    moviePlayer = player;
}


- (void)removeMoviePlayerView
{
    // We must stop the movie player from being fullscreen before removing its
    // view from the superview
    [moviePlayer setFullscreen:NO];
    [moviePlayer.view removeFromSuperview];
    [moviePlayer release];
    moviePlayer = nil;
}


// Return the AR view
- (EAGLView*)getARView
{
    return arViewController.arView;
}

@end
