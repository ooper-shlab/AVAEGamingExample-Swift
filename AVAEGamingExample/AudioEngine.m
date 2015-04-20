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

#import "AudioEngine.h"
#import <AVFoundation/AVFoundation.h>

@interface AudioEngine () {
    AVAudioEngine           *_engine;
    AVAudioEnvironmentNode  *_environment;
    AVAudioPCMBuffer        *_collisionSoundBuffer;
    NSMutableArray          *_collisionPlayerArray;
    AVAudioPlayerNode       *_launchSoundPlayer;
    AVAudioPCMBuffer        *_launchSoundBuffer;
    bool                    _multichannelOutputEnabled;
}
@end

@implementation AudioEngine

- (AVAudioPCMBuffer *)loadSoundIntoBuffer:(NSString *)filename
{
    // load the collision sound into a buffer
    NSURL *soundFileURL = [NSURL URLWithString:[[NSBundle mainBundle] pathForResource:filename ofType:@"caf"]];
    NSAssert(soundFileURL, @"Error creating URL to sound file");
    NSError *error;
    AVAudioFile *soundFile = [[AVAudioFile alloc] initForReading:soundFileURL commonFormat:AVAudioPCMFormatFloat32 interleaved:NO error:&error];
    NSAssert(soundFile != nil, @"Error creating soundFile, %@", error.localizedDescription);
    
    AVAudioPCMBuffer *outputBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:soundFile.processingFormat frameCapacity:(AVAudioFrameCount)soundFile.length];
    NSAssert([soundFile readIntoBuffer:outputBuffer error:&error], @"Error reading file into buffer, %@", error.localizedDescription);
    
    return outputBuffer;
}

- (instancetype)init
{
    if (self = [super init]) {
        _engine = [[AVAudioEngine alloc] init];
        _environment = [[AVAudioEnvironmentNode alloc] init];
        [_engine attachNode:_environment];
        
        // array that keeps track of all the collision players
        _collisionPlayerArray = [[NSMutableArray alloc] init];
        
        // load the collision sound into a buffer
        _collisionSoundBuffer = [self loadSoundIntoBuffer:@"bounce"];
        
        // load the launch sound into a buffer
        _launchSoundBuffer = [self loadSoundIntoBuffer:@"launchSound"];
        
        // setup the launch sound player
        _launchSoundPlayer = [[AVAudioPlayerNode alloc] init];
        [_engine attachNode:_launchSoundPlayer];
        _launchSoundPlayer.volume = 0.35;
        
        // wire everything up
        [self makeEngineConnections];
        
        // sign up for notifications about changes in output configuration
        [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioEngineConfigurationChangeNotification object:_engine queue:nil usingBlock: ^(NSNotification *note) {
            
            // if the engine configuration does change, rewire everything up once again
            NSLog(@"Engine configuration changed! Re-wiring connections...");
            [self makeEngineConnections];
            [self startEngine];
        }];
        
        // turn on the environment reverb
        _environment.reverbParameters.enable = YES;
        [_environment.reverbParameters loadFactoryReverbPreset:AVAudioUnitReverbPresetLargeHall];
        _environment.reverbParameters.level = -20.;
 
        // we're ready to start rendering so start the engine
        [self startEngine];
    }
    return self;
}

- (void)makeEngineConnections
{
    [_engine connect:_launchSoundPlayer to:_environment format:_launchSoundBuffer.format];
    [_engine connect:_environment to:_engine.outputNode format:[self constructOutputConnectionFormatForEnvironment]];
    
    // if we're connecting with a multichannel format, we need to pick a multichannel rendering algorithm
    AVAudio3DMixingRenderingAlgorithm renderingAlgo = _multichannelOutputEnabled ? AVAudio3DMixingRenderingAlgorithmSoundField : AVAudio3DMixingRenderingAlgorithmEqualPowerPanning;
    
    // if we already have a pool of collision players, connect all of them to the environment
    [_collisionPlayerArray enumerateObjectsUsingBlock:^(AVAudioPlayerNode *collisionPlayer, NSUInteger idx, BOOL *stop) {
        [_engine connect:collisionPlayer to:_environment format:_collisionSoundBuffer.format];
        collisionPlayer.renderingAlgorithm = renderingAlgo;
    }];
}

- (void)startEngine
{
    NSError *error;
    NSAssert([_engine startAndReturnError:&error], @"Error starting engine, %@", error.localizedDescription);
}

- (AVAudioFormat *)constructOutputConnectionFormatForEnvironment
{
    AVAudioFormat *environmentOutputConnectionFormat = nil;
    AVAudioChannelCount numHardwareOutputChannels = [_engine.outputNode outputFormatForBus:0].channelCount;
    const double hardwareSampleRate = [_engine.outputNode outputFormatForBus:0].sampleRate;
    
    // if we're connected to multichannel hardware, create a compatible multichannel format for the environment node
    if (numHardwareOutputChannels > 2 && numHardwareOutputChannels != 3) {
        if (numHardwareOutputChannels > 8) numHardwareOutputChannels = 8;
        
        // find an AudioChannelLayoutTag that the environment node knows how to render to
        // this is documented in AVAudioEnvironmentNode.h
        AudioChannelLayoutTag environmentOutputLayoutTag;
        switch (numHardwareOutputChannels) {
            case 4:
                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_4;
                break;
                
            case 5:
                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_5_0;
                break;
                
            case 6:
                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_6_0;
                break;
                
            case 7:
                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_7_0;
                break;
                
            case 8:
                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_8;
                break;
                
            default:
                // based on our logic, we shouldn't hit this case
                environmentOutputLayoutTag = kAudioChannelLayoutTag_Stereo;
                break;
        }
        
        // using that layout tag, now construct a format
        AVAudioChannelLayout *environmentOutputChannelLayout = [[AVAudioChannelLayout alloc] initWithLayoutTag:environmentOutputLayoutTag];
        environmentOutputConnectionFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:hardwareSampleRate channelLayout:environmentOutputChannelLayout];
        _multichannelOutputEnabled = true;
    }
    else {
        // stereo rendering format, this is the common case
        environmentOutputConnectionFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:hardwareSampleRate channels:2];
        _multichannelOutputEnabled = false;
    }
    
    return environmentOutputConnectionFormat;
}

- (void)createPlayerForSCNNode:(SCNNode *)node
{
    // create a new player and connect it to the environment node
    AVAudioPlayerNode *newPlayer = [[AVAudioPlayerNode alloc] init];
    
    [_engine attachNode:newPlayer];
    [_engine connect:newPlayer to:_environment format:_collisionSoundBuffer.format];
    [_collisionPlayerArray insertObject:newPlayer atIndex:[node.name integerValue]];
    
    // pick a rendering algorithm based on the rendering format
    AVAudio3DMixingRenderingAlgorithm renderingAlgo = _multichannelOutputEnabled ?
                                                      AVAudio3DMixingRenderingAlgorithmSoundField :
                                                      AVAudio3DMixingRenderingAlgorithmEqualPowerPanning;
    
    newPlayer.renderingAlgorithm = renderingAlgo;
    
    // turn up the reverb blend for this player
    newPlayer.reverbBlend = 0.3;
}

- (void)destroyPlayerForSCNNode:(SCNNode *)node
{
    NSInteger playerIndex = [node.name integerValue];
    AVAudioPlayerNode *player = _collisionPlayerArray[playerIndex];
    [player stop];
    [_engine disconnectNodeOutput:player];
}

- (void)playCollisionSoundForSCNNode:(SCNNode *)node position:(AVAudio3DPoint)position impulse:(float)impulse
{
    if (_engine.isRunning) {
        NSInteger playerIndex = [node.name integerValue];
        
        AVAudioPlayerNode *player = _collisionPlayerArray[playerIndex];
        
        [player scheduleBuffer:_collisionSoundBuffer atTime:nil options:AVAudioPlayerNodeBufferInterrupts completionHandler:nil];
        player.position = position;
        player.volume = [self calculateVolumeForImpulse:impulse];
        player.rate = [self calculatePlaybackRateForImpulse:impulse];
        
        [player play];
    }
}

- (void)playLaunchSound:(AVAudioNodeCompletionHandler)completionHandler
{
    if (_engine.isRunning) {
        [_launchSoundPlayer scheduleBuffer:_launchSoundBuffer completionHandler:completionHandler];
        [_launchSoundPlayer play];
    }
}

- (float)calculateVolumeForImpulse:(float)impulse
{
    // Simple mapping of impulse to volume
    
    const float volMinDB = -20.;
    const float impulseMax = 12.;
    
    if (impulse > impulseMax) impulse = impulseMax;
    float volDB = (impulse / impulseMax * -volMinDB) + volMinDB;
    
    return powf(10, (volDB / 20));
}

- (float)calculatePlaybackRateForImpulse:(float)impulse
{
    // Simple mapping of impulse to playback rate (pitch)
    // This gives the effect of the pitch dropping as the impulse reduces
    
    const float rateMax = 1.2;
    const float rateMin = 0.95;
    const float rateRange = rateMax - rateMin;
    const float impulseMax = 12.;
    const float impulseMin = 0.6;
    const float impulseRange = impulseMax - impulseMin;
    
    if (impulse > impulseMax)   impulse = impulseMax;
    if (impulse < impulseMin)   impulse = impulseMin;
    
    return (((impulse - impulseMin) / impulseRange) * rateRange) + rateMin;
}

@end
