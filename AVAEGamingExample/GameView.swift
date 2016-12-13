//
//  GameView.swift
//  AVAEGamingExample
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/20.
//
/*
    Copyright (C) 2015 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information

    Abstract:
    GameView
*/

import SceneKit
import AVFoundation

@objc(GameView)
class GameView: SCNView {
    
    var gameAudioEngine: AudioEngine!
    
    var previousTouch: CGPoint = CGPoint()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        #if os(iOS) || os(tvOS)
            self.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panGesture)))
        #endif
    }
    
    func degreesFromRad<F: BinaryFloatingPoint>(_ rad: F) -> F {
        return (rad/F(M_PI)) * 180
    }
    
    func radFromDegrees<F: BinaryFloatingPoint>(_ degree: F) -> F {
        return (degree/180) * F(M_PI)
    }
    
    private func updateEulerAnglesAndListener(fromDeltaX dx: CGFloat, deltaY dy: CGFloat) {
        //estimate the position deltas as the angular change and convert it to radians for scene kit
        let dYaw = self.radFromDegrees(SCNVectorFloat(dx))
        let dPitch = self.radFromDegrees(SCNVectorFloat(dy))
        
        //scale the feedback to make the transitions smooth and natural
        let scalar: SCNVectorFloat = 0.1
        
        self.pointOfView?.eulerAngles = SCNVector3Make(self.pointOfView!.eulerAngles.x+dPitch*scalar,
                                                       self.pointOfView!.eulerAngles.y+dYaw*scalar,
                                                       self.pointOfView!.eulerAngles.z)
        
        
        let listener = self.scene!.rootNode.childNode(withName: "listenerLight", recursively: true)
        listener?.eulerAngles = SCNVector3Make(self.pointOfView!.eulerAngles.x,
                                               self.pointOfView!.eulerAngles.y,
                                               self.pointOfView!.eulerAngles.z)
        
        
        //convert the scene kit angular orientation (radians) to degrees for AVAudioEngine and match the orientation
        self.gameAudioEngine
            .updateListenerOrientation(AVAudioMake3DAngularOrientation(Float(self.degreesFromRad(-1*self.pointOfView!.eulerAngles.y)),
                                                                       Float(self.degreesFromRad(-1*self.pointOfView!.eulerAngles.x)),
                                                                       Float(self.degreesFromRad(self.pointOfView!.eulerAngles.z))))
    }
    
    #if os(iOS) || os(tvOS)
    
    @objc private func panGesture(_ panRecognizer: UIPanGestureRecognizer) {
        //capture the first touch
        if panRecognizer.state == .began {
            self.previousTouch = panRecognizer.location(in: self)
        }
        
        let currentTouch = panRecognizer.location(in: self)
        
        //Calculate the change in position
        let dX = currentTouch.x-self.previousTouch.x
        let dY = currentTouch.y-self.self.previousTouch.y
        
        self.previousTouch = currentTouch
        
        self.updateEulerAnglesAndListener(fromDeltaX: dX, deltaY: dY)
    }
    
    #else
    override func mouseDown(with theEvent: NSEvent) {
        /* Called when a mouse click occurs */
        super.mouseDown(with: theEvent)
    }
    
    override func mouseDragged(with theEvent: NSEvent) {
        /* Called when a mouse dragged occurs */
        super.mouseDragged(with: theEvent)
        
        self.updateEulerAnglesAndListener(fromDeltaX: theEvent.deltaX, deltaY: theEvent.deltaY)
        
    }
    
    override func magnify(with event: NSEvent) {
        //implement this method to zoom in and out
        //super.magnify(with: event)
    }
    
    override func rotate(with event: NSEvent) {
        //implement this to have to listener roll along the perpendicular axis to the screen plane
        //super.rotate(with: event)
    }
    
    #endif //os(iOS) || os(TvOS)
    
    
}
