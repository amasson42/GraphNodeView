//
//  ViewController.swift
//  GraphNodeView
//
//  Created by Arthur Masson on 01/12/2017.
//  Copyright © 2017 Arthur Masson. All rights reserved.
//

import Cocoa
import SceneKit

class ViewController: NSViewController {
    
    @IBOutlet weak var graphNodeView: GraphNodeView!
    @IBOutlet weak var senderField: NSTextField!
    @IBOutlet weak var targetField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func sendVisualSignal(_ sender: Any) {
        let node = SCNNode()
        
        let imageRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        #if os(macOS)
            let image = NSImage(size: imageRect.size)
            image.lockFocus()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: imageRect).fill()
            image.unlockFocus()
        #else
            UIGraphicsBeginImageContextWithOptions(imageRect.size, false, 1.0)
            UIColor.white.setFill()
            UIBezierPath(ovalIn: imageRect).fill()
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        #endif
        
        let emitter = SCNParticleSystem()
        emitter.particleColor = .blue
        emitter.particleImage = image
        emitter.emitterShape = SCNSphere(radius: 0.2)
        emitter.birthRate = 200
        emitter.birthLocation = .surface
        emitter.birthDirection = .surfaceNormal
        emitter.spreadingAngle = 0
        emitter.particleAngle = 0
        emitter.particleAngleVariation = 0
        emitter.particleLifeSpan = 2.5
        emitter.particleLifeSpanVariation = 0.5
        emitter.particleVelocity = 0.1
        emitter.particleVelocityVariation = 0.1
        emitter.speedFactor = 1
        emitter.particleSize = 0.05
        emitter.particleSizeVariation = 0
        
        node.addParticleSystem(emitter)
        self.graphNodeView.sendVisualSignal(withModel: node, fromNodeNamed: self.senderField.stringValue, toNodeNamed: self.targetField.stringValue)
    }
    
    @IBAction func setFlatGraph(_ sender: NSButton) {
        graphNodeView.flatGraph = sender.state == .on
    }
    
    @IBAction func setDataSource(_ sender: Any) {
        graphNodeView.dataSource = self
        graphNodeView.delegate = self
    }
}

extension ViewController: GraphNodeViewDataSource {
    
    func graphNodeView(_ graphNodeView: GraphNodeView, linksForNodeNamed name: String) -> Set<String> {
        switch name {
        case "Alpha":
            return ["Bravo"]
        case "Bravo":
            return ["Charlie"]
        case "Charlie":
            return []
        case "Delta":
            return ["Alpha", "Bravo", "Charlie"]
        default:
            return ["Delta"]
        }
    }
    
    func namesOfAllNodes(in graphNodeView: GraphNodeView) -> Set<String> {
        return ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf"]
    }
    
    func graphNodeView(_ graphNodeView: GraphNodeView, modelForNodeNamed name: String) -> SCNNode {
        let geometry = SCNBox(width: 1.0, height: 1.0, length: 0.2, chamferRadius: 0.1)
        let color: NSColor
        switch name {
        case "Alpha":
            color = NSColor.red
        case "Bravo":
            color = NSColor.green
        case "Charlie":
            color = NSColor.blue
        case "Delta":
            color = NSColor.yellow
        default:
            color = NSColor.randomColor()
        }
        geometry.materials.first?.diffuse.contents = color
        let node = SCNNode(geometry: geometry)
        
        let textGeo = SCNText(string: name, extrusionDepth: 1.0)
        textGeo.materials.first?.diffuse.contents = color.blended(withFraction: 0.6, of: .black)
        let textNode = SCNNode(geometry: textGeo)
        let scaling = SCNFloat(0.5 / textNode.boundingSphere.radius)
        textNode.scale = SCNVector3(x: scaling, y: scaling, z: scaling)
        textNode.position = SCNVector3(x: -0.5, y: -0.5, z: 0.1)
        node.addChildNode(textNode)
        
        return node
    }
    
    func graphNodeView(_ graphNodeView: GraphNodeView,
                       linkPropertyForLinkFromNodeNamed nodeSrc: String,
                       toNodeNamed nodeDst: String) -> GraphNodeView.LinkProperty? {
        var property = GraphNodeView.LinkProperty()
        property.arrowShaped = true
        property.lineShape = .square
        switch nodeDst {
        case "Alpha":
            property.color = .red
        case "Bravo":
            property.color = .green
        case "Charlie":
            property.color = .blue
        case "Delta":
            property.color = .yellow
        default:
            property.color = NSColor.randomColor()
        }
        return property
    }
}

extension ViewController: GraphNodeViewDelegate {
    func graphNodeView(_ graphNodeView: GraphNodeView, selectedNodeNamed name: String) {
        print("touched node named:", name)
    }
}
