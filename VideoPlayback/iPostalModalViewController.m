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
    [[[GAI sharedInstance] defaultTracker] sendView:@"modal"];
	// Do any additional setup after loading the view.
}

- (IBAction)ipostalclicked:(id)sender {
    [[[GAI sharedInstance] defaultTracker] sendEventWithCategory:@""
                                                      withAction:@""
                                                       withLabel:@""
                                                       withValue:nil];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.google.com"]];
    [self dismissModalViewControllerAnimated:YES];
}

- (IBAction)okClicked:(id)sender {
    [self dismissModalViewControllerAnimated:YES];
}
@end
