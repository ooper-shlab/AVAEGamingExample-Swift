/*
    Copyright (C) 2015 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    AudioEngine is the main controller class that manages the following:
                    AVAudioEngine           *_engine;
                    AVAudioEnvironmentNode  *_environment;
                    AVAudioPCMBuffer        *_collisionSoundBuffer;
                    NSMutableArray          *_collisionPlayerArray;
                    AVAudioPlayerNode       *_launchSoundPlayer;
                    AVAudioPCMBuffer        *_launchSoundBuffer;
                    bool                    _multichannelOutputEnabled;
    
                 It creates and connects all the nodes, loads the buffers as well as controls the AVAudioEngine object itself.
*/

@import Foundation;
@import AVFoundation;
@import SceneKit;

@interface AudioEngine : NSObject

- (void)createPlayerForSCNNode:(SCNNode *)node;
- (void)destroyPlayerForSCNNode:(SCNNode *)node;

- (void)playCollisionSoundForSCNNode:(SCNNode *)node position:(AVAudio3DPoint)position impulse:(float)impulse;
- (void)playLaunchSound:(AVAudioNodeCompletionHandler)completionHandler;

@end
