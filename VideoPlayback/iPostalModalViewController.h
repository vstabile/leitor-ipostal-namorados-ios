//
//  iPostalModalViewController.h
//  VideoPlayback
//
//  Created by Victor on 23/05/13.
//
//

#import <UIKit/UIKit.h>

@interface iPostalModalViewController : UIViewController{
    
}
- (IBAction)ipostalclicked:(id)sender;
- (IBAction)okClicked:(id)sender;
@property (retain, nonatomic) IBOutlet UIButton *comecarBtn;
@property (retain, nonatomic) IBOutlet UIButton *baixarBtn;
@property (retain, nonatomic) IBOutlet UIImageView *bgImage;

@end
