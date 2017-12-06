//
//  ViewController.swift
//  GraphNodeView(iOS)
//
//  Created by Arthur MASSON on 12/1/17.
//  Copyright © 2017 Arthur Masson. All rights reserved.
//

import UIKit
import SceneKit

extension UIColor {
    static func randomColor() -> UIColor {
        let red: CGFloat = arc4random() % 2 == 0 ? 0.8 : 0.2
        let green: CGFloat = arc4random() % 2 == 0 ? 0.8 : 0.2
        let blue: CGFloat = arc4random() % 2 == 0 ? 0.8 : 0.2
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

class ViewController: UIViewController {

    @IBOutlet weak var graphNodeView: GraphNodeView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func setFlatGraph(_ sender: UISwitch) {
        self.graphNodeView.flatGraph = sender.isOn
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
        let color: UIColor
        switch name {
        case "Alpha":
            color = UIColor.red
        case "Bravo":
            color = UIColor.green
        case "Charlie":
            color = UIColor.blue
        case "Delta":
            color = UIColor.yellow
        default:
            color = UIColor.randomColor()
        }
        geometry.materials.first?.diffuse.contents = color
        let node = SCNNode(geometry: geometry)
        
        let textGeo = SCNText(string: name, extrusionDepth: 1.0)
        
        textGeo.materials.first?.diffuse.contents = color
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
            property.color = UIColor.randomColor()
        }
        return property
    }
}

extension ViewController: GraphNodeViewDelegate {
    func graphNodeView(_ graphNodeView: GraphNodeView, selectedNodeNamed name: String) {
        print("touched node named:", name)
        self.graphNodeView.reloadNode(named: name)
    }
}
