//
//  GraphNodeView.swift
//  GraphNodeView
//
//  Created by Arthur Masson on 01/12/2017.
//  Copyright © 2017 Arthur Masson. All rights reserved.
//

import SceneKit
import GameplayKit

/* TODO: for the next updates
- can use spritekit instead of scenekit for simple 2D display
- create a tableview to display the dictionnary of values from selected node
- documentation
*/

#if os(macOS)
	typealias UIView = NSView
	typealias UIColor = NSColor
	let AutoResizingMaskFlexibleWidthAndHeight: NSView.AutoresizingMask = [.width, .height]
#else
	let AutoResizingMaskFlexibleWidthAndHeight: UIViewAutoresizing = [.flexibleWidth, .flexibleHeight]
#endif

@available(OSX 10.11, iOS 9.0, *)
protocol GraphNodeViewDataSource: class {
	func namesOfAllNodes(in graphNodeView: GraphNodeView) -> Set<String>
	func graphNodeView(_ graphNodeView: GraphNodeView, linksForNodeNamed: String) -> Set<String>
	func graphNodeView(_ graphNodeView: GraphNodeView, modelForNodeNamed: String) -> SCNNode
	func graphNodeView(_ graphNodeView: GraphNodeView, positionForNodeNamed: String) -> SCNVector3?
	func graphNodeView(_ graphNodeView: GraphNodeView, informationAboutNodeNamed: String) -> [String: Any]
	func graphNodeView(_ graphNodeView: GraphNodeView, linkPropertyForLinkFromNodeNamed: String, toNodeNamed: String) -> GraphNodeView.LinkProperty?
}

@available(OSX 10.11, iOS 9.0, *)
extension GraphNodeViewDataSource {
	func graphNodeView(_ graphNodeView: GraphNodeView, modelForNodeNamed name: String) -> SCNNode {
		let geometry = SCNSphere(radius: 0.5)
		let node = SCNNode(geometry: geometry)
		return node
	}
	
	func graphNodeView(_ graphNodeView: GraphNodeView, positionForNodeNamed name: String) -> SCNVector3? {
		return nil
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

@available(OSX 10.11, iOS 9.0, *)
protocol GraphNodeViewDelegate: class {
	func graphNodeView(_ graphNodeView: GraphNodeView, selectedNodeNamed name: String)
}

@available(OSX 10.11, iOS 9.0, *)
extension GraphNodeViewDelegate {
	func graphNodeView(_ graphNodeView: GraphNodeView, selectedNodeNamed name: String) {
		
	}
}

@available(OSX 10.11, iOS 9.0, *)
class GraphNodeView: UIView {
	
	struct Constants {
		static let preferedDistanceBetweenNodes: Float = 10.0
		static let startingDistanceBetweenNodes: Float = 1.0
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
	
	public var selectedNodeName: String? {
		get {
			return selectedNode?.name
		}
		set {
			if let nodeName = newValue {
				if self.nodesNode != nil {
					self.selectedNode = self.nodesNode.childNode(withName: nodeName, recursively: false)
				}
			} else {
				self.selectedNode = nil
			}
		}
	}
	
	// MARK: dataSource informations
	private var nodeNames: Set<String> = []
	private var linksNames: [String: Set<String>] = [:]
	private var nodeModels: [String: SCNNode] = [:]
	private var nodePositions: [String: SCNVector3] = [:]
	
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
		var color: UIColor = .white
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
@available(OSX 10.11, iOS 9.0, *)
extension GraphNodeView {
	
	private func initContent() {
		self.initScene()
		self.initAgents()
	}
	
	private func clearContent() {
		self.nodeNames.removeAll()
		self.nodeModels.removeAll()
		self.nodePositions.removeAll()
		self.linksNames.removeAll()
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
@available(OSX 10.11, iOS 9.0, *)
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

@available(OSX 10.11, iOS 9.0, *)
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
		agent.radius = Constants.preferedDistanceBetweenNodes
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
					pos += Constants.startingDistanceBetweenNodes
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
					pos += Constants.startingDistanceBetweenNodes
				}
				self.agents[nodeName] = agent
				newAgents.append(agent)
			}
		}
		
		for (nodeName, agent) in self.agents {
			
			if let position = self.nodePositions[nodeName] {
				agent.position3d = float3(Float(position.x), Float(position.y), Float(position.z))
			} else {
				let separateGoal = GKGoal(toSeparateFrom: newAgents,
										  maxDistance: Constants.preferedDistanceBetweenNodes,
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

@available(OSX 10.11, iOS 9.0, *)
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

@available(OSX 10.11, iOS 9.0, *)
extension GraphNodeView {
	
	private func initScene() {
		
		scene = SCNScene()
		scene.background.contents = UIColor.black
		
		nodesNode = SCNNode()
		scene.rootNode.addChildNode(nodesNode)
		
		linksNode = SCNNode()
		scene.rootNode.addChildNode(linksNode)
		
		selectorNode = createSelectorNode()
		scene.rootNode.addChildNode(selectorNode)
		
		sceneView.scene = scene
		sceneView.allowsCameraControl = true
		sceneView.autoenablesDefaultLighting = true
		
		// MARK: Camera settings
		let camera = SCNNode()
		camera.camera = SCNCamera()
		camera.position.z = 20
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
		let contener = SCNNode()
		contener.name = name
		contener.addChildNode(node)
		nodesNode.addChildNode(contener)
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
			self.selectorNode.isHidden = true
		}
	}
	
	private func sceneUpdatePosition(ofNodeNamed name: String) {
		guard let node = self.nodesNode.childNode(withName: name, recursively: false),
			let agent = self.agents[name] else {
				return
		}
		let agentPosition = agent.position3d
		node.position = SCNVector3(agentPosition.x, agentPosition.y, agentPosition.z)
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
		
		let scaler1 = SCNNode()
		scaler1.scale = SCNVector3(x: 0.1, y: 0.5, z: 0.1)
		scaler1.runAction(.repeatForever(.rotateBy(x: 0, y: .pi / 6, z: 0, duration: 1.0)))
		scaler1.runAction(.repeatForever(.rotateBy(x: 2 * .pi / 3, y: 0, z: .pi / -4, duration: 1.0)))
		scaler1.addChildNode(SCNNode(geometry: SCNTorus(ringRadius: 6.5, pipeRadius: 0.25)))
		node.addChildNode(scaler1)
		let scaler2 = SCNNode()
		scaler2.scale = SCNVector3(x: 0.1, y: 0.3, z: 0.1)
		scaler2.runAction(.repeatForever(.rotateBy(x: 0, y: -.pi / 6, z: 0, duration: 0.4)))
		scaler2.runAction(.repeatForever(.rotateBy(x: -.pi / 8, y: 0, z: .pi / 4, duration: 0.7)))
		scaler2.addChildNode(SCNNode(geometry: SCNTorus(ringRadius: 6, pipeRadius: 0.25)))
		node.addChildNode(scaler2)
		
		return node
	}
}

// MARK: Calls to datasource
@available(OSX 10.11, iOS 9.0, *)
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
			self.nodeModels[nodeName] = dataSource.graphNodeView(self, modelForNodeNamed: nodeName)
			self.nodePositions[nodeName] = dataSource.graphNodeView(self, positionForNodeNamed: nodeName)
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
		for _ in 0...1000 {
			self.agentsUpdatePositions(withDeltaTime: 0.1)
		}
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
		
		self.nodeModels[nodeName] = dataSource.graphNodeView(self, modelForNodeNamed: nodeName)
		self.nodePositions[nodeName] = dataSource.graphNodeView(self, positionForNodeNamed: nodeName)
		
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

@available(OSX 10.11, iOS 9.0, *)
extension GraphNodeView {
	
	func touchSceneViewAt(point: CGPoint) {
		let hits = self.sceneView.hitTest(point, options: [:])
		self.selectedNode = {
			for hit in hits {
				if let node = hit.node.isIn(node: self.nodesNode) {
					return node
				}
			}
			return nil
		}()
		if let touchedNodeName = self.selectedNode?.name {
			self.delegate?.graphNodeView(self, selectedNodeNamed: touchedNodeName)
		}
	}
}

#if os(macOS)
	// MARK: Events macOS
	@available(OSX 10.11, *)
	extension GraphNodeView {
		
		@objc func handleClick(_ gestureReconizer: NSGestureRecognizer) {
			let position = gestureReconizer.location(in: self.sceneView)
			self.touchSceneViewAt(point: position)
		}
	}
#elseif os(iOS)
	// MARK: Events iOS
	@available(iOS 9.0, *)
	extension GraphNodeView {
		
		@objc func handleTap(_ gestureReconizer: UIGestureRecognizer) {
			let position = gestureReconizer.location(in: self.sceneView)
			self.touchSceneViewAt(point: position)
		}
	}
#endif

// MARK: Visual functionnalities
@available(OSX 10.11, iOS 9.0, *)
extension GraphNodeView {
	
	func sendVisualSignal(withModel model: SCNNode,
						  fromNodeNamed srcName: String,
						  toNodeNamed dstName: String,
						  duration: TimeInterval = 1.0,
						  completionHandler: (() -> Void)? = nil) {
		
		guard let srcNode = self.nodesNode.childNode(withName: srcName, recursively: false),
			let dstNode = self.nodesNode.childNode(withName: dstName, recursively: false) else {
				return
		}
		model.position = SCNVector3(x: srcNode.position.x - dstNode.position.x,
									y: srcNode.position.y - dstNode.position.y,
									z: srcNode.position.z - dstNode.position.z)
		dstNode.addChildNode(model)
		model.runAction(.sequence([
			.move(to: SCNVector3Zero, duration: duration),
			.removeFromParentNode()
			]), completionHandler: completionHandler)
	}
}
