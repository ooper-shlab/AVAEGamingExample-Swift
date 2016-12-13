//
//  AudioEngine.swift
//  AVAEGamingExample
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/20.
//
/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
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

import Foundation
import AVFoundation
import SceneKit

@objc protocol AudioEngineDelegate: NSObjectProtocol {
    
    @objc optional func engineWasInterrupted()
    @objc optional func engineHasRestarted()
    @objc optional func engineConfigurationHasChanged()
}

@objc(AudioEngine)
class AudioEngine: NSObject {
    
    weak var delegate: AudioEngineDelegate?
    
    private var _engine: AVAudioEngine
    private var _environment: AVAudioEnvironmentNode
    private var _collisionSoundBuffer: AVAudioPCMBuffer
    private var _collisionPlayerArray: [AVAudioPlayerNode] = []
    private var _launchSoundPlayer: AVAudioPlayerNode
    private var _launchSoundBuffer: AVAudioPCMBuffer
    private var _multichannelOutputEnabled: Bool = false
    
    // mananging session and configuration changes
    private var _isSessionInterrupted: Bool = false
    private var _isConfigChangePending: Bool = false
    
    private class func loadSoundIntoBuffer(_ filename: String) -> AVAudioPCMBuffer {
        
        // load the collision sound into a buffer
        let soundFileURL = URL(string: Bundle.main.path(forResource: filename, ofType: "caf")!)
        assert(soundFileURL != nil, "Error creating URL to sound file")
        
        let soundFile: AVAudioFile!
        do {
            soundFile = try AVAudioFile(forReading: soundFileURL!, commonFormat: AVAudioCommonFormat.pcmFormatFloat32, interleaved: false)
        } catch let error as NSError {
            //soundFile = nil
            fatalError("Error creating soundFile, \(error.localizedDescription)")
        }
        
        let outputBuffer = AVAudioPCMBuffer(pcmFormat: soundFile!.processingFormat, frameCapacity: AVAudioFrameCount(soundFile!.length))
        do {
            try soundFile!.read(into: outputBuffer)
        } catch let error as NSError {
            fatalError("Error reading file into buffer, \(error.localizedDescription)")
        }
        
        return outputBuffer
    }
    
    var isRunning: Bool {
        get {
            return _engine.isRunning;
        }
        set {
            //ignored
        }
    }
    
    override init() {
        _engine = AVAudioEngine()
        _environment = AVAudioEnvironmentNode()
        
        // array that keeps track of all the collision players
        
        // load the collision sound into a buffer
        _collisionSoundBuffer = AudioEngine.loadSoundIntoBuffer("bounce")
        
        // load the launch sound into a buffer
        _launchSoundBuffer = AudioEngine.loadSoundIntoBuffer("launchSound")
        
        // setup the launch sound player
        _launchSoundPlayer = AVAudioPlayerNode()
        super.init()
        
        #if os(iOS)
            self.initAVAudioSession()
        #endif
        
        _engine.attach(_environment)
        _engine.attach(_launchSoundPlayer)
        _launchSoundPlayer.volume = 0.35
        
        // wire everything up
        self.makeEngineConnections()
        
        // sign up for notifications about changes in output configuration
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVAudioEngineConfigurationChange, object: _engine, queue: nil) {note in
            
            // if we've received this notification, something has changed and the engine has been stopped
            // re-wire all the connections and start the engine
            
            self._isConfigChangePending = true
            
            if !self._isSessionInterrupted {
                NSLog("Received a \(Notification.Name.AVAudioEngineConfigurationChange) notification!")
                NSLog("Re-wiring connections and starting once again")
                self.makeEngineConnections()
                self.startEngine()
            } else {
                NSLog("Session is interrupted, deferring changes")
            }
            
            // post notification
            self.delegate?.engineConfigurationHasChanged?()
        }
        
        // turn on the environment reverb
        _environment.reverbParameters.enable = true
        _environment.reverbParameters.level = -20.0
        _environment.reverbParameters.loadFactoryReverbPreset(AVAudioUnitReverbPreset.largeHall)
        
        // we're ready to start rendering so start the engine
        self.startEngine()
    }
    
    private func makeEngineConnections() {
        _engine.connect(_launchSoundPlayer, to: _environment, format: _launchSoundBuffer.format)
        _engine.connect(_environment, to: _engine.outputNode, format: self.constructOutputConnectionFormatForEnvironment())
        
        // if we're connecting with a multichannel format, we need to pick a multichannel rendering algorithm
        let renderingAlgo: AVAudio3DMixingRenderingAlgorithm = _multichannelOutputEnabled ? .soundField : .equalPowerPanning
        
        // if we already have a pool of collision players, connect all of them to the environment
        for collisionPlayer in _collisionPlayerArray {
            _engine.connect(collisionPlayer, to: _environment, format: _collisionSoundBuffer.format)
            collisionPlayer.renderingAlgorithm = renderingAlgo
        }
    }
    
    private func startEngine() {
        do {
            try _engine.start()
        } catch let error as NSError {
            fatalError("Error starting engine, \(error.localizedDescription)")
        }
    }
    
    private func constructOutputConnectionFormatForEnvironment() -> AVAudioFormat {
        let environmentOutputConnectionFormat: AVAudioFormat
        let numHardwareOutputChannels = _engine.outputNode.outputFormat(forBus: 0).channelCount
        let hardwareSampleRate = _engine.outputNode.outputFormat(forBus: 0).sampleRate
        
        // if we're connected to multichannel hardware, create a compatible multichannel format for the environment node
        if numHardwareOutputChannels > 2 && numHardwareOutputChannels != 3 {
            
            // find an AudioChannelLayoutTag that the environment node knows how to render to
            // this is documented in AVAudioEnvironmentNode.h
            let environmentOutputLayoutTag: AudioChannelLayoutTag
            switch numHardwareOutputChannels {
            case 4:
                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_4
                
            case 5:
                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_5_0
                
            case 6:
                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_6_0
                
            case 7:
                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_7_0
                
            case 8:
                environmentOutputLayoutTag = kAudioChannelLayoutTag_AudioUnit_8
                
            default:
                // based on our logic, we shouldn't hit this case
                environmentOutputLayoutTag = kAudioChannelLayoutTag_Stereo
            }
            
            // using that layout tag, now construct a format
            let environmentOutputChannelLayout = AVAudioChannelLayout(layoutTag: environmentOutputLayoutTag)
            environmentOutputConnectionFormat = AVAudioFormat(standardFormatWithSampleRate: hardwareSampleRate, channelLayout: environmentOutputChannelLayout)
            _multichannelOutputEnabled = true
        } else {
            // stereo rendering format, this is the common case
            environmentOutputConnectionFormat = AVAudioFormat(standardFormatWithSampleRate: hardwareSampleRate, channels: 2)
            _multichannelOutputEnabled = false
        }
        
        return environmentOutputConnectionFormat
    }
    
    func createPlayerForSCNNode(_ node: SCNNode) {
        // create a new player and connect it to the environment node
        let newPlayer = AVAudioPlayerNode()
        _engine.attach(newPlayer)
        _engine.connect(newPlayer, to: _environment, format: _collisionSoundBuffer.format)
        _collisionPlayerArray.insert(newPlayer, at: Int(node.name!)!)
        
        // pick a rendering algorithm based on the rendering format
        let renderingAlgo: AVAudio3DMixingRenderingAlgorithm = _multichannelOutputEnabled ?
            .soundField :
            .equalPowerPanning
        
        newPlayer.renderingAlgorithm = renderingAlgo
        
        // turn up the reverb blend for this player
        newPlayer.reverbBlend = 0.3
    }
    
    func destroyPlayerForSCNNode(_ node: SCNNode) {
        let playerIndex = Int(node.name!)!
        let player = _collisionPlayerArray[playerIndex]
        player.stop()
        _engine.disconnectNodeOutput(player)
    }
    
    func playCollisionSoundForSCNNode(_ node: SCNNode, position: AVAudio3DPoint, impulse: Float) {
        if _engine.isRunning {
            let playerIndex = Int(node.name!)!
            let player = _collisionPlayerArray[playerIndex]
            player.scheduleBuffer(_collisionSoundBuffer, at: nil, options: AVAudioPlayerNodeBufferOptions.interrupts, completionHandler: nil)
            player.position = position
            player.volume = self.calculateVolumeForImpulse(impulse)
            player.rate = self.calculatePlaybackRateForImpulse(impulse)
            player.play()
        }
    }
    
    func playLaunchSoundAtPosition(_ position: AVAudio3DPoint, completionHandler: @escaping AVAudioNodeCompletionHandler) {
        if _engine.isRunning {
            _launchSoundPlayer.position = position
            _launchSoundPlayer.scheduleBuffer(_launchSoundBuffer, completionHandler: completionHandler)
            _launchSoundPlayer.play()
        }
    }
    
    private func calculateVolumeForImpulse(_ _impulse: Float) -> Float {
        // Simple mapping of impulse to volume
        
        let volMinDB: Float = -20.0
        let impulseMax: Float = 12.0
        
        var impulse = _impulse
        if impulse > impulseMax { impulse = impulseMax }
        let volDB = (impulse / impulseMax * -volMinDB) + volMinDB
        return powf(10, (volDB / 20))
    }
    
    private func calculatePlaybackRateForImpulse(_ _impulse: Float) -> Float {
        // Simple mapping of impulse to playback rate (pitch)
        // This gives the effect of the pitch dropping as the impulse reduces
        
        let rateMax: Float = 1.2
        let rateMin: Float = 0.95
        let rateRange: Float = rateMax - rateMin
        let impulseMax: Float = 12.0
        let impulseMin: Float = 0.6
        let impulseRange: Float = impulseMax - impulseMin
        
        var impulse = _impulse
        if impulse > impulseMax  { impulse = impulseMax }
        if impulse < impulseMin  { impulse = impulseMin }
        
        return (((impulse - impulseMin) / impulseRange) * rateRange) + rateMin
    }
    
    func updateListenerPosition(_ position: AVAudio3DPoint) {
        _environment.listenerPosition = position;
    }
    
    var listenerPosition: AVAudio3DPoint {
        return _environment.listenerPosition;
    }
    
    func updateListenerOrientation(_ orientation: AVAudio3DAngularOrientation) {
        _environment.listenerAngularOrientation = orientation
    }
    
    var listenerAngularOrientation: AVAudio3DAngularOrientation {
        return _environment.listenerAngularOrientation;
    }
    
    //MARK: AVAudioSession
    
    #if os(iOS) || os(tvOS)
    private func initAVAudioSession() {
        
        // Configure the audio session
        let sessionInstance = AVAudioSession.sharedInstance()
        
        // set the session category
        do {
            try sessionInstance.setCategory(AVAudioSessionCategoryPlayback)
        } catch let error as NSError {
            NSLog("Error setting AVAudioSession category! \(error.localizedDescription)\n")
        }
        
        let desiredNumChannels = 8 // for 7.1 rendering
        let maxChannels = sessionInstance.maximumOutputNumberOfChannels
        if maxChannels >= desiredNumChannels {
            do {
                try sessionInstance.setPreferredOutputNumberOfChannels(desiredNumChannels)
            } catch let error as NSError {
                NSLog("Error setting PreferredOuputNumberOfChannels! \(error.localizedDescription)")
            }
        }
        
        
        // add interruption handler
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: Notification.Name.AVAudioSessionInterruption,
            object: sessionInstance)
        
        // we don't do anything special in the route change notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: Notification.Name.AVAudioSessionRouteChange,
            object: sessionInstance)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset),
            name: NSNotification.Name.AVAudioSessionMediaServicesWereReset,
            object: sessionInstance)
        
        // activate the audio session
        do {
            try sessionInstance.setActive(true)
        } catch let error as NSError {
            NSLog("Error setting session active! \(error.localizedDescription)\n")
        }
    }
    
    @objc private func handleInterruption(_ notification: NSNotification) {
        let theInterruptionType = notification.userInfo![AVAudioSessionInterruptionTypeKey].flatMap {
            AVAudioSessionInterruptionType(rawValue: $0 as! UInt)
        }
        
        NSLog("Session interrupted > --- %s ---\n", theInterruptionType == AVAudioSessionInterruptionType.began ? "Begin Interruption" : "End Interruption")
        
        if theInterruptionType == AVAudioSessionInterruptionType.began {
            _isSessionInterrupted = true
            
            //stop the playback of the nodes
            for collisionPlayer in _collisionPlayerArray {
                collisionPlayer.stop()
            }
            
            self.delegate?.engineWasInterrupted?()
            
        }
        if theInterruptionType == AVAudioSessionInterruptionType.ended {
            // make sure to activate the session
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                _isSessionInterrupted = false
                if _isConfigChangePending {
                    //there is a pending config changed notification
                    NSLog("Responding to earlier engine config changed notification. Re-wiring connections and starting once again");
                    self.makeEngineConnections()
                    self.startEngine()
                    
                    _isConfigChangePending = false
                } else {
                    // start the engine once again
                    self.startEngine()
                }
            } catch let error as NSError {
                NSLog("AVAudioSession set active failed with error: %@", error.localizedDescription)
            }
        }
    }
    
    @objc private func handleRouteChange(_ notification: NSNotification) {
        let reasonValue = notification.userInfo![AVAudioSessionRouteChangeReasonKey].flatMap {
            AVAudioSessionRouteChangeReason(rawValue: $0 as! UInt)
        }
        let routeDescription = notification.userInfo![AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
        
        NSLog("Route change:")
        switch (reasonValue) {
        case AVAudioSessionRouteChangeReason.newDeviceAvailable?:
            NSLog("     NewDeviceAvailable")
        case AVAudioSessionRouteChangeReason.oldDeviceUnavailable?:
            NSLog("     OldDeviceUnavailable")
        case AVAudioSessionRouteChangeReason.categoryChange?:
            NSLog("     CategoryChange")
            NSLog("     New Category: %@", AVAudioSession.sharedInstance().category)
        case AVAudioSessionRouteChangeReason.override?:
            NSLog("     Override")
        case AVAudioSessionRouteChangeReason.wakeFromSleep?:
            NSLog("     WakeFromSleep")
        case AVAudioSessionRouteChangeReason.noSuitableRouteForCategory?:
            NSLog("     NoSuitableRouteForCategory")
        default:
            NSLog("     ReasonUnknown")
        }
        
        NSLog("Previous route:\n")
        NSLog("\(routeDescription)")
    }
    
    @objc private func handleMediaServicesReset(_ notification: NSNotification) {
        // if we've received this notification, the media server has been reset
        // re-wire all the connections and start the engine
        NSLog("Media services have been reset!");
        NSLog("Re-wiring connections and starting once again");
        
        self.initAVAudioSession()
        self.createEngineAndAttachNodes()
        self.makeEngineConnections()
        self.startEngine()
        
        //notify the delegate
        self.delegate?.engineConfigurationHasChanged?()
    }
    
    private func createEngineAndAttachNodes() {
        _engine = AVAudioEngine()
        
        _engine.attach(_environment)
        _engine.attach(_launchSoundPlayer)
        
        for collisionPlayer in _collisionPlayerArray {
            _engine.attach(collisionPlayer)
        }
        
    }
    
    #endif
    
    
}
