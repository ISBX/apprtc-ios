//
//  ARTCRoomTextInputViewCell.h
//  AppRTC
//
//  Created by Kelly Chu on 3/7/15.
//  Copyright (c) 2015 ISBX. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ARTCRoomTextInputViewCellDelegate;

@interface ARTCRoomTextInputViewCell : UITableViewCell <UITextFieldDelegate>

@property (assign, nonatomic) id <ARTCRoomTextInputViewCellDelegate> delegate;

@property (strong, nonatomic) IBOutlet UITextField *textField;
@property (strong, nonatomic) IBOutlet UIView *textFieldBorderView;
@property (strong, nonatomic) IBOutlet UIButton *joinButton;
@property (strong, nonatomic) IBOutlet UILabel *errorLabel;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *errorLabelHeightConstraint; //used for animating

- (IBAction)touchButtonPressed:(id)sender;

@end

@protocol ARTCRoomTextInputViewCellDelegate<NSObject>
@optional
- (void)roomTextInputViewCell:(ARTCRoomTextInputViewCell *)cell shouldJoinRoom:(NSString *)room;
@end