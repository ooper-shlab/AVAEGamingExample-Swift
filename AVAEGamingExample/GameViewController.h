/*
    Copyright (C) 2015 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    GameViewController
*/

@import SceneKit;

#import "GameView.h"

@interface GameViewController : NSViewController <SCNPhysicsContactDelegate>

@property (assign) IBOutlet GameView *gameView;

@end
