//
//  AudioEngine.swift
//  AVAEGamingExample
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/20.
//
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
//
//@import Foundation;
import Foundation
//@import AVFoundation;
import AVFoundation
//@import SceneKit;
import SceneKit
//
//@interface AudioEngine : NSObject
@objc(AudioEngine)
class AudioEngine: NSObject {
//
//- (void)createPlayerForSCNNode:(SCNNode *)node;
//- (void)destroyPlayerForSCNNode:(SCNNode *)node;
//
//- (void)playCollisionSoundForSCNNode:(SCNNode *)node position:(AVAudio3DPoint)position impulse:(float)impulse;
//- (void)playLaunchSound:(AVAudioNodeCompletionHandler)completionHandler;
//
//@end
//
//#import "AudioEngine.h"
//#import <AVFoundation/AVFoundation.h>
//
//@interface AudioEngine () {
//    AVAudioEngine           *_engine;
    private var _engine: AVAudioEngine
//    AVAudioEnvironmentNode  *_environment;
    private var _environment: AVAudioEnvironmentNode
//    AVAudioPCMBuffer        *_collisionSoundBuffer;
    private var _collisionSoundBuffer: AVAudioPCMBuffer
//    NSMutableArray          *_collisionPlayerArray;
    private var _collisionPlayerArray: [AVAudioPlayerNode] = []
//    AVAudioPlayerNode       *_launchSoundPlayer;
    private var _launchSoundPlayer: AVAudioPlayerNode
//    AVAudioPCMBuffer        *_launchSoundBuffer;
    private var _launchSoundBuffer: AVAudioPCMBuffer
//    bool                    _multichannelOutputEnabled;
    private var _multichannelOutputEnabled: Bool = false
//}
//@end
//
//@implementation AudioEngine
//
//- (AVAudioPCMBuffer *)loadSoundIntoBuffer:(NSString *)filename
//{
    private class func loadSoundIntoBuffer(filename: String) -> AVAudioPCMBuffer {
//    // load the collision sound into a buffer
//    NSURL *soundFileURL = [NSURL URLWithString:[[NSBundle mainBundle] pathForResource:filename ofType:@"caf"]];
        let soundFileURL = NSURL(string: NSBundle.mainBundle().pathForResource(filename, ofType: "caf")!)
//    NSAssert(soundFileURL, @"Error creating URL to sound file");
        assert(soundFileURL != nil, "Error creating URL to sound file")
//    NSError *error;
//    AVAudioFile *soundFile = [[AVAudioFile alloc] initForReading:soundFileURL commonFormat:AVAudioPCMFormatFloat32 interleaved:NO error:&error];
        let soundFile: AVAudioFile!
        do {
            soundFile = try AVAudioFile(forReading: soundFileURL!, commonFormat: AVAudioCommonFormat.PCMFormatFloat32, interleaved: false)
        } catch let error as NSError {
            //soundFile = nil
            fatalError("Error creating soundFile, \(error.localizedDescription)")
        }
//    NSAssert(soundFile != nil, @"Error creating soundFile, %@", error.localizedDescription);
//
//    AVAudioPCMBuffer *outputBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:soundFile.processingFormat frameCapacity:(AVAudioFrameCount)soundFile.length];
        let outputBuffer = AVAudioPCMBuffer(PCMFormat: soundFile!.processingFormat, frameCapacity: AVAudioFrameCount(soundFile!.length))
//    NSAssert([soundFile readIntoBuffer:outputBuffer error:&error], @"Error reading file into buffer, %@", error.localizedDescription);
        do {
            try soundFile!.readIntoBuffer(outputBuffer)
        } catch let error as NSError {
            fatalError("Error reading file into buffer, \(error.localizedDescription)")
        }
//
//    return outputBuffer;
        return outputBuffer
//}
    }
//
//- (instancetype)init
//{
    override init() {
//    if (self = [super init]) {
//        _engine = [[AVAudioEngine alloc] init];
        _engine = AVAudioEngine()
//        _environment = [[AVAudioEnvironmentNode alloc] init];
        _environment = AVAudioEnvironmentNode()
//        [_engine attachNode:_environment];
//
//        // array that keeps track of all the collision players
//        _collisionPlayerArray = [[NSMutableArray alloc] init];
//
//        // load the collision sound into a buffer
//        _collisionSoundBuffer = [self loadSoundIntoBuffer:@"bounce"];
        _collisionSoundBuffer = AudioEngine.loadSoundIntoBuffer("bounce")
//
//        // load the launch sound into a buffer
//        _launchSoundBuffer = [self loadSoundIntoBuffer:@"launchSound"];
        _launchSoundBuffer = AudioEngine.loadSoundIntoBuffer("launchSound")
//
//        // setup the launch sound player
//        _launchSoundPlayer = [[AVAudioPlayerNode alloc] init];
        _launchSoundPlayer = AVAudioPlayerNode()
        super.init()

        _engine.attachNode(_environment)
//        [_engine attachNode:_launchSoundPlayer];
        _engine.attachNode(_launchSoundPlayer)
//        _launchSoundPlayer.volume = 0.35;
        _launchSoundPlayer.volume = 0.35
//
//        // wire everything up
//        [self makeEngineConnections];
        self.makeEngineConnections()
//
//        // sign up for notifications about changes in output configuration
//        [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioEngineConfigurationChangeNotification object:_engine queue:nil usingBlock: ^(NSNotification *note) {
        NSNotificationCenter.defaultCenter().addObserverForName(AVAudioEngineConfigurationChangeNotification, object: _engine, queue: nil) {note in
//
//            // if the engine configuration does change, rewire everything up once again
//            NSLog(@"Engine configuration changed! Re-wiring connections...");
            NSLog("Engine configuration changed! Re-wiring connections...")
//            [self makeEngineConnections];
            self.makeEngineConnections()
//            [self startEngine];
            self.startEngine()
//        }];
        }
//
//        // turn on the environment reverb
//        _environment.reverbParameters.enable = YES;
        _environment.reverbParameters.enable = true
//        [_environment.reverbParameters loadFactoryReverbPreset:AVAudioUnitReverbPresetLargeHall];
        _environment.reverbParameters.loadFactoryReverbPreset(AVAudioUnitReverbPreset.LargeHall)
//        _environment.reverbParameters.level = -20.;
        _environment.reverbParameters.level = -20.0
//
//        // we're ready to start rendering so start the engine
//        [self startEngine];
        self.startEngine()
//    }
//    return self;
//}
    }
//
//- (void)makeEngineConnections
//{
    private func makeEngineConnections() {
//    [_engine connect:_launchSoundPlayer to:_environment format:_launchSoundBuffer.format];
        _engine.connect(_launchSoundPlayer, to: _environment, format: _launchSoundBuffer.format)
//    [_engine connect:_environment to:_engine.outputNode format:[self constructOutputConnectionFormatForEnvironment]];
        _engine.connect(_environment, to: _engine.outputNode, format: self.constructOutputConnectionFormatForEnvironment())
//
//    // if we're connecting with a multichannel format, we need to pick a multichannel rendering algorithm
//    AVAudio3DMixingRenderingAlgorithm renderingAlgo = _multichannelOutputEnabled ? AVAudio3DMixingRenderingAlgorithmSoundField : AVAudio3DMixingRenderingAlgorithmEqualPowerPanning;
        let renderingAlgo: AVAudio3DMixingRenderingAlgorithm = _multichannelOutputEnabled ? .SoundField : .EqualPowerPanning
//
//    // if we already have a pool of collision players, connect all of them to the environment
//    [_collisionPlayerArray enumerateObjectsUsingBlock:^(AVAudioPlayerNode *collisionPlayer, NSUInteger idx, BOOL *stop) {
        for collisionPlayer in _collisionPlayerArray {
//        [_engine connect:collisionPlayer to:_environment format:_collisionSoundBuffer.format];
            _engine.connect(collisionPlayer, to: _environment, format: _collisionSoundBuffer.format)
//        collisionPlayer.renderingAlgorithm = renderingAlgo;
            collisionPlayer.renderingAlgorithm = renderingAlgo
//    }];
        }
//}
    }
//
//- (void)startEngine
//{
    private func startEngine() {
//    NSError *error;
//    NSAssert([_engine startAndReturnError:&error], @"Error starting engine, %@", error.localizedDescription);
        do {
            try _engine.start()
        } catch let error as NSError {
            fatalError("Error starting engine, \(error.localizedDescription)")
        }
//}
    }
//
//- (AVAudioFormat *)constructOutputConnectionFormatForEnvironment
//{
    private func constructOutputConnectionFormatForEnvironment() -> AVAudioFormat {
//    AVAudioFormat *environmentOutputConnectionFormat = nil;
        let environmentOutputConnectionFormat: AVAudioFormat
//    AVAudioChannelCount numHardwareOutputChannels = [_engine.outputNode outputFormatForBus:0].channelCount;
        let numHardwareOutputChannels = _engine.outputNode.outputFormatForBus(0).channelCount
//    const double hardwareSampleRate = [_engine.outputNode outputFormatForBus:0].sampleRate;
        let hardwareSampleRate = _engine.outputNode.outputFormatForBus(0).sampleRate
//
//    // if we're connected to multichannel hardware, create a compatible multichannel format for the environment node
//    if (numHardwareOutputChannels > 2 && numHardwareOutputChannels != 3) {
        if numHardwareOutputChannels > 2 && numHardwareOutputChannels != 3 {
//        if (numHardwareOutputChannels > 8) numHardwareOutputChannels = 8;
//
//        // find an AudioChannelLayoutTag that the environment node knows how to render to
//        // this is documented in AVAudioEnvironmentNode.h
//        AudioChannelLayoutTag environmentOutputLayoutTag;
            let environmentOutputLayoutTag: AudioChannelLayoutTag
//        switch (numHardwareOutputChannels) {
            switch numHardwareOutputChannels {
//            case 4:
            case 4:
//                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_4;
                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_4
//                break;
//
//            case 5:
            case 5:
//                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_5_0;
                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_5_0
//                break;
//
//            case 6:
            case 6:
//                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_6_0;
                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_6_0
//                break;
//
//            case 7:
            case 7:
//                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_7_0;
                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_7_0
//                break;
//
//            case 8:
            case 8:
//                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_8;
                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_8
//                break;
//
//            default:
            default:
//                // based on our logic, we shouldn't hit this case
//                environmentOutputLayoutTag = kAudioChannelLayoutTag_Stereo;
                environmentOutputLayoutTag = kAudioChannelLayoutTag_Stereo
//                break;
//        }
            }
//
//        // using that layout tag, now construct a format
//        AVAudioChannelLayout *environmentOutputChannelLayout = [[AVAudioChannelLayout alloc] initWithLayoutTag:environmentOutputLayoutTag];
            let environmentOutputChannelLayout = AVAudioChannelLayout(layoutTag: environmentOutputLayoutTag)
//        environmentOutputConnectionFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:hardwareSampleRate channelLayout:environmentOutputChannelLayout];
            environmentOutputConnectionFormat = AVAudioFormat(standardFormatWithSampleRate: hardwareSampleRate, channelLayout: environmentOutputChannelLayout)
//        _multichannelOutputEnabled = true;
            _multichannelOutputEnabled = true
//    }
//    else {
        } else {
//        // stereo rendering format, this is the common case
//        environmentOutputConnectionFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:hardwareSampleRate channels:2];
        environmentOutputConnectionFormat = AVAudioFormat(standardFormatWithSampleRate: hardwareSampleRate, channels: 2)
//        _multichannelOutputEnabled = false;
            _multichannelOutputEnabled = false
//    }
        }
//
//    return environmentOutputConnectionFormat;
        return environmentOutputConnectionFormat
//}
    }
//
//- (void)createPlayerForSCNNode:(SCNNode *)node
//{
    func createPlayerForSCNNode(node: SCNNode) {
//    // create a new player and connect it to the environment node
//    AVAudioPlayerNode *newPlayer = [[AVAudioPlayerNode alloc] init];
        let newPlayer = AVAudioPlayerNode()
//
//    [_engine attachNode:newPlayer];
        _engine.attachNode(newPlayer)
//    [_engine connect:newPlayer to:_environment format:_collisionSoundBuffer.format];
        _engine.connect(newPlayer, to: _environment, format: _collisionSoundBuffer.format)
//    [_collisionPlayerArray insertObject:newPlayer atIndex:[node.name integerValue]];
        _collisionPlayerArray.insert(newPlayer, atIndex: Int(node.name!)!)
//
//    // pick a rendering algorithm based on the rendering format
//    AVAudio3DMixingRenderingAlgorithm renderingAlgo = _multichannelOutputEnabled ?
        let renderingAlgo: AVAudio3DMixingRenderingAlgorithm = _multichannelOutputEnabled ?
//                                                      AVAudio3DMixingRenderingAlgorithmSoundField :
            .SoundField :
//                                                      AVAudio3DMixingRenderingAlgorithmEqualPowerPanning;
            .EqualPowerPanning
//
//    newPlayer.renderingAlgorithm = renderingAlgo;
        newPlayer.renderingAlgorithm = renderingAlgo
//
//    // turn up the reverb blend for this player
//    newPlayer.reverbBlend = 0.3;
        newPlayer.reverbBlend = 0.3
//}
    }
//
//- (void)destroyPlayerForSCNNode:(SCNNode *)node
//{
    func destroyPlayerForSCNNode(node: SCNNode) {
//    NSInteger playerIndex = [node.name integerValue];
        let playerIndex = Int(node.name!)!
//    AVAudioPlayerNode *player = _collisionPlayerArray[playerIndex];
        let player = _collisionPlayerArray[playerIndex]
//    [player stop];
        player.stop()
//    [_engine disconnectNodeOutput:player];
        _engine.disconnectNodeOutput(player)
//}
    }
//
//- (void)playCollisionSoundForSCNNode:(SCNNode *)node position:(AVAudio3DPoint)position impulse:(float)impulse
//{
    func playCollisionSoundForSCNNode(node: SCNNode, position: AVAudio3DPoint, impulse: Float) {
//    if (_engine.isRunning) {
        if _engine.running {
//        NSInteger playerIndex = [node.name integerValue];
            let playerIndex = Int(node.name!)!
//
//        AVAudioPlayerNode *player = _collisionPlayerArray[playerIndex];
            let player = _collisionPlayerArray[playerIndex]
//
//        [player scheduleBuffer:_collisionSoundBuffer atTime:nil options:AVAudioPlayerNodeBufferInterrupts completionHandler:nil];
            player.scheduleBuffer(_collisionSoundBuffer, atTime: nil, options: AVAudioPlayerNodeBufferOptions.Interrupts, completionHandler: nil)
//        player.position = position;
            player.position = position
//        player.volume = [self calculateVolumeForImpulse:impulse];
            player.volume = self.calculateVolumeForImpulse(impulse)
//        player.rate = [self calculatePlaybackRateForImpulse:impulse];
            player.rate = self.calculatePlaybackRateForImpulse(impulse)
//
//        [player play];
            player.play()
//    }
        }
//}
    }
//
//- (void)playLaunchSound:(AVAudioNodeCompletionHandler)completionHandler
//{
    func playLaunchSound(completionHandler: AVAudioNodeCompletionHandler) {
//    if (_engine.isRunning) {
        if _engine.running {
//        [_launchSoundPlayer scheduleBuffer:_launchSoundBuffer completionHandler:completionHandler];
            _launchSoundPlayer.scheduleBuffer(_launchSoundBuffer, completionHandler: completionHandler)
//        [_launchSoundPlayer play];
            _launchSoundPlayer.play()
//    }
        }
//}
    }
//
//- (float)calculateVolumeForImpulse:(float)impulse
//{
    private func calculateVolumeForImpulse(var impulse: Float) -> Float {
//    // Simple mapping of impulse to volume
//
//    const float volMinDB = -20.;
        let volMinDB: Float = -20.0
//    const float impulseMax = 12.;
        let impulseMax: Float = 12.0
//
//    if (impulse > impulseMax) impulse = impulseMax;
        if impulse > impulseMax { impulse = impulseMax }
//    float volDB = (impulse / impulseMax * -volMinDB) + volMinDB;
        let volDB = (impulse / impulseMax * -volMinDB) + volMinDB
//
//    return powf(10, (volDB / 20));
        return powf(10, (volDB / 20))
//}
    }
//
//- (float)calculatePlaybackRateForImpulse:(float)impulse
//{
    private func calculatePlaybackRateForImpulse(var impulse: Float) -> Float {
//    // Simple mapping of impulse to playback rate (pitch)
//    // This gives the effect of the pitch dropping as the impulse reduces
//
//    const float rateMax = 1.2;
        let rateMax: Float = 1.2
//    const float rateMin = 0.95;
        let rateMin: Float = 0.95
//    const float rateRange = rateMax - rateMin;
        let rateRange: Float = rateMax - rateMin
//    const float impulseMax = 12.;
        let impulseMax: Float = 12.0
//    const float impulseMin = 0.6;
        let impulseMin: Float = 0.6
//    const float impulseRange = impulseMax - impulseMin;
        let impulseRange: Float = impulseMax - impulseMin
//
//    if (impulse > impulseMax)   impulse = impulseMax;
        if impulse > impulseMax  { impulse = impulseMax }
//    if (impulse < impulseMin)   impulse = impulseMin;
        if impulse < impulseMin  { impulse = impulseMin }
//
//    return (((impulse - impulseMin) / impulseRange) * rateRange) + rateMin;
        return (((impulse - impulseMin) / impulseRange) * rateRange) + rateMin
//}
    }
//
//@end
}