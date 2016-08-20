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

@objc(GameViewController)
class GameViewController: NSViewController, SCNPhysicsContactDelegate {
    
    @IBOutlet weak var gameView: GameView!
    
    var _audioEngine: AudioEngine!
    
    func randFloat(_ min: CGFloat, _ max: CGFloat) -> CGFloat {
        return min + ((max-min)*(CGFloat(arc4random())/CGFloat(RAND_MAX)))
    }
    
    let BallCategoryBit = Int(SCNPhysicsCollisionCategory.default.rawValue)
    let WallCategoryBit = Int(SCNPhysicsCollisionCategory.static.rawValue)
    
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        if contact.collisionImpulse > 0.6 { // arbitrary threshold
            
            let contactPoint = AVAudioMake3DPoint(Float(contact.contactPoint.x), Float(contact.contactPoint.y), Float(contact.contactPoint.z))
            let ballNode: SCNNode
            
            // Check which contact node is the ball
            // There is no guaranty regarding the ordering in the contact pair so check both
            if contact.nodeA.name == "Wall" {
                //NSLog(@"ballNode = contact.nodeB");
                ballNode = contact.nodeB
            } else {
                //NSLog(@"ballNode = contact.nodeA");
                ballNode = contact.nodeA
            }
            
            _audioEngine.playCollisionSoundForSCNNode(ballNode, position: contactPoint, impulse: Float(contact.collisionImpulse))
        }
    }
    
    func setupPhysicsScene(_ scene: SCNScene) {
        let node = scene.rootNode.childNode(withName: "Cube", recursively: true)!
        node.castsShadow = false
        
        let lightNode = scene.rootNode.childNode(withName: "MainLight", recursively: true)!
        lightNode.light!.shadowMode = SCNShadowMode.modulated
        
        let (min, max) = node.boundingBox
        
        let cubeSize: CGFloat = (max.y-min.y) * node.scale.y
        let wallWidth: CGFloat = 1
        let wallGeometry = SCNBox(width: cubeSize, height: cubeSize, length: wallWidth, chamferRadius: 0)
        wallGeometry.firstMaterial!.transparency = 0
        
        let wallPosition = (cubeSize/2 + wallWidth/2)
        
        let wall1 = SCNNode()
        wall1.name = "Wall"
        wall1.geometry = wallGeometry
        wall1.physicsBody = SCNPhysicsBody.static()
        wall1.position = SCNVector3Make(0, 0, -wallPosition)
        if #available(OSX 10.11, *) {
            wall1.physicsBody?.contactTestBitMask = BallCategoryBit
        }
        scene.rootNode.addChildNode(wall1)
        
        let wall2 = wall1.copy() as! SCNNode
        wall2.position = SCNVector3Make(0, 0, wallPosition)
        wall2.eulerAngles = SCNVector3Make(CGFloat(M_PI), 0, 0)
        scene.rootNode.addChildNode(wall2)
        
        let wall3 = wall1.copy() as! SCNNode
        wall3.position = SCNVector3Make(-wallPosition, 0, 0)
        wall3.eulerAngles = SCNVector3Make(0, CGFloat(M_PI_2), 0)
        scene.rootNode.addChildNode(wall3)
        
        let wall4 = wall1.copy() as! SCNNode
        wall4.position = SCNVector3Make(wallPosition, 0, 0)
        wall4.eulerAngles = SCNVector3Make(0, CGFloat(-M_PI_2), 0)
        scene.rootNode.addChildNode(wall4)
        
        let wall5 = wall1.copy() as! SCNNode
        wall5.position = SCNVector3Make(0, wallPosition, 0)
        wall5.eulerAngles = SCNVector3Make(CGFloat(M_PI_2), 0, 0)
        scene.rootNode.addChildNode(wall5)
        
        let wall6 = wall1.copy() as! SCNNode
        wall6.position = SCNVector3Make(0, -wallPosition, 0)
        wall6.eulerAngles = SCNVector3Make(CGFloat(-M_PI_2), 0, 0)
        scene.rootNode.addChildNode(wall6)
        
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
        ball.physicsBody!.restitution = 1.2 // bounce!
        if #available(OSX 10.11, *) {
            ball.physicsBody?.contactTestBitMask = BallCategoryBit | WallCategoryBit
        }
        
        // create an AVAudioEngine player which will be tied to this ball
        _audioEngine.createPlayerForSCNNode(ball)
        
        self.gameView.scene!.rootNode.addChildNode(ball)
        
        // bias the direction towards one of the side walls
        let whichWall = round(randFloat(0, 1));  // 0 is left and 1 is right
        let xVal = (1 - whichWall) * randFloat(-8, -3) + whichWall * randFloat(3, 8)
        
        // initial force
        ball.physicsBody!.applyForce(SCNVector3Make(xVal, randFloat(0,5), -randFloat(5,15)), at: SCNVector3Zero, asImpulse: true)
        ball.physicsBody!.applyTorque(SCNVector4Make(randFloat(-1,1), randFloat(-1,1), randFloat(-1,1), randFloat(-1,1)), asImpulse: true)
        
        SCNTransaction.commit()
    }
    
    // removeBall is never called but included for completeness
    func removeBall(_ ball: SCNNode) {
        _audioEngine.destroyPlayerForSCNNode(ball)
        ball.removeFromParentNode()
    }
    
    override func awakeFromNib() {
        // create a new scene
        let options: [SCNSceneSource.LoadingOption : Any]? = nil //###Needed to build with Xcode 8 beta 6
        let scene = SCNScene(named: "cube.dae", inDirectory: "assets.scnassets", options: options)!
        
        // set the scene to the view
        self.gameView.scene = scene
        
        // setup the room
        self.setupPhysicsScene(scene)
        
        // setup audio engine
        _audioEngine = AudioEngine()
        
        // create a queue that will handle adding SceneKit nodes (balls) and corresponding AVAudioEngine players
        let queue = DispatchQueue(label: "DemBalls", attributes: []/*DispatchQueue.Attributes.serial*/)
        queue.async {
            while true {
                var ballIndex = 0
                
                // play the launch sound
                self._audioEngine.playLaunchSound {
                    
                    // launch sound has finished scheduling
                    // now create and launch a ball
                    let ballID = String(ballIndex)
                    self.createAndLaunchBall(ballID)
                    ballIndex += 1
                }
                
                // wait for some time before launching the next ball
                sleep(4)
            }
        }
        
        // configure the view
        self.gameView.backgroundColor = NSColor.black
    }
    
}
