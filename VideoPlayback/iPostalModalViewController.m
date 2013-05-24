//
//  iPostalModalViewController.m
//  VideoPlayback
//
//  Created by Victor on 23/05/13.
//
//

#import "iPostalModalViewController.h"
#import "GAI.h"

@interface iPostalModalViewController ()

@end

@implementation iPostalModalViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [[[GAI sharedInstance] defaultTracker] sendView:@"home"];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        
    }
    else
    {
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        if ([UIScreen mainScreen].scale == 2.f && screenHeight == 568.0f)
        {
            self.bgImage.image = [UIImage imageNamed:@"info-568h.png"];
            self.comecarBtn.frame = CGRectMake(20, 38, 37, 202);
            self.baixarBtn.frame = CGRectMake(20, 320, 37, 202);
        }
    }

    
    
	// Do any additional setup after loading the view.
}

- (IBAction)ipostalclicked:(id)sender {
    [[[GAI sharedInstance] defaultTracker] sendEventWithCategory:@"uiAction"
                                                      withAction:@"download ipostal"
                                                       withLabel:@"dia dos namorados"
                                                       withValue:nil];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://itunes.apple.com/us/app/ipostal/id518463027?ls=1&mt=8"]];
    [self dismissModalViewControllerAnimated:YES];
}

- (IBAction)okClicked:(id)sender {
    [self dismissModalViewControllerAnimated:YES];
}
- (void)dealloc {
    [_comecarBtn release];
    [_baixarBtn release];
    [_bgImage release];
    [super dealloc];
}
- (void)viewDidUnload {
    [self setComecarBtn:nil];
    [self setBaixarBtn:nil];
    [self setBgImage:nil];
    [super viewDidUnload];
}
@end
