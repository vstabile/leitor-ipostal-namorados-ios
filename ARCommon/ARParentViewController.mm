/*==============================================================================
 Copyright (c) 2010-2013 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/

#import "ARParentViewController.h"
#import "ARViewController.h"
#import "OverlayViewController.h"
#import "QCARutils.h"

@implementation ARParentViewController

@synthesize arViewRect;

// initialisation functions set up size of managed view
- (id)initWithWindow:(UIWindow*)window
{
    self = [super init];
    
    if (self) {
        // Custom initialization
        arViewRect.size = [[UIScreen mainScreen] bounds].size;
        arViewRect.origin.x = arViewRect.origin.y = 0;
        appWindow = window;
        [appWindow retain];
    }
    
    return self;
}

- (void)dealloc
{
    [arViewController release];
    [overlayViewController release];
    [parentView release];
    [appWindow release];
    [super dealloc];
}

- (void)loadView
{
    NSLog(@"ARParentVC: creating");
    [self createParentViewAndSplashContinuation];
    
    // Add the EAGLView and the overlay view to the window
    arViewController = [[ARViewController alloc] init];
    
    // need to set size here to setup camera image size for AR
    arViewController.arViewSize = arViewRect.size;
    [parentView addSubview:arViewController.view];
    
    // Hide the AR view so the parent view can be seen during start-up (the
    // parent view contains the splash continuation image on iPad and is empty
    // on iPhone and iPod)
    [arViewController.view setHidden:YES];
    
    // Create an auto-rotating overlay view and its view controller (used for
    // displaying UI objects, such as the camera control menu)
    overlayViewController = [[OverlayViewController alloc] init];
    [parentView addSubview: overlayViewController.view];
    
    self.view = parentView;
}

- (void)viewDidLoad
{
    NSLog(@"ARParentVC: loading");
    // it's important to do this from here as arViewController has the wrong idea of orientation
    [arViewController handleARViewRotation:self.interfaceOrientation];
    // we also have to set the overlay view to the correct width/height for the orientation
    [overlayViewController handleViewRotation:self.interfaceOrientation];
}


- (void)viewWillAppear:(BOOL)animated 
{
    NSLog(@"ARParentVC: appearing");
    // make sure we're oriented/sized properly before reappearing/restarting
    [arViewController handleARViewRotation:self.interfaceOrientation];
    [overlayViewController handleViewRotation:self.interfaceOrientation];
    [arViewController viewWillAppear:animated];
}


- (void)viewDidAppear:(BOOL)animated 
{
    NSLog(@"ARParentVC: appeared");
    [arViewController viewDidAppear:animated];
}


- (void)viewDidDisappear:(BOOL)animated
{
    NSLog(@"ARParentVC: dissappeared");
    [arViewController viewDidDisappear:animated];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (UIInterfaceOrientationPortrait == interfaceOrientation);
    // Support all orientations
//    return YES;
    
    // Support both portrait orientations
    //return (UIInterfaceOrientationPortrait == interfaceOrientation ||
    //        UIInterfaceOrientationPortraitUpsideDown == interfaceOrientation);

    // Support both landscape orientations
    //return (UIInterfaceOrientationLandscapeLeft == interfaceOrientation ||
    //        UIInterfaceOrientationLandscapeRight == interfaceOrientation);
}


// Not using iOS6 specific enums in order to compile on iOS5 and lower versions
-(NSUInteger)supportedInterfaceOrientations
{
    return ((1 << UIInterfaceOrientationPortrait) | (1 << UIInterfaceOrientationLandscapeLeft) | (1 << UIInterfaceOrientationLandscapeRight) | (1 << UIInterfaceOrientationPortraitUpsideDown));
}


// This is called on iOS 4 devices (when built with SDK 5.1 or 6.0) and iOS 6
// devices (when built with SDK 5.1)
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
    // ensure overlay size and AR orientation is correct for screen orientation
    [overlayViewController handleViewRotation:self.interfaceOrientation];
    [arViewController handleARViewRotation:interfaceOrientation];
    
    if (YES == [arViewController.view isHidden] && UIInterfaceOrientationIsLandscape([self interfaceOrientation])) {
        // iPad - the interface orientation is landscape, so we must switch to
        // the landscape splash image
        [self updateSplashScreenImageForLandscape];
    }
}


// This is called on iOS 6 devices (when built with SDK 5.1 or 6.0)
- (void) viewWillLayoutSubviews
{
    if (YES == [arViewController.view isHidden] && UIInterfaceOrientationIsLandscape([self interfaceOrientation])) {
        // iPad - the interface orientation is landscape, so we must switch to
        // the landscape splash image
        [self updateSplashScreenImageForLandscape];
    }
}


// touch handlers
- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    //[arViewController.arView touchesBegan:touches withEvent:event];
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    // iOS requires all events handled if touchesBegan is handled and not forwarded
    //[arViewController.arView touchesMoved:touches withEvent:event];
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    //[arViewController.arView touchesEnded:touches withEvent:event];

    // iOS requires all events handled if touchesBegan is handled and not forwarded
    UITouch* touch = [touches anyObject];
    
    int tc = [touch tapCount];
    if (2 == tc)
    {
        // Show camera control action sheet
        [[QCARutils getInstance] cameraCancelAF];
        [overlayViewController showOverlay];
    }
    if (1 == tc)
    {
        [[QCARutils getInstance] cameraTriggerAF];
    }
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    // iOS requires all events handled if touchesBegan is handled and not forwarded
}


#pragma mark -
#pragma mark Splash screen control
// Set up a continuation of the splash screen until the camera is initialised
- (void)createParentViewAndSplashContinuation
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    NSString* bgImageName = @"Default.png";
//    CGRect indicator1Rect = CGRectZero;
//    CGRect indicator2Rect = CGRectZero;

    if (UIUserInterfaceIdiomPad == [[UIDevice currentDevice] userInterfaceIdiom]) {
        // iPad
        if (YES == [self isRetinaEnabled])
        {
            bgImageName = @"Default-Portrait@2x~ipad.png";
        }
        else
        {
            bgImageName = @"Default-Portrait~ipad.png";
        }
//        indicator1Rect = CGRectMake(74,234,37,37);
//        indicator2Rect = CGRectMake(74, 778, 37, 37);
        
        continuarRect = CGRectMake(67, 117, 271, 51); //(67, 117, 51, 271)
        appstoreRect = CGRectMake(67, 702, 271, 51); //(67, 637, 51, 271)
    }
    else {
        // iPhone and iPod
        if (568 == screenBounds.size.height)
        {
            // iPhone 5
            bgImageName = @"Default-568h@2x.png";
//            indicator1Rect = CGRectMake(20,114,37,37);
//            indicator2Rect = CGRectMake(20, 420, 37, 37);
            
            continuarRect = CGRectMake(40, 48, 202, 37); //(20, 38, 37, 202)
            appstoreRect = CGRectMake(40, 355, 202, 37); //(20, 320, 37, 202)
        }
        else if (YES == [self isRetinaEnabled])
        {
            bgImageName = @"Default@2x.png";
            //            indicator1Rect = CGRectMake(20,97,37,37);
            //            indicator2Rect = CGRectMake(20, 345, 37, 37);
            
            continuarRect = CGRectMake(40, 30, 202, 37); //(20, 20, 37, 202)
            appstoreRect = CGRectMake(40, 271, 202, 37); //(20, 261, 37, 202)
        }
        else //iphone regular
        {
            bgImageName = @"Default.png";
            //            indicator1Rect = CGRectMake(20,97,37,37);
            //            indicator2Rect = CGRectMake(20, 345, 37, 37);
            
            continuarRect = CGRectMake(40, 30, 202, 37); //(20, 20, 37, 202)
            appstoreRect = CGRectMake(40, 271, 202, 37); //(20, 261, 37, 202)
        }
    }
//    indicator1 = [[UIActivityIndicatorView alloc] initWithFrame:indicator1Rect];
//    indicator1.hidesWhenStopped = YES;
//    indicator1.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
//    [indicator1 startAnimating];
    

//    indicator2 = [[UIActivityIndicatorView alloc] initWithFrame:indicator2Rect];
//    indicator2.hidesWhenStopped = YES;
//    indicator2.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
//    [indicator2 startAnimating];
    
    
    // Create the splash image
    UIImage *image = [UIImage imageNamed:bgImageName];
    
    if (UIUserInterfaceIdiomPad == [[UIDevice currentDevice] userInterfaceIdiom] && NO)
    {
        // iPad - create the parent view and populate it with the splash image
        parentView = [[UIImageView alloc] initWithImage:image];
        splashView.userInteractionEnabled = YES;
        parentView.frame = screenBounds;
    }
    else
    {
        // iPhone and iPod - create the parent view, but don't populate it with
        // an image
        parentView = [[UIImageView alloc] initWithFrame:arViewRect];

        // Create a splash view
        splashView = [[UIImageView alloc] initWithImage:image];
        splashView.userInteractionEnabled = YES;
        splashView.frame = screenBounds;

        [appWindow addSubview:splashView];
        // Add the splash view directly to the window (this prevents the splash
        // view from rotating, so it is always portrait)
    }
    

//    [appWindow addSubview:indicator1];
//    [appWindow addSubview:indicator2];
    
    // userInteractionEnabled defaults to NO for UIImageViews
    [parentView setUserInteractionEnabled:YES];
    
    // Poll to see if the camera video stream has started and if so remove the
    // splash screen
    [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(endSplash:) userInfo:nil repeats:YES];
}


- (void)updateSplashScreenImageForLandscape
{
    // The splash screen update needs to happen only once
    static BOOL done = NO;
    
    if (NO == done && UIUserInterfaceIdiomPad == [[UIDevice currentDevice] userInterfaceIdiom]) {
        done = YES;
        
        // On the iPad, we must support landscape splash screen images, to match
        // the one iOS shows for us.  Update the splash screen image
        // appropriately
        
        NSString* splashImageName = @"Default-Landscape~ipad.png";
        
        if (YES == [self isRetinaEnabled]) {
            splashImageName = @"Default-Landscape@2x~ipad.png";
        }
        
        // Load the landscape image
        UIImage* image = [UIImage imageNamed:splashImageName];
        
        // Update the size and image for the existing UIImageView object
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        CGRect frame;
        frame.origin.x = 0;
        frame.origin.y = 0;
        frame.size.width = screenBounds.size.height;
        frame.size.height = screenBounds.size.width;
        
        UIImageView* imageView = (UIImageView*)self.view;
        [imageView setImage:image];
    }
}


- (void)endSplash:(NSTimer*)theTimer
{
    // Poll to see if the camera video stream has started and if so remove the
    // splash screen
            NSLog(@"step3");
    if ([QCARutils getInstance].videoStreamStarted == YES)
    {
        NSLog(@"step4");
//        [indicator1 stopAnimating];
//        [indicator2 stopAnimating];
        
        
        
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        NSString* bgImageName = @"pattern.png";
        if (UIUserInterfaceIdiomPad == [[UIDevice currentDevice] userInterfaceIdiom]) {
            // iPad

            
            bgImageName = nil;
            
            {//bg
                UIView * bg = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 768, 1024)];
                bg.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"pattern.png"]];
                [splashView addSubview:bg];
            }
            
            
            { // INSTRUCOES
                UILabel * infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 400, 50)];
                infoLabel.font = [UIFont fontWithName:@"Intro" size:38.0f];
                //                infoLabel.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.8];
                infoLabel.backgroundColor = [UIColor clearColor];
                infoLabel.text = @"INSTRUÇÕES";
                infoLabel.textColor = [UIColor whiteColor];
                //                infoLabel.textColor = [UIColor orangeColor];
                [infoLabel setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                infoLabel.center = CGPointMake(228 + 260 - 1, 100 + 153 - 2);
                [splashView addSubview:infoLabel];
            }
            { // ENVIE UM CARTAO
                UILabel * infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 400, 50)];
                infoLabel.font = [UIFont fontWithName:@"Intro" size:38.0f];
                infoLabel.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.8];
                infoLabel.backgroundColor = [UIColor clearColor];
                infoLabel.text = @"ENVIE UM CARTÃO";
                infoLabel.textColor = [UIColor whiteColor];
                //                infoLabel.textColor = [UIColor orangeColor];
                [infoLabel setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                infoLabel.center = CGPointMake(228 + 263 - 4, 375 + 88 + 361 - 8);
                [splashView addSubview:infoLabel];
            }
            { // LEITOR IPOSTAL
                UILabel * infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 400, 40)];
                infoLabel.font = [UIFont fontWithName:@"Intro" size:40.0f];
                infoLabel.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.6];
                infoLabel.backgroundColor = [UIColor clearColor];
                infoLabel.text = @"LEITOR IPOSTAL";
                infoLabel.textColor = [UIColor colorWithRed:215/255.0f green:221/255.0f blue:212/255.0f alpha:1.0f];
                //                infoLabel.textColor = [UIColor orangeColor];
                [infoLabel setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                infoLabel.center = CGPointMake(279 + 382, 183 + 292 -45);
                [splashView addSubview:infoLabel];
            }
            { // INSTRUCAO TEXTO
                UILabel * infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 400, 300)];
                infoLabel.font = [UIFont fontWithName:@"RexBold" size:30.0f];
                //                infoLabel.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.6];
                infoLabel.backgroundColor = [UIColor clearColor];
                infoLabel.text = @"1. APONTE SUA CÂMERA PARA O LADO DA FRENTE DO CARTÃO MÁGICO\n\n2. CLIQUE NO SÍMBOLO ▶ QUE APARECERÁ EM SUA TELA\n\n3. SEU CARTÃO GANHARÁ VIDA!";
                infoLabel.lineBreakMode = NSLineBreakByWordWrapping;
                infoLabel.numberOfLines = 0;
                infoLabel.textColor = [UIColor colorWithRed:219/255.0f green:225/255.0f blue:216/255.0f alpha:1.0f];
                //                infoLabel.textColor = [UIColor orangeColor];
                [infoLabel setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                infoLabel.center = CGPointMake(147 + 133, 231 + 20);
                [splashView addSubview:infoLabel];
            }
            { // BAIXAR IPOSTAL TEXTO
                UILabel * infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 400, 300)];
                infoLabel.font = [UIFont fontWithName:@"RexBold" size:30.0f];
                infoLabel.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.6];
                infoLabel.backgroundColor = [UIColor clearColor];
                infoLabel.text = @"O IPOSTAL IMPRIME E ENTREGA CARTÕES PERSONALIZADOS PARA QUALQUER LUGAR DO MUNDO. RETRIBUA O CARINHO ENVIANDO VOCÊ TAMBÉM UM CARTÃO MÁGICO.";
                infoLabel.lineBreakMode = NSLineBreakByWordWrapping;
                infoLabel.textAlignment = NSTextAlignmentCenter;
                infoLabel.numberOfLines = 0;
                infoLabel.textColor = [UIColor colorWithRed:219/255.0f green:225/255.0f blue:216/255.0f alpha:1.0f];
                //                infoLabel.textColor = [UIColor orangeColor];
                [infoLabel setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                infoLabel.center = CGPointMake(147 + 143, 351 + 391 + 45);
                [splashView addSubview:infoLabel];
            }
            { // LOGO IPOSTAL
                UIImageView * logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"selo.png"]];
                logoView.contentMode = UIViewContentModeScaleAspectFit;
                logoView.frame = CGRectMake(0, 0, 152, 152);
                [logoView setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                logoView.center = CGPointMake(659, 127);
                [splashView addSubview:logoView];
            }
            { // SEPARADOR
                UIView * separator = [[UIView alloc] initWithFrame:CGRectMake(51, 511, 424, 4)];
                separator.backgroundColor = [UIColor colorWithRed:210/255.0f green:216/255.0f blue:208/255.0f alpha:1.0f];
                [splashView addSubview:separator];
            }
        }
        else {
            // iPhone and iPod
            if (568 == screenBounds.size.height)
            {
                { // INSTRUCOES
                    UILabel * infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 150, 30)];
                    infoLabel.font = [UIFont fontWithName:@"Intro" size:19.0f];
                    //                    infoLabel.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.8];
                    infoLabel.backgroundColor = [UIColor clearColor];
                    infoLabel.text = @"INSTRUÇÕES";
                    infoLabel.textColor = [UIColor whiteColor];
                    [infoLabel setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                    infoLabel.center = CGPointMake(228, 100);
                    [splashView addSubview:infoLabel];
                }
                { // ENVIE UM CARTAO
                    UILabel * infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
                    infoLabel.font = [UIFont fontWithName:@"Intro" size:19.0f];
                    //                    infoLabel.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.8];
                    infoLabel.backgroundColor = [UIColor clearColor];
                    infoLabel.text = @"ENVIE UM CARTÃO";
                    infoLabel.textColor = [UIColor whiteColor];
                    [infoLabel setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                    infoLabel.center = CGPointMake(228, 375 + 88);
                    [splashView addSubview:infoLabel];
                }
                { // LEITOR IPOSTAL
                    UILabel * infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
                    infoLabel.font = [UIFont fontWithName:@"Intro" size:20.0f];
                    //                    infoLabel.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.8];
                    infoLabel.backgroundColor = [UIColor clearColor];
                    infoLabel.text = @"LEITOR IPOSTAL";
                    infoLabel.textColor = [UIColor colorWithRed:215/255.0f green:221/255.0f blue:212/255.0f alpha:1.0f];
                    [infoLabel setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                    infoLabel.center = CGPointMake(279, 183);
                    [splashView addSubview:infoLabel];
                }
                { // INSTRUCAO TEXTO
                    UILabel * infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 210, 200)];
                    infoLabel.font = [UIFont fontWithName:@"RexBold" size:14.0f];
                    //                    infoLabel.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.8];
                    infoLabel.backgroundColor = [UIColor clearColor];
                    infoLabel.text = @"1. APONTE SUA CÂMERA PARA O LADO DA FRENTE DO CARTÃO MÁGICO\n\n2. CLIQUE NO SÍMBOLO ▶ QUE APARECERÁ EM SUA TELA\n\n3. SEU CARTÃO GANHARÁ VIDA!";
                    infoLabel.lineBreakMode = NSLineBreakByWordWrapping;
                    infoLabel.numberOfLines = 0;
                    infoLabel.textColor = [UIColor colorWithRed:219/255.0f green:225/255.0f blue:216/255.0f alpha:1.0f];
                    [infoLabel setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                    infoLabel.center = CGPointMake(142, 131);
                    [splashView addSubview:infoLabel];
                }
                { // BAIXAR IPOSTAL TEXTO
                    UILabel * infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
                    infoLabel.font = [UIFont fontWithName:@"RexBold" size:14.0f];
                    //                    infoLabel.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.6];
                    infoLabel.backgroundColor = [UIColor clearColor];
                    infoLabel.text = @"O IPOSTAL IMPRIME E ENTREGA CARTÕES PERSONALIZADOS PARA QUALQUER LUGAR DO MUNDO. RETRIBUA O CARINHO ENVIANDO VOCÊ TAMBÉM UM CARTÃO MÁGICO.";
                    infoLabel.lineBreakMode = NSLineBreakByWordWrapping;
                    infoLabel.textAlignment = NSTextAlignmentCenter;
                    infoLabel.numberOfLines = 0;
                    infoLabel.textColor = [UIColor colorWithRed:219/255.0f green:225/255.0f blue:216/255.0f alpha:1.0f];
                    [infoLabel setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                    infoLabel.center = CGPointMake(147, 351 + 88);
                    [splashView addSubview:infoLabel];
                }
                { // LOGO IPOSTAL
                    UIImageView * logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"selo.png"]];
                    logoView.contentMode = UIViewContentModeScaleAspectFit;
                    logoView.frame = CGRectMake(0, 0, 43, 43);
                    [logoView setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                    logoView.center = CGPointMake(282, 47);
                    [splashView addSubview:logoView];
                }
                { // SEPARADOR
                    UIView * separator = [[UIView alloc] initWithFrame:CGRectMake(58/2.0f, (478/2.0f) + 44, 413/2.0f, 4/2.0f)];
                    separator.backgroundColor = [UIColor colorWithRed:210/255.0f green:216/255.0f blue:208/255.0f alpha:1.0f];
                    [splashView addSubview:separator];
                }
                
                
                bgImageName = @"pattern.png";
            }
            else
            {
                { // INSTRUCOES
                    UILabel * infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 150, 30)];
                    infoLabel.font = [UIFont fontWithName:@"Intro" size:19.0f];
                    //                    infoLabel.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.8];
                    infoLabel.backgroundColor = [UIColor clearColor];
                    infoLabel.text = @"INSTRUÇÕES";
                    infoLabel.textColor = [UIColor whiteColor];
                    [infoLabel setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                    infoLabel.center = CGPointMake(228, 100);
                    [splashView addSubview:infoLabel];
                }
                { // ENVIE UM CARTAO
                    UILabel * infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
                    infoLabel.font = [UIFont fontWithName:@"Intro" size:19.0f];
                    //                    infoLabel.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.8];
                    infoLabel.backgroundColor = [UIColor clearColor];
                    infoLabel.text = @"ENVIE UM CARTÃO";
                    infoLabel.textColor = [UIColor whiteColor];
                    [infoLabel setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                    infoLabel.center = CGPointMake(228, 375);
                    [splashView addSubview:infoLabel];
                }
                { // LEITOR IPOSTAL
                    UILabel * infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
                    infoLabel.font = [UIFont fontWithName:@"Intro" size:20.0f];
                    //                    infoLabel.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.8];
                    infoLabel.backgroundColor = [UIColor clearColor];
                    infoLabel.text = @"LEITOR IPOSTAL";
                    infoLabel.textColor = [UIColor colorWithRed:215/255.0f green:221/255.0f blue:212/255.0f alpha:1.0f];
                    [infoLabel setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                    infoLabel.center = CGPointMake(279, 183);
                    [splashView addSubview:infoLabel];
                }
                { // INSTRUCAO TEXTO
                    UILabel * infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 210, 200)];
                    infoLabel.font = [UIFont fontWithName:@"RexBold" size:14.0f];
                    //                    infoLabel.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.8];
                    infoLabel.backgroundColor = [UIColor clearColor];
                    infoLabel.text = @"1. APONTE SUA CÂMERA PARA O LADO DA FRENTE DO CARTÃO MÁGICO\n\n2. CLIQUE NO SÍMBOLO ▶ QUE APARECERÁ EM SUA TELA\n\n3. SEU CARTÃO GANHARÁ VIDA!";
                    infoLabel.lineBreakMode = NSLineBreakByWordWrapping;
                    infoLabel.numberOfLines = 0;
                    infoLabel.textColor = [UIColor colorWithRed:219/255.0f green:225/255.0f blue:216/255.0f alpha:1.0f];
                    [infoLabel setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                    infoLabel.center = CGPointMake(142, 131);
                    [splashView addSubview:infoLabel];
                }
                { // BAIXAR IPOSTAL TEXTO
                    UILabel * infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
                    infoLabel.font = [UIFont fontWithName:@"RexBold" size:14.0f];
                    //                    infoLabel.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.6];
                    infoLabel.backgroundColor = [UIColor clearColor];
                    infoLabel.text = @"O IPOSTAL IMPRIME E ENTREGA CARTÕES PERSONALIZADOS PARA QUALQUER LUGAR DO MUNDO. RETRIBUA O CARINHO ENVIANDO VOCÊ TAMBÉM UM CARTÃO MÁGICO.";
                    infoLabel.lineBreakMode = NSLineBreakByWordWrapping;
                    infoLabel.textAlignment = NSTextAlignmentCenter;
                    infoLabel.numberOfLines = 0;
                    infoLabel.textColor = [UIColor colorWithRed:219/255.0f green:225/255.0f blue:216/255.0f alpha:1.0f];
                    [infoLabel setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                    infoLabel.center = CGPointMake(147, 351);
                    [splashView addSubview:infoLabel];
                }
                { // LOGO IPOSTAL
                    UIImageView * logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"selo.png"]];
                    logoView.contentMode = UIViewContentModeScaleAspectFit;
                    logoView.frame = CGRectMake(0, 0, 43, 43);
                    [logoView setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
                    logoView.center = CGPointMake(282, 47);
                    [splashView addSubview:logoView];
                }
                { // SEPARADOR
                    UIView * separator = [[UIView alloc] initWithFrame:CGRectMake(58/2.0f, 478/2.0f, 413/2.0f, 4/2.0f)];
                    separator.backgroundColor = [UIColor colorWithRed:210/255.0f green:216/255.0f blue:208/255.0f alpha:1.0f];
                    [splashView addSubview:separator];
                }
                
                if (YES == [self isRetinaEnabled])
                {
                    bgImageName = @"info@2x.png";
                }
                else //iphone regular
                {
                    bgImageName = @"info.png";
                }
                bgImageName = @"pattern.png";
            }
        }
        UIImage *image = [UIImage imageNamed:bgImageName];
        [splashView setImage:image];
        
        
        continuarButton = [[UIButton alloc] initWithFrame:continuarRect];
        [continuarButton addTarget:self action:@selector(removeInfoScreen) forControlEvents:UIControlEventTouchUpInside];
        [continuarButton setBackgroundImage:[UIImage imageNamed:@"bt_empty@2x.png"] forState:UIControlStateNormal];
        [continuarButton setTitle:@"COMEÇAR" forState:UIControlStateNormal];
        [continuarButton setTitleColor:[UIColor colorWithWhite:90/255.0f alpha:1.0f] forState:UIControlStateNormal];
        //        [continuarButton setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
        //        [continuarButton setTitleShadowColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        //        [[continuarButton titleLabel] setShadowOffset:CGSizeMake(1.0f, 1.0f)];
        [[continuarButton titleLabel] setFont:[UIFont fontWithName:@"Intro" size:(UIUserInterfaceIdiomPad == [[UIDevice currentDevice] userInterfaceIdiom])?32.0f:20.0f]];
        CGPoint pt = continuarButton.center;
        [continuarButton setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
        continuarButton.center = CGPointMake(pt.x - 110, pt.y + 70);
        [appWindow addSubview:continuarButton];
        
        appStoreButton = [[UIButton alloc] initWithFrame:appstoreRect];
        
        UIImageView * selo = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ic_launcher.png"]];
        selo.frame = CGRectMake(10,
                                (UIUserInterfaceIdiomPad == [[UIDevice currentDevice] userInterfaceIdiom])?5:3,
                                (UIUserInterfaceIdiomPad == [[UIDevice currentDevice] userInterfaceIdiom])?40:30,
                                (UIUserInterfaceIdiomPad == [[UIDevice currentDevice] userInterfaceIdiom])?40:30);
        [appStoreButton addSubview:selo];
        [appStoreButton addTarget:self action:@selector(downloadIpostal) forControlEvents:UIControlEventTouchUpInside];
        [appStoreButton setBackgroundImage:[UIImage imageNamed:@"bt_empty@2x.png"] forState:UIControlStateNormal];
        [appStoreButton setTitle:@"BAIXAR O IPOSTAL" forState:UIControlStateNormal];
        [appStoreButton setTitleColor:[UIColor colorWithWhite:90/255.0f alpha:1.0f] forState:UIControlStateNormal];
        //        [appStoreButton setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
        //        [appStoreButton setTitleShadowColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        //        [[appStoreButton titleLabel] setShadowOffset:CGSizeMake(1.0f, 1.0f)];
        [appStoreButton setTitleEdgeInsets:UIEdgeInsetsMake([appStoreButton titleEdgeInsets].top,
                                                            [appStoreButton titleEdgeInsets].left + 20,
                                                            [appStoreButton titleEdgeInsets].bottom,
                                                            [appStoreButton titleEdgeInsets].right - 10)];
        [[appStoreButton titleLabel] setFont:[UIFont fontWithName:@"Intro" size:(UIUserInterfaceIdiomPad == [[UIDevice currentDevice] userInterfaceIdiom])?20.0f:14.0f]];
        pt = appStoreButton.center;
        [appStoreButton setTransform:CGAffineTransformMakeRotation(M_PI / 2)];
        appStoreButton.center = CGPointMake(pt.x - 110, pt.y + 70);
        
        [appWindow addSubview:appStoreButton];
        
        // Stop the repeating timer
        [theTimer invalidate];
    }
}

- (void)downloadIpostal
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://itunes.apple.com/us/app/ipostal/id518463027?ls=1&mt=8"]];
    [self removeInfoScreen];
}


- (void)removeInfoScreen
{
    // Make the AR view visible
    [arViewController.view setHidden:NO];
    
    // The parent view no longer needs the image data (iPad)
    [parentView setImage:nil];
    
    // On iPhone and iPod, remove the splash view from the window
    // (splashView will be nil on iPad)
    [continuarButton removeFromSuperview];
    [appStoreButton removeFromSuperview];
    [splashView removeFromSuperview];
    [splashView release];
    splashView = nil;
}


// Test to see if the screen has retina mode
- (BOOL) isRetinaEnabled
{
    return ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)]
            &&
            ([UIScreen mainScreen].scale == 2.0));
}


// Free any OpenGL ES resources that are easily recreated when the app resumes
- (void)freeOpenGLESResources
{
    [arViewController freeOpenGLESResources];
}

@end
