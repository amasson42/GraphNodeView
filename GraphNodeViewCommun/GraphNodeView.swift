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
	func graphNodeView(_ graphNodeView: GraphNodeView, linksForNodeNamed: String) -> [String]
	func graphNodeView(_ graphNodeView: GraphNodeView, modelForNodeNamed: String) -> SCNNode
	func graphNodeView(_ graphNodeView: GraphNodeView, informationAboutNodeNamed: String) -> [String: Any]
	func graphNodeView(_ graphNodeView: GraphNodeView, linkPropertyForLinkFromNodeNamed: String, toNodeNamed: String) -> GraphNodeView.LinkProperty?
}

extension GraphNodeViewDataSource {
	func graphNodeView(_ graphNodeView: GraphNodeView, modelForNodeNamed name: String) -> SCNNode {
		let geometry = SCNSphere(radius: 0.5)
		let node = SCNNode(geometry: geometry)
		return node
	}
	
	func graphNodeView(_ graphNodeView: GraphNodeView, informationAboutNodeNamed name: String) -> [String: Any] {
		return [:]
	}
	
	func graphNodeView(_ graphNodeView: GraphNodeView,
					   linkPropertyForLinkFromNodeNamed nodeSrc: String,
					   toNodeNamed nodeDst: String) -> GraphNodeView.LinkProperty? {
		return nil
	}
}

protocol GraphNodeViewDelegate: class {
	func graphNodeView(_ graphNodeView: GraphNodeView, selectedNodeNamed name: String)
}

extension GraphNodeViewDelegate {
	func graphNodeView(_ graphNodeView: GraphNodeView, selectedNodeNamed name: String) {
		
	}
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
	
	var flatGraph: Bool = false {
		didSet {
			if oldValue != flatGraph {
				self.createAgents()
			}
		}
	}
	
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
		
		#if os(macOS)
			self.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:))))
		#else
			self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
		#endif
		
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
extension GKAgent {
	var position3d: float3 {
		get {
			if let agent2d = self as? GKAgent2D {
				return float3(agent2d.position.x, agent2d.position.y, 0)
			} else if let agent3d = self as? GKAgent3D {
				return agent3d.position
			} else {
				return float3(0, 0, 0)
			}
		}
		set {
			if let agent2d = self as? GKAgent2D {
				agent2d.position.x = newValue.x
				agent2d.position.y = newValue.y
			} else if let agent3d = self as? GKAgent3D {
				agent3d.position = newValue
			}
		}
	}
}

extension GraphNodeView {
	
	private func initAgents() {
		self.agents = [:]
	}
	
	private func clearAgents() {
		self.agents.removeAll()
	}
	
	private func createNewAgent() -> GKAgent {
		let agent: GKAgent
		if self.flatGraph {
			let agent2d = GKAgent2D()
			agent = agent2d
		} else {
			let agent3d = GKAgent3D()
			agent = agent3d
		}
		agent.radius = 10.0
		return agent
	}
	
	private func createAgents() {
		
		let originAgent = GKAgent()
		
		var newAgents: [GKAgent] = []
		var pos: Float = 0.0
		for nodeName in nodeNames {
			let agent = self.createNewAgent()
			if let previousAgent = self.agents[nodeName] {
				agent.position3d = previousAgent.position3d
			} else {
				agent.position3d = float3(pos, 0, 0)
				pos += 1.0
			}
			self.agents[nodeName] = agent
			newAgents.append(agent)
		}
		
		for (nodeName, agent) in self.agents {
			
			let separateGoal = GKGoal(toSeparateFrom: newAgents, maxDistance: 10, maxAngle: .pi * 2)
			let idleGoal = GKGoal(toReachTargetSpeed: 0)
			let compactingGoal = GKGoal(toSeekAgent: originAgent)
			
			var linksAgentsGoal: [GKGoal] = []
			for link in self.linksNames[nodeName] ?? [] {
				if let linkAgent = self.agents[link] {
					linksAgentsGoal.append(GKGoal(toSeekAgent: linkAgent))
				}
			}
			
			let behavior = GKBehavior(weightedGoals: [
				separateGoal: 10.0,
				idleGoal: 1.0,
				compactingGoal: 2.0,
				])
			for seekGoal in linksAgentsGoal {
				behavior.setWeight(0.4, for: seekGoal)
			}
			agent.behavior = behavior
		}
		
	}
	
	private func agentsUpdatePositions(withDeltaTime deltaTime: TimeInterval) {
		for (_, agent) in self.agents {
			agent.update(deltaTime: deltaTime)
		}
	}
}

// MARK: All of Scene

extension SCNNode {
	
	/**
	Evalutate if the node is recursively a child of the target node.
	If it's the case, it return the direct child of the target containing self.
	If not return nil
	- parameters:
	  - node: target node
	*/
	func isIn(node: SCNNode) -> SCNNode? {
		if let parent = self.parent {
			if parent === node {
				return self
			} else {
				return parent.isIn(node: node)
			}
		} else {
			return nil
		}
	}
}

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
			if let linkNames = self.linksNames[nodeName] {
				for linkName in linkNames {
					self.sceneAdd(linkFrom: nodeName, to: linkName)
				}
			}
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
		let endingDistance = property.endingDistance - (property.arrowShaped ? 0.2 : 0.0)
		lineNode.scale.y = SCNFloat(endingDistance - property.startingDistance)
		lineNode.position.y = SCNFloat((endingDistance - property.startingDistance) / 2
			+ property.startingDistance)
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
			arrowNode.position.y = SCNFloat(endingDistance)
			linkNode.addChildNode(arrowNode)
		}
		
		self.linksNode.addChildNode(linkNode)
	}
	
	private func sceneUpdatePositions() {
		for nodeName in nodeNames {
			self.sceneUpdatePosition(ofNodeNamed: nodeName)
			if let linkNames = self.linksNames[nodeName] {
				for linkName in linkNames {
					self.sceneUpdatePosition(ofLinkFromNodeNamed: nodeName, toNodeNamed: linkName)
				}
			}
		}
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
			node.position = SCNVector3(x: SCNFloat(agent3d.position.x),
									   y: SCNFloat(agent3d.position.y),
									   z: SCNFloat(agent3d.position.z))
		}
	}
	
	private func sceneUpdatePosition(ofLinkFromNodeNamed nameSrc: String, toNodeNamed nameDst: String) {
		guard let nodeSrc = self.nodesNode.childNode(withName: nameSrc, recursively: false),
			let nodeDst = self.nodesNode.childNode(withName: nameDst, recursively: false),
			let nodeLink = self.linksNode.childNode(withName: nameSrc + "-" + nameDst, recursively: false)
			else {
				return
		}
		
		let v = SCNVector3(x: nodeDst.position.x - nodeSrc.position.x,
						   y: nodeDst.position.y - nodeSrc.position.y,
						   z: nodeDst.position.z - nodeSrc.position.z)
		
		let distance = sqrt((v.x * v.x) + (v.y * v.y) + (v.z * v.z))
		nodeLink.position = SCNVector3(x: nodeSrc.position.x + 0.5 * v.x / distance,
									   y: nodeSrc.position.y + 0.5 * v.y / distance,
									   z: nodeSrc.position.z + 0.5 * v.z / distance)
		
		let yaw = atan2(v.y, v.x) + .pi / 2
		let pitch = atan2(sqrt(v.x * v.x + v.y * v.y), v.z) + .pi / 2
		
		nodeLink.eulerAngles.x = pitch
		nodeLink.eulerAngles.z = yaw
		nodeLink.scale.y = distance - 1.0
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
			let node = dataSource.graphNodeView(self, modelForNodeNamed: nodeName)
			self.nodeModels[nodeName] = node
		}
		for nodeName in nodeNames {
			let linkNames = dataSource.graphNodeView(self, linksForNodeNamed: nodeName)
			self.linksNames[nodeName] = linkNames
			for linkName in linkNames {
				if let property = dataSource.graphNodeView(self,
														   linkPropertyForLinkFromNodeNamed: nodeName,
														   toNodeNamed: linkName) {
					self.linksProperty[nodeName + "-" + linkName] = property
				}
			}
		}
		self.createContent()
	}
	
}

// MARK: Calls to delegate

extension GraphNodeView {
	
	func touchSceneViewAt(point: CGPoint) {
		let hits = self.sceneView.hitTest(point, options: [:])
		let touchedNode: SCNNode? = {
			for hit in hits {
				if let node = hit.node.isIn(node: self.nodesNode) {
					return node
				}
			}
			return nil
		}()
		if let touchedNodeName = touchedNode?.name {
			self.delegate?.graphNodeView(self, selectedNodeNamed: touchedNodeName)
		}
	}
}

// MARK: Events macOS
#if os(macOS)
	extension GraphNodeView {
		
		@objc func handleClick(_ gestureReconizer: NSGestureRecognizer) {
			let position = gestureReconizer.location(in: self.sceneView)
			self.touchSceneViewAt(point: position)
		}
	}
#endif

// MARK: Events iOS
#if os(iOS)
	extension GraphNodeView {
		
		@objc func handleTap(_ gestureReconizer: UIGestureRecognizer) {
			let position = gestureReconizer.location(in: self.sceneView)
			self.touchSceneViewAt(point: position)
		}
	}
#endif

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
