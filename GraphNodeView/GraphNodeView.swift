//
//  GraphNodeView.swift
//  GraphNodeView
//
//  Created by Arthur Masson on 01/12/2017.
//  Copyright © 2017 Arthur Masson. All rights reserved.
//

import SceneKit

protocol GraphNodeViewDataSource: class {
    func namesOfAllNodes(in graphNodeView: GraphNodeView) -> [String]
    func graphNodeView(_ graphNodeView: GraphNodeView, linksForNodeNamed name: String) -> [String]
}

extension GraphNodeViewDataSource {
    func graphNodeView(_ graphNodeView: GraphNodeView, modelForNodenNamed name: String) -> SCNNode {
        let geometry = SCNSphere(radius: 0.5)
        let node = SCNNode(geometry: geometry)
        return node
    }
    
    func graphNodeView(_ graphNodeView: GraphNodeView, informationAboutNodeNamed named: String) -> [String: Any] {
        return [:]
    }
}

protocol GraphNodeViewDelegate: class {
    
}

class GraphNodeView: NSView {
    weak var dataSource: GraphNodeViewDataSource?
    weak var delegate: GraphNodeViewDelegate?
    
    private(set) var sceneView: SCNView!
    
    override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        self.createSceneView()
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        self.createSceneView()
    }
    
    private func createSceneView() {
        let sceneView = SCNView(frame: CGRect(origin: .zero, size: self.frame.size))
        self.addSubview(sceneView)
        self.sceneView = sceneView
    }
}
