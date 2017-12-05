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
	func namesOfAllNodes(in graphNodeView: GraphNodeView) -> Set<String>
	func graphNodeView(_ graphNodeView: GraphNodeView, linksForNodeNamed: String) -> Set<String>
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
	
	struct Constants {
		static let distanceBetweenNodes: Float = 10.0
		static let arrowHeadPercentOccupation: Float = 0.1
		static let linkerChar = "-"
		private init() {}
	}
	
	weak var dataSource: GraphNodeViewDataSource? {
		didSet {
			self.reloadData()
		}
	}
	
	weak var delegate: GraphNodeViewDelegate?
	
	// MARK: dataSource informations
	private var nodeNames: Set<String> = []
	private var nodeModels: [String: SCNNode] = [:]
	private var linksNames: [String: Set<String>] = [:]
	
	// MARK: Scene uses
	private var lastUpdateTime: TimeInterval?
	private var sceneView: SCNView!
	private var scene: SCNScene!
	private var nodesNode: SCNNode!
	private var linksNode: SCNNode!
	private weak var selectedNode: SCNNode?
	private var selectorNode: SCNNode!
	
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
	
	private func createOneContent(forNode name: String) {
		self.createSceneNode(named: name)
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
		agent.radius = Constants.distanceBetweenNodes
		return agent
	}
	
	private func createAgents() {
		
		let originAgent = GKAgent()
		
		var newAgents: [GKAgent] = []
		var pos: Float = 0.0
		if self.flatGraph {
			for nodeName in nodeNames {
				let agent: GKAgent2D
				if let previousAgent = self.agents[nodeName] {
					if let previousAgent2d = previousAgent as? GKAgent2D {
						agent = previousAgent2d
						agent.behavior = nil
					} else {
						agent = self.createNewAgent() as! GKAgent2D
						agent.position3d = previousAgent.position3d
					}
				} else {
					agent = self.createNewAgent() as! GKAgent2D
					agent.position3d = float3(pos, 0, 0)
					pos += 1.0
				}
				self.agents[nodeName] = agent
				newAgents.append(agent)
			}
		} else {
			for nodeName in nodeNames {
				let agent: GKAgent3D
				if let previousAgent = self.agents[nodeName] {
					if let previousAgent3d = previousAgent as? GKAgent3D {
						agent = previousAgent3d
						agent.behavior = nil
					} else {
						agent = self.createNewAgent() as! GKAgent3D
						agent.position3d = previousAgent.position3d
					}
				} else {
					agent = self.createNewAgent() as! GKAgent3D
					agent.position3d = float3(pos, 0, 0)
					pos += 1.0
				}
				self.agents[nodeName] = agent
				newAgents.append(agent)
			}
		}

		
		for (nodeName, agent) in self.agents {
			
			let separateGoal = GKGoal(toSeparateFrom: newAgents,
									  maxDistance: Constants.distanceBetweenNodes,
									  maxAngle: .pi * 2)
			let idleGoal = GKGoal(toReachTargetSpeed: 0)
			let compactingGoal = GKGoal(toSeekAgent: originAgent)
			
			var linksAgentsGoal: [GKGoal] = []
			for link in self.linksNames[nodeName] ?? [] {
				if let linkAgent = self.agents[link] {
					linksAgentsGoal.append(GKGoal(toSeekAgent: linkAgent))
				}
			}
			
			// MARK: Behavior constants
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
		
		selectorNode = createSelectorNode()
		scene.rootNode.addChildNode(selectorNode)
		
		sceneView.scene = scene
		sceneView.allowsCameraControl = true
		sceneView.autoenablesDefaultLighting = true
		sceneView.showsStatistics = true
		
		// MARK: Camera settings
		let camera = SCNNode()
		camera.camera = SCNCamera()
		camera.position.z = 10
		scene.rootNode.addChildNode(camera)
		sceneView.pointOfView = camera
	}
	
	private func clearScene() {
		nodesNode.childNodes.forEach {$0.removeFromParentNode()}
		linksNode.childNodes.forEach {$0.removeFromParentNode()}
	}
	
	private func createScene() {
		for nodeName in self.nodeNames {
			createSceneNode(named: nodeName)
		}
	}
	
	private func createSceneNode(named nodeName: String) {
		if let node = self.nodeModels[nodeName] {
			self.sceneAdd(node: node, forName: nodeName)
		}
		if let linkNames = self.linksNames[nodeName] {
			for linkName in linkNames {
				self.sceneAdd(linkFrom: nodeName, to: linkName)
			}
		}
	}
	
	private func sceneAdd(node: SCNNode, forName name: String) {
		node.name = name
		nodesNode.addChildNode(node)
	}
	
	private func sceneAdd(linkFrom nameSrc: String, to nameDst: String) {
		
		let linkNode = SCNNode()
		linkNode.name = nameSrc + Constants.linkerChar + nameDst
		
		// loading property
		let property: LinkProperty
		if let customProperty = self.linksProperty[nameSrc + Constants.linkerChar + nameDst] {
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
		let endingDistance = property.endingDistance
			- (property.arrowShaped ? Constants.arrowHeadPercentOccupation : 0.0)
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
										height: CGFloat(Constants.arrowHeadPercentOccupation))
			case .square:
				arrowGeometry = SCNPyramid(width: CGFloat(2 * property.lineWidth),
										   height: CGFloat(Constants.arrowHeadPercentOccupation),
										   length: CGFloat(2 * property.lineWidth))
			case .wire:
				arrowGeometry = SCNCone(topRadius: 0,
										bottomRadius: CGFloat(2 * property.lineWidth),
										height: CGFloat(Constants.arrowHeadPercentOccupation))
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
		if let selectedNode = self.selectedNode {
			self.selectorNode.isHidden = false
			self.selectorNode.position = selectedNode.position
		} else {
			self.selectorNode.isHidden = false
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
			let nodeLink = self.linksNode.childNode(withName: nameSrc + Constants.linkerChar + nameDst, recursively: false)
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
	
	private func createSelectorNode() -> SCNNode {
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
		emitter.emitterShape = SCNSphere(radius: 0.5)
		emitter.birthRate = 200
		emitter.birthLocation = .surface
		emitter.birthDirection = .surfaceNormal
		emitter.isLocal = true
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
		
		return node
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
					self.linksProperty[nodeName + Constants.linkerChar + linkName] = property
				}
			}
		}
		self.createContent()
	}
	
	public func reloadNode(named nodeName: String) {
		guard let dataSource = self.dataSource else {
			return
		}
		
		if let node = self.nodesNode.childNode(withName: nodeName, recursively: false) {
			node.removeFromParentNode()
		}
		if let linkNames = self.linksNames[nodeName] {
			for linkName in linkNames {
				if let node = self.linksNode.childNode(withName: nodeName + Constants.linkerChar + linkName, recursively: false) {
					node.removeFromParentNode()
				}
			}
		}
		
		let node = dataSource.graphNodeView(self, modelForNodeNamed: nodeName)
		self.nodeModels[nodeName] = node
		
		let linkNames = dataSource.graphNodeView(self, linksForNodeNamed: nodeName)
		self.linksNames[nodeName] = linkNames
		for linkName in linkNames {
			if let property = dataSource.graphNodeView(self,
													   linkPropertyForLinkFromNodeNamed: nodeName,
													   toNodeNamed: linkName) {
				self.linksProperty[nodeName + Constants.linkerChar + linkName] = property
			}
		}
		self.createAgents()
		self.createSceneNode(named: nodeName)
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
		self.selectedNode = touchedNode
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
