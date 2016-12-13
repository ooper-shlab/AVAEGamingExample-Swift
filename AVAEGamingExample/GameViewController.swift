//
//  GameViewController.swift
//  AVAEGamingExample
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/20.
//
/*
    Copyright (C) 2015 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information

    Abstract:
    GameViewController
*/

import Foundation
import AVFoundation
import SceneKit

#if os(iOS) || os(tvOS)
    typealias OSViewController = UIViewController
    typealias SCNVectorFloat = Float
    typealias OSColor = UIColor
#else
    typealias OSViewController = NSViewController
    typealias SCNVectorFloat = CGFloat
    typealias OSColor = NSColor
#endif
@objc(GameViewController)
class GameViewController: OSViewController, SCNPhysicsContactDelegate, AudioEngineDelegate {
    
    var _audioEngine: AudioEngine!
    
    private var gameView: GameView!
    
    func randFloat<F: FloatingPoint>(_ min: F, _ max: F) -> F {
        return min + ((max-min)*(F(arc4random())/F(RAND_MAX)))
    }
    
    let BallCategoryBit = Int(SCNPhysicsCollisionCategory.default.rawValue)
    let WallCategoryBit = Int(SCNPhysicsCollisionCategory.static.rawValue)
    
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        if contact.collisionImpulse > 0.6 /* arbitrary threshold */ {
            
            let contactPoint = AVAudioMake3DPoint(Float(contact.contactPoint.x), Float(contact.contactPoint.y), Float(contact.contactPoint.z))
            _audioEngine.playCollisionSoundForSCNNode(contact.nodeB, position: contactPoint, impulse: Float(contact.collisionImpulse))
        }
    }
    
    func setupPhysicsScene(_ scene: SCNScene) {
        let cube = scene.rootNode.childNode(withName: "Cube", recursively: true)!
        cube.castsShadow = false
        
        let lightNode = scene.rootNode.childNode(withName: "MainLight", recursively: true)!
        lightNode.light!.shadowMode = SCNShadowMode.modulated
        
        let (min, max) = cube.boundingBox
        
        let cubeSize: SCNVectorFloat = (max.y-min.y) * cube.scale.y
        let wallWidth: SCNVectorFloat = 1
        let wallGeometry = SCNBox(width: CGFloat(cubeSize), height: CGFloat(cubeSize), length: CGFloat(wallWidth), chamferRadius: 0)
        wallGeometry.firstMaterial!.transparency = 0
        
        let wallPosition = (cubeSize/2 + wallWidth/2)
        
        let wall1 = SCNNode()
        wall1.name = "Wall"
        wall1.geometry = wallGeometry
        wall1.physicsBody = SCNPhysicsBody.static()
        if #available(OSX 10.11, iOS 9.0, *) {
            wall1.physicsBody?.contactTestBitMask = Int(SCNPhysicsCollisionCategory.default.rawValue)
        }
        wall1.position = SCNVector3Make(0, 0, -wallPosition)
        scene.rootNode.addChildNode(wall1)
        
        let wall2 = wall1.copy() as! SCNNode
        wall2.position = SCNVector3Make(0, 0, wallPosition)
        wall2.eulerAngles = SCNVector3Make(SCNVectorFloat(M_PI), 0, 0)
        scene.rootNode.addChildNode(wall2)
        
        let wall3 = wall1.copy() as! SCNNode
        wall3.position = SCNVector3Make(-wallPosition, 0, 0)
        wall3.eulerAngles = SCNVector3Make(0, SCNVectorFloat(M_PI_2), 0)
        scene.rootNode.addChildNode(wall3)
        
        let wall4 = wall1.copy() as! SCNNode
        wall4.position = SCNVector3Make(wallPosition, 0, 0)
        wall4.eulerAngles = SCNVector3Make(0, SCNVectorFloat(-M_PI_2), 0)
        scene.rootNode.addChildNode(wall4)
        
        let wall5 = wall1.copy() as! SCNNode
        wall5.position = SCNVector3Make(0, wallPosition, 0)
        wall5.eulerAngles = SCNVector3Make(SCNVectorFloat(M_PI_2), 0, 0)
        scene.rootNode.addChildNode(wall5)
        
        let wall6 = wall1.copy() as! SCNNode
        wall6.position = SCNVector3Make(0, -wallPosition, 0)
        wall6.eulerAngles = SCNVector3Make(SCNVectorFloat(-M_PI_2), 0, 0)
        scene.rootNode.addChildNode(wall6)
        
        let pointOfViewCamera = scene.rootNode.childNode(withName: "Camera", recursively: true)!
        self.gameView.pointOfView = pointOfViewCamera
        
        let listener = scene.rootNode.childNode(withName: "listenerLight", recursively: true)!
        listener.position = pointOfViewCamera.position
        
        // setup physics callbacks
        scene.physicsWorld.contactDelegate = self
        
        // turn off gravity for more fun
        //        scene.physicsWorld.gravity = SCNVector3Zero
    }
    
    private func createAndLaunchBall(_ ballID: String) {
        SCNTransaction.begin()
        
        let ball = SCNNode()
        ball.name = ballID
        ball.geometry = SCNSphere(radius: 0.2)
        ball.geometry!.firstMaterial!.diffuse.contents = "assets.scnassets/texture.jpg"
        ball.geometry!.firstMaterial!.reflective.contents = "assets.scnassets/envmap.jpg"
        
        ball.position = SCNVector3Make(0, -2, 2.5)
        
        ball.physicsBody = SCNPhysicsBody.dynamic()
        ball.physicsBody!.restitution = 1.2 //bounce!
        if #available(OSX 10.11, *) {
            ball.physicsBody?.contactTestBitMask = BallCategoryBit | WallCategoryBit
        }
        
        // create an AVAudioEngine player which will be tied to this ball
        _audioEngine.createPlayerForSCNNode(ball)
        
        self.gameView.scene!.rootNode.addChildNode(ball)
        
        // bias the direction towards one of the side walls
        let whichWall = round(randFloat(0 as SCNVectorFloat, 1));  // 0 is left and 1 is right
        let xVal = (1 - whichWall) * randFloat(-8, -3) + whichWall * randFloat(3, 8)
        
        // initial force
        ball.physicsBody!.applyForce(SCNVector3Make(xVal, randFloat(0,5), -randFloat(5,15)), at: SCNVector3Zero, asImpulse: true)
        ball.physicsBody!.applyTorque(SCNVector4Make(randFloat(-1,1), randFloat(-1,1), randFloat(-1,1), randFloat(-1,1)), asImpulse: true)
        
        SCNTransaction.commit()
    }
    
    func removeBall(_ ball: SCNNode) {
        _audioEngine.destroyPlayerForSCNNode(ball)
        ball.removeFromParentNode()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create a new scene
        let options: [SCNSceneSource.LoadingOption : Any]? = nil //###Needed to build with Xcode 8 beta 6
        let scene = SCNScene(named: "cube.scn", inDirectory: "assets.scnassets", options: options)!
        
        // find the SCNView
        for view in self.view.subviews {
            if let view = view as? GameView {
                self.gameView = view
            }
        }
        
        // set the scene to the view
        self.gameView.scene = scene
        
        // setup the room
        self.setupPhysicsScene(scene)
        
        // setup audio engine
        _audioEngine = AudioEngine()
        
        //make the listener position the same as the camera point of view
        _audioEngine.updateListenerPosition(AVAudioMake3DPoint(0, -2, 2.5))
        
        self.gameView.gameAudioEngine = _audioEngine;
        
        // create a queue that will handle adding SceneKit nodes (balls) and corresponding AVAudioEngine players
        let queue = DispatchQueue(label: "DemBalls", attributes: []/*DispatchQueue.Attributes.serial*/)
        queue.async {
            while true {
                struct Static {
                    static var ballIndex = 0
                }
                while self._audioEngine.isRunning {
                    
                    // play the launch sound
                    self._audioEngine.playLaunchSoundAtPosition(AVAudioMake3DPoint(0, -2, 2.5)) {
                        
                        // launch sound has finished scheduling
                        // now create and launch a ball
                        let ballID = String(Static.ballIndex)
                        self.createAndLaunchBall(ballID)
                        Static.ballIndex += 1
                    }
                    
                    // wait for some time before launching the next ball
                    sleep(4);
                }
            }
        }
        
        // configure the view
        self.gameView.backgroundColor = .black
    }
    
}
