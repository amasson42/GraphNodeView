//
//  GraphNodeView.swift
//  GraphNodeView
//
//  Created by Arthur Masson on 01/12/2017.
//  Copyright © 2017 Arthur Masson. All rights reserved.
//

import SceneKit
import GameplayKit

#if os(macOS)
	typealias CPView = NSView
	typealias CPColor = NSColor
	let AutoResizingMaskFlexibleWidthAndHeight: NSView.AutoresizingMask = [.width, .height]
#else
	typealias CPView = UIView
	typealias CPColor = UIColor
	let AutoResizingMaskFlexibleWidthAndHeight: UIViewAutoresizing = [.flexibleWidth, .flexibleHeight]
#endif

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
	
	func graphNodeView(_ graphNodeView: GraphNodeView,
					   linkPropertyForLinkFromNode nodeSrc: String,
					   to nodeDst: String) -> GraphNodeView.LinkProperty? {
		return nil
	}
}

protocol GraphNodeViewDelegate: class {
	
}

class GraphNodeView: CPView {
	
	weak var dataSource: GraphNodeViewDataSource? {
		didSet {
			self.reloadData()
		}
	}
	
	weak var delegate: GraphNodeViewDelegate?
	
	// MARK: dataSource informations
	private var nodeNames: [String] = []
	private var nodeModels: [String: SCNNode] = [:]
	private var linksNames: [String: [String]] = [:]
	
	// MARK: Scene uses
	private var lastUpdateTime: TimeInterval?
	private var sceneView: SCNView!
	private var scene: SCNScene!
	private var nodesNode: SCNNode!
	private var linksNode: SCNNode!
	
	struct LinkProperty {
		enum LineShape {
			case round
			case square
			case wire
		}
		var lineShape: LineShape = .round
		var lineWidth: Float = 0.1
		var color: CPColor = .white
		var arrowShaped: Bool = false
		var startingDistance: Float = 0.0
		var endingDistance: Float = 1.0
	}
	/**
	link for node \"nda\" to node \"ndb\" is named \"nda-ndb\"
	*/
	private var linksProperty: [String: LinkProperty] = [:]
	
	private var agents: [String: GKAgent] = [:]
	
	struct Settings {
		var canEscapeFrom2DPlan: Bool
	}
	
	public var settings = Settings(canEscapeFrom2DPlan: true)
	
	// MARK: Initialisation
	override init(frame frameRect: CGRect) {
		super.init(frame: frameRect)
		self.initView()
	}
	
	required init?(coder decoder: NSCoder) {
		super.init(coder: decoder)
		self.initView()
	}
	
	private func initView() {
		
		let sceneView = SCNView(frame: CGRect(origin: .zero, size: self.frame.size))
		self.addSubview(sceneView)
		sceneView.autoresizingMask = AutoResizingMaskFlexibleWidthAndHeight
		self.sceneView = sceneView
		self.sceneView.delegate = self
		self.sceneView.isPlaying = true
		
		self.initContent()
	}
	
}

// MARK: Content using
extension GraphNodeView {
	
	private func initContent() {
		self.initScene()
		self.initAgents()
	}
	
	private func clearContent() {
		self.nodeNames = []
		self.nodeModels = [:]
		self.linksNames = [:]
		self.clearScene()
		self.clearAgents()
	}
	
	private func createContent() {
		self.createScene()
		self.createAgents()
	}
}

// MARK: All of GameplayKit
extension GraphNodeView {
	
	private func initAgents() {
		self.agents = [:]
	}
	
	private func clearAgents() {
		self.agents.removeAll()
	}
	
	private func createAgents() {
		let originAgent = GKAgent()
		var agents: [GKAgent] = []
		var pos: Float = 0.0
		for nodeName in nodeNames {
			let agent = settings.canEscapeFrom2DPlan ? GKAgent3D() : GKAgent2D()
			(agent as! GKAgent3D).position.x = pos
			pos += 1.0
			self.agents[nodeName] = agent
			agents.append(agent)
		}
		
		let separateGoal = GKGoal(toSeparateFrom: agents, maxDistance: 5, maxAngle: 0)
		let idleGoal = GKGoal(toReachTargetSpeed: 0)
		let compactingGoal = GKGoal(toSeekAgent: originAgent)
		let behavior = GKBehavior(weightedGoals: [
			separateGoal: 1.6,
			idleGoal: 1.0,
			compactingGoal: 0.1,
			])
		// TODO: seek linked agents
		for agent in agents {
			agent.behavior = behavior
			agent.radius = 0.5
		}
	}
	
	private func agentsUpdatePositions(withDeltaTime deltaTime: TimeInterval) {
		for (_, agent) in self.agents {
			agent.update(deltaTime: deltaTime)
		}
	}
}

// MARK: All of Scene
extension GraphNodeView {
	
	private func initScene() {
		
		scene = SCNScene()
		scene.background.contents = CPColor.black
		
		nodesNode = SCNNode()
		scene.rootNode.addChildNode(nodesNode)
		
		linksNode = SCNNode()
		scene.rootNode.addChildNode(linksNode)
		
		sceneView.scene = scene
		sceneView.allowsCameraControl = true
		sceneView.autoenablesDefaultLighting = true
		sceneView.showsStatistics = true
		
		let camera = SCNNode()
		camera.camera = SCNCamera()
		camera.position.z = 5
		scene.rootNode.addChildNode(camera)
		sceneView.pointOfView = camera
	}
	
	private func clearScene() {
		nodesNode.childNodes.forEach {$0.removeFromParentNode()}
		linksNode.childNodes.forEach {$0.removeFromParentNode()}
	}
	
	private func createScene() {
		for nodeName in self.nodeNames {
			if let node = self.nodeModels[nodeName] {
				self.sceneAdd(node: node, forName: nodeName)
			}
		}
	}
	
	private func sceneUpdatePositions() {
		for nodeName in nodeNames {
			self.sceneUpdatePosition(ofNodeNamed: nodeName)
		}
	}
	
	private func sceneAdd(node: SCNNode, forName name: String) {
		node.name = name
		nodesNode.addChildNode(node)
	}
	
	private func sceneAdd(linkFrom nameSrc: String, to nameDst: String) {
		
		let linkNode = SCNNode()
		linkNode.name = nameSrc + "-" + nameDst
		
		// loading property
		let property: LinkProperty
		if let customProperty = self.linksProperty[nameSrc + "-" + nameDst] {
			property = customProperty
		} else {
			property = LinkProperty()
		}
		
		// creating line geometry
		let lineGeometry: SCNGeometry
		switch property.lineShape {
		case .round:
			lineGeometry = SCNCylinder(radius: CGFloat(property.lineWidth),
									   height: 1.0)
		case .square:
			lineGeometry = SCNBox(width: CGFloat(property.lineWidth),
								  height: 1.0,
								  length: CGFloat(property.lineWidth),
								  chamferRadius: 0)
		case .wire:
			// FIXME: Create custom line geometry like in arkit tutorial
			lineGeometry = SCNCylinder(radius: CGFloat(property.lineWidth), height: 1.0)
		}
		lineGeometry.materials.first?.diffuse.contents = property.color
		
		// creating line node
		let lineNode = SCNNode(geometry: lineGeometry)
		lineNode.scale.y = SCNFloat(property.endingDistance - property.startingDistance)
		lineNode.position.y = SCNFloat(property.startingDistance)
		linkNode.addChildNode(lineNode)
		
		// creating arrowhead
		if property.arrowShaped {
			let arrowGeometry: SCNGeometry
			switch property.lineShape {
			case .round:
				arrowGeometry = SCNCone(topRadius: 0,
										bottomRadius: CGFloat(2 * property.lineWidth),
										height: 0.2)
			case .square:
				arrowGeometry = SCNPyramid(width: CGFloat(2 * property.lineWidth),
										   height: 0.2,
										   length: CGFloat(2 * property.lineWidth))
			case .wire:
				arrowGeometry = SCNCone(topRadius: 0,
										bottomRadius: CGFloat(2 * property.lineWidth),
										height: 0.2)
			}
			arrowGeometry.materials.first?.diffuse.contents = property.color
			let arrowNode = SCNNode(geometry: arrowGeometry)
			arrowNode.position.y = SCNFloat(property.endingDistance - 0.2)
			linkNode.addChildNode(arrowNode)
		}
		
		self.linksNode.addChildNode(linkNode)
	}
	
	private func sceneUpdatePosition(ofNodeNamed name: String) {
		guard let node = self.nodesNode.childNode(withName: name, recursively: false),
			let agent = self.agents[name] else {
			return
		}
		if let agent2d = agent as? GKAgent2D {
			node.position = SCNVector3(x: SCNFloat(agent2d.position.x),
									   y: SCNFloat(agent2d.position.y),
									   z: 0)
		} else if let agent3d = agent as? GKAgent3D {
			print(agent3d.position)
			node.position = SCNVector3(x: SCNFloat(agent3d.position.x),
									   y: SCNFloat(agent3d.position.y),
									   z: SCNFloat(agent3d.position.z))
		}
		print(node.position)
	}
}

// MARK: Calls to datasource
extension GraphNodeView {
	
	/**
		Clear and reload every informations from the dataSource
	*/
	public func reloadData() {
		
		self.clearContent()
		
		guard let dataSource = self.dataSource else {
			return
		}
		self.nodeNames = dataSource.namesOfAllNodes(in: self)
		for nodeName in nodeNames {
			let node = dataSource.graphNodeView(self, modelForNodenNamed: nodeName)
			self.nodeModels[nodeName] = node
		}
		for nodeName in nodeNames {
			let links = dataSource.graphNodeView(self, linksForNodeNamed: nodeName)
			self.linksNames[nodeName] = links
			for link in links {
				if let property = dataSource.graphNodeView(self, linkPropertyForLinkFromNode: nodeName, to: link) {
					let linkName = nodeName + "-" + link
					self.linksProperty[linkName] = property
				}
			}
		}
		self.createContent()
	}
	
}

extension GraphNodeView: SCNSceneRendererDelegate {
	
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		let deltaTime: TimeInterval
		if let lastUpdateTime = self.lastUpdateTime {
			deltaTime = time - lastUpdateTime
		} else {
			deltaTime = 0
		}
		self.lastUpdateTime = time
		self.agentsUpdatePositions(withDeltaTime: deltaTime)
		self.sceneUpdatePositions()
	}
}
