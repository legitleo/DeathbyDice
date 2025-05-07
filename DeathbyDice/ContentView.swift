import SwiftUI
import SceneKit

struct ContentView: View {
    @State private var isShowingRollScreen = false
    
    var body: some View {
        NavigationView {
            VStack {
                if !isShowingRollScreen {
                    // Splash Screen
                    VStack {
                        Text("Death by Dice")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding()
                        
                        Button(action: {
                            isShowingRollScreen = true
                        }) {
                            Text("Roll the Dice")
                                .font(.title2)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                } else {
                    // Roll Screen
                    RollScreen()
                }
            }
        }
    }
}

struct RollScreen: View {
    @State private var d6Result = 1
    @State private var d20Result = 1
    @State private var isRolling = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Dice Roll Results")
                .font(.title)
                .padding()
            
            // Single Scene View for both dice
            DiceSceneView(diceType: .d6, result: d6Result, isRolling: $isRolling)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            Button(action: rollDice) {
                Text(isRolling ? "Rolling..." : "Roll Dice")
                    .font(.title2)
                    .padding()
                    .background(isRolling ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(isRolling)
            .padding()
        }
    }
    
    func rollDice() {
        isRolling = true
        
        // Simulate rolling animation duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            d6Result = Int.random(in: 1...6)
            d20Result = Int.random(in: 1...20)
            isRolling = false
        }
    }
}

enum DiceType {
    case d6
    case d20
}

struct DiceSceneView: UIViewRepresentable {
    let diceType: DiceType
    let result: Int
    @Binding var isRolling: Bool
    
    // Arena and floor constants accessible everywhere in this struct
    let floorY: Float = 0.0
    let wallHeight: Float = 5.0
    let arenaWidth: Float = 6.0
    let wallThickness: Float = 0.5
    
    class Coordinator: NSObject {
        var parent: DiceSceneView
        var timer: Timer?
        weak var diceNode: SCNNode?
        weak var sceneView: SCNView?
        var rollStartTime: Date?
        
        init(_ parent: DiceSceneView) {
            self.parent = parent
        }
        
        func startMonitoring() {
            stopMonitoring()
            rollStartTime = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                self?.checkIfSettled()
            }
        }
        
        func stopMonitoring() {
            timer?.invalidate()
            timer = nil
            rollStartTime = nil
        }
        
        func checkIfSettled() {
            guard let diceNode = diceNode, let physicsBody = diceNode.physicsBody else { return }
            let velocity = physicsBody.velocity
            let angularVelocity = physicsBody.angularVelocity
            let velocityMagnitude = sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)
            let angularMagnitude = sqrt(angularVelocity.x * angularVelocity.x + angularVelocity.y * angularVelocity.y + angularVelocity.z * angularVelocity.z)
            // Wait at least 1 second before allowing settle
            if let start = rollStartTime, Date().timeIntervalSince(start) < 1.0 {
                return
            }
            // Only settle if dice is at or just above the floor (y ≈ -2)
            let floorY: Float = -2.0
            let settleThreshold: Float = 0.2 // Allow a little tolerance above the floor
            let isOnFloor = diceNode.presentation.position.y <= (floorY + settleThreshold)
            // Only settle if the bottom face is nearly perfectly down
            var bottomFaceIsDown = false
            if diceNode.geometry is SCNBox {
                // D6 face normals in local space
                let faceNormals = [
                    SCNVector3(0, 1, 0),   // Top
                    SCNVector3(0, -1, 0),  // Bottom
                    SCNVector3(1, 0, 0),   // Right
                    SCNVector3(-1, 0, 0),  // Left
                    SCNVector3(0, 0, 1),   // Front
                    SCNVector3(0, 0, -1)   // Back
                ]
                // World down
                let worldDown = SCNVector3(0, -1, 0)
                // Find which face is most aligned with world down
                var minDot: Float = 1
                for normal in faceNormals {
                    // Convert normal to world space
                    let worldNormal = diceNode.presentation.simdConvertVector(simd_float3(normal), to: nil)
                    let dot = simd_dot(worldNormal, simd_float3(worldDown))
                    if dot < minDot {
                        minDot = dot
                    }
                }
                // If the most downward face is nearly perfectly down (dot < -0.98)
                if minDot < -0.98 {
                    bottomFaceIsDown = true
                }
            } else {
                // For non-cube dice, fallback to previous logic
                bottomFaceIsDown = true
            }
            if velocityMagnitude < 0.01 && angularMagnitude < 0.01 && isOnFloor && bottomFaceIsDown {
                DispatchQueue.main.async {
                    self.parent.isRolling = false
                }
                stopMonitoring()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> SCNView {
        let floorY: Float = 0.0
        let wallHeight: Float = 5.0
        // Arena dimensions
        let arenaWidth: Float = 6.0
        let wallThickness: Float = 0.5 // Thicker walls
        
        let sceneView = SCNView()
        sceneView.scene = SCNScene()
        sceneView.backgroundColor = .clear
        sceneView.autoenablesDefaultLighting = true
        
        // Enable physics with stronger gravity
        sceneView.scene?.physicsWorld.gravity = SCNVector3(0, -15, 0)
        
        // Move the floor up so the dice never goes below the gray area
        let floor = SCNFloor()
        floor.reflectivity = 0.0
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, floorY, 0)
        floorNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        floorNode.physicsBody?.restitution = 0.2 // Less bouncy floor
        sceneView.scene?.rootNode.addChildNode(floorNode)
        
        // Add walls (thicker, taller, and positioned at arena edges)
        let wallMaterial = SCNMaterial()
        wallMaterial.diffuse.contents = UIColor.clear
        
        // Back wall
        let backWall = SCNBox(width: CGFloat(arenaWidth), height: CGFloat(wallHeight), length: CGFloat(wallThickness), chamferRadius: 0)
        backWall.materials = [wallMaterial]
        let backWallNode = SCNNode(geometry: backWall)
        backWallNode.position = SCNVector3(0, wallHeight/2 + floorY, -arenaWidth/2)
        backWallNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        backWallNode.physicsBody?.restitution = 0.2
        sceneView.scene?.rootNode.addChildNode(backWallNode)
        
        // Front wall
        let frontWall = SCNBox(width: CGFloat(arenaWidth), height: CGFloat(wallHeight), length: CGFloat(wallThickness), chamferRadius: 0)
        frontWall.materials = [wallMaterial]
        let frontWallNode = SCNNode(geometry: frontWall)
        frontWallNode.position = SCNVector3(0, wallHeight/2 + floorY, arenaWidth/2)
        frontWallNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        frontWallNode.physicsBody?.restitution = 0.2
        sceneView.scene?.rootNode.addChildNode(frontWallNode)
        
        // Left wall
        let leftWall = SCNBox(width: CGFloat(wallThickness), height: CGFloat(wallHeight), length: CGFloat(arenaWidth), chamferRadius: 0)
        leftWall.materials = [wallMaterial]
        let leftWallNode = SCNNode(geometry: leftWall)
        leftWallNode.position = SCNVector3(-arenaWidth/2, wallHeight/2 + floorY, 0)
        leftWallNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        leftWallNode.physicsBody?.restitution = 0.2
        sceneView.scene?.rootNode.addChildNode(leftWallNode)
        
        // Right wall
        let rightWall = SCNBox(width: CGFloat(wallThickness), height: CGFloat(wallHeight), length: CGFloat(arenaWidth), chamferRadius: 0)
        rightWall.materials = [wallMaterial]
        let rightWallNode = SCNNode(geometry: rightWall)
        rightWallNode.position = SCNVector3(arenaWidth/2, wallHeight/2 + floorY, 0)
        rightWallNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        rightWallNode.physicsBody?.restitution = 0.2
        sceneView.scene?.rootNode.addChildNode(rightWallNode)
        
        // Add camera (centered vertically to fit the new arena)
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, wallHeight/2 + floorY, Float(arenaWidth))
        cameraNode.eulerAngles = SCNVector3(-0.18, 0, 0)
        sceneView.scene?.rootNode.addChildNode(cameraNode)
        
        // Add dice node
        let diceNode = createDiceNode()
        sceneView.scene?.rootNode.addChildNode(diceNode)
        
        // Save references for monitoring
        context.coordinator.diceNode = diceNode
        context.coordinator.sceneView = sceneView
        
        return sceneView
    }
    
    func updateUIView(_ sceneView: SCNView, context: Context) {
        guard let diceNode = sceneView.scene?.rootNode.childNodes.first(where: { $0.geometry is SCNBox && $0.geometry?.materials.first?.diffuse.contents as? UIColor == .blue }) else { return }
        context.coordinator.diceNode = diceNode
        context.coordinator.sceneView = sceneView
        
        if isRolling {
            // Start the dice on the floor, centered
            let diceHeight: Float = 1.5
            diceNode.position = SCNVector3(0, floorY + diceHeight / 2, 0)
            // Do not reset rotation
            
            // Add physics body
            let physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
            physicsBody.mass = 1.0
            physicsBody.friction = 0.3
            physicsBody.restitution = 0.2
            physicsBody.angularDamping = 0.2
            physicsBody.damping = 0.05
            diceNode.physicsBody = physicsBody
            
            // Apply a 'pop up' force: strong upward, some horizontal
            let throwForce = SCNVector3(
                Float.random(in: -4...4), // horizontal
                Float.random(in: 8...12), // strong upward
                Float.random(in: -4...4)  // horizontal
            )
            diceNode.physicsBody?.applyForce(throwForce, asImpulse: true)
            
            // Apply random rotation (slightly increased for a bit more spin)
            let randomRotation = SCNVector4(
                Float.random(in: 0...1),
                Float.random(in: 0...1),
                Float.random(in: 0...1),
                Float.random(in: 0...18)
            )
            diceNode.physicsBody?.applyTorque(randomRotation, asImpulse: true)
            
            // Clamp angular velocity to prevent excessive spinning
            if let body = diceNode.physicsBody {
                let maxAngular: Float = 2.5
                var av = body.angularVelocity
                let mag = sqrt(av.x * av.x + av.y * av.y + av.z * av.z)
                if mag > maxAngular && mag > 0 {
                    let scale = maxAngular / mag
                    av.x *= scale
                    av.y *= scale
                    av.z *= scale
                    body.angularVelocity = av
                }
            }
            // Start monitoring for settling
            context.coordinator.startMonitoring()
        } else {
            // Remove physics body when not rolling
            diceNode.physicsBody = nil
            // Set final position based on result
            setDicePosition(for: result, node: diceNode)
            // Stop monitoring
            context.coordinator.stopMonitoring()
        }
    }
    
    private func createDiceNode() -> SCNNode {
        // This is a placeholder. We'll replace this with actual 3D models
        let geometry: SCNGeometry
        switch diceType {
        case .d6:
            geometry = SCNBox(width: 1.5, height: 1.5, length: 1.5, chamferRadius: 0.15)
        case .d20:
            geometry = SCNBox(width: 1.5, height: 1.5, length: 1.5, chamferRadius: 0.15)
        }
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.blue
        geometry.materials = [material]
        
        return SCNNode(geometry: geometry)
    }
    
    private func setDicePosition(for result: Int, node: SCNNode) {
        // Place the dice centered and resting on the floor when not rolling
        let diceHeight: Float = 1.5 // Matches the SCNBox height
        node.position = SCNVector3(0, floorY + diceHeight / 2, 0)
        // Optionally, reset rotation to a neutral orientation
        node.eulerAngles = SCNVector3Zero
    }
}

#Preview {
    ContentView()
} 