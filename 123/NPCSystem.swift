import SceneKit
import UIKit

final class NPCSystem {

    struct HumanRig {
        let root: SCNNode
        let leftArm: SCNNode
        let rightArm: SCNNode
        let leftLeg: SCNNode
        let rightLeg: SCNNode
    }

    private final class Agent {
        let node: SCNNode
        var wps: [SIMD2<Float>]
        var idx = 0
        var speed: Float
        var heading: Float = 0
        var rig: HumanRig?
        var phase: Float = Float.random(in: 0...6)
        var bubble: SCNNode?
        var isPed = false
        var isStatic = false
        var isVehicle = false
        var taken = false
        var pauseTimer: Float = 0
        var honkCooldown: Float = 0
        var radius: Float = 0.5
        var knockedTimer: Float = 0
        var isTram = false
        var stopIdx = 0
        var dwellTimer: Float = 0
        var doors: [SCNNode] = []
        var doorsOpen = false

        init(node: SCNNode, wps: [SIMD2<Float>], speed: Float) {
            self.node = node
            self.wps = wps
            self.speed = speed
        }
    }

    private var agents: [Agent] = []
    private let root = SCNNode()

    var onHonk: (() -> Void)?

    var onTramDoors: (() -> Void)?
    private var stops: [SCNVector3] = []

    private let shirtColors: [UIColor] = [
        UIColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 1),
        UIColor(red: 0.7, green: 0.25, blue: 0.3, alpha: 1),
        UIColor(red: 0.25, green: 0.6, blue: 0.4, alpha: 1),
        UIColor(red: 0.65, green: 0.55, blue: 0.25, alpha: 1),
        UIColor(red: 0.5, green: 0.35, blue: 0.6, alpha: 1),
    ]
    private let carColors: [UIColor] = [
        UIColor(white: 0.9, alpha: 1),
        UIColor(white: 0.2, alpha: 1),
        UIColor(red: 0.2, green: 0.35, blue: 0.6, alpha: 1),
        UIColor(red: 0.6, green: 0.6, blue: 0.62, alpha: 1),
        UIColor(red: 0.35, green: 0.5, blue: 0.35, alpha: 1),
    ]
    private let pedGreetings = ["Hey!", "Nice day, eh!", "How's it goin'?", "Go Leafs!"]

    init(scene: SCNScene, city: CityData, reduced: Bool) {
        scene.rootNode.addChildNode(root)
        spawnPedestrians(count: reduced ? 6 : 12)
        spawnVehicles(count: reduced ? 4 : 8)
        spawnCyclists(count: reduced ? 2 : 4)
        spawnAutoStreetcars(count: reduced ? 1 : 2, stops: city.streetcarStops)

        spawnGreeters(spots: city.workerSpots, text: "Order up!", shirt: .white)
        spawnGreeters(spots: city.customerSpots, text: "That for me?",
                      shirt: UIColor(red: 0.4, green: 0.55, blue: 0.75, alpha: 1))
    }

    func update(dt: Float, playerPos: SCNVector3, playerCarPos: SCNVector3) {
        for a in agents {
            if a.taken { continue }

            if a.knockedTimer > 0 {
                a.knockedTimer -= dt
                if a.knockedTimer <= 0 {
                    a.node.eulerAngles.x = 0
                    a.node.position.y = 0.24
                    if let rig = a.rig { Self.settle(rig: rig, dt: 1) }
                }
                continue
            }

            if a.isTram {
                updateTram(a, dt: dt)
                continue
            }

            if a.pauseTimer > 0 {
                a.pauseTimer -= dt
                continue
            }

            if a.isVehicle {
                a.honkCooldown = max(0, a.honkCooldown - dt)
                let dx = playerCarPos.x - a.node.position.x
                let dz = playerCarPos.z - a.node.position.z
                let dist = sqrt(dx * dx + dz * dz)
                if dist < 9 {
                    let fwdX = -sin(a.heading), fwdZ = -cos(a.heading)
                    let dot = (dx / max(0.001, dist)) * fwdX + (dz / max(0.001, dist)) * fwdZ
                    if dot > 0.5 {

                        if a.honkCooldown <= 0 {
                            a.honkCooldown = 9
                            onHonk?()
                        }
                        continue
                    }
                }
                if carAhead(a) { continue }
            }

            if a.isPed || a.isStatic {
                let dx = a.node.position.x - playerPos.x
                let dz = a.node.position.z - playerPos.z
                let close = (dx * dx + dz * dz) < 9
                a.bubble?.isHidden = !close
                if close {

                    let target = atan2(-(playerPos.x - a.node.position.x),
                                       -(playerPos.z - a.node.position.z))
                    a.heading = Self.lerpAngle(a.heading, target, 1 - exp(-8 * dt))
                    a.node.eulerAngles.y = a.heading
                    if let rig = a.rig { Self.settle(rig: rig, dt: dt) }
                    continue
                }
            }
            if a.isStatic {
                if let rig = a.rig { Self.settle(rig: rig, dt: dt) }
                continue
            }
            move(a, dt: dt)
        }
    }

    private func move(_ a: Agent, dt: Float) {
        guard !a.wps.isEmpty else { return }
        let wp = a.wps[a.idx]
        var dx = wp.x - a.node.position.x
        var dz = wp.y - a.node.position.z
        let dist = sqrt(dx * dx + dz * dz)
        if dist < 0.7 {
            a.idx = (a.idx + 1) % a.wps.count
            return
        }
        dx /= dist; dz /= dist
        let target = atan2(-dx, -dz)
        a.heading = Self.lerpAngle(a.heading, target, 1 - exp(-6 * dt))
        a.node.eulerAngles.y = a.heading
        a.node.position.x += dx * a.speed * dt
        a.node.position.z += dz * a.speed * dt

        if let rig = a.rig {
            a.phase += dt * 8
            let swing = sin(a.phase) * 0.6
            rig.leftArm.eulerAngles.x = swing
            rig.rightArm.eulerAngles.x = -swing
            rig.leftLeg.eulerAngles.x = -swing * 0.9
            rig.rightLeg.eulerAngles.x = swing * 0.9
        }
    }

    private func spawnAutoStreetcars(count: Int, stops cityStops: [SCNVector3]) {
        stops = cityStops
        guard !stops.isEmpty, count > 0 else { return }
        for k in 0..<count {
            let tram = Self.makeStreetcar()

            var doorNodes: [SCNNode] = []
            for dx: Float in [-1.24, 1.24] {
                let door = SCNNode(geometry: SCNBox(width: 0.08, height: 1.9, length: 1.3,
                                                    chamferRadius: 0.02))
                door.geometry?.firstMaterial?.diffuse.contents =
                    UIColor(red: 0.9, green: 0.85, blue: 0.8, alpha: 1)
                door.position = SCNVector3(dx, 1.3, 0.9)
                tram.addChildNode(door)
                doorNodes.append(door)
            }
            let stride = max(1, stops.count / max(1, count))
            let startIdx = (k * stride) % stops.count
            let sp = stops[startIdx]

            tram.position = SCNVector3(sp.x - 30, 0, CityBuilder.transitLaneWest)
            root.addChildNode(tram)

            let a = Agent(node: tram, wps: [], speed: 9)
            a.isTram = true
            a.isVehicle = true
            a.radius = 3.2
            a.stopIdx = startIdx
            a.heading = -.pi / 2
            a.node.eulerAngles.y = a.heading
            a.doors = doorNodes
            agents.append(a)
        }
    }

    private func updateTram(_ a: Agent, dt: Float) {

        guard !stops.isEmpty else { return }
        if a.stopIdx < 0 || a.stopIdx >= stops.count { a.stopIdx = 0 }

        let laneZ = CityBuilder.transitLaneWest
        a.node.position.z = laneZ

        if a.dwellTimer > 0 {
            a.dwellTimer -= dt
            if a.dwellTimer <= 0 {

                if a.doorsOpen {
                    a.doorsOpen = false
                    for d in a.doors {
                        let to = SCNVector3(d.position.x, d.position.y, 0.9)
                        d.runAction(SCNAction.move(to: to, duration: 0.5))
                    }
                }
                a.stopIdx = stops.isEmpty ? 0 : (a.stopIdx + 1) % stops.count
            }
            return
        }

        let target = stops[a.stopIdx]

        let dx = target.x - a.node.position.x
        let dist = abs(dx)

        if dist < 1.6 {

            a.dwellTimer = 4.0
            if !a.doorsOpen {
                a.doorsOpen = true
                for d in a.doors {
                    let to = SCNVector3(d.position.x, d.position.y, 2.15)
                    d.runAction(SCNAction.move(to: to, duration: 0.5))
                }
                onTramDoors?()
            }
            return
        }

        let dir: Float = dx > 0 ? 1 : -1
        let want: Float = dir > 0 ? -Float.pi / 2 : Float.pi / 2
        a.heading = Self.lerpAngle(a.heading, want, 1 - exp(-4 * dt))
        a.node.eulerAngles.y = a.heading

        let speed = min(a.speed, max(2.5, dist * 0.8))
        a.node.position.x += dir * speed * dt
    }

    func boardableTram(near p: SCNVector3, radius: Float) -> SCNNode? {
        for a in agents where a.isTram && a.doorsOpen && a.dwellTimer > 0.6 {
            let dx = a.node.position.x - p.x
            let dz = a.node.position.z - p.z
            if dx * dx + dz * dz < radius * radius { return a.node }
        }
        return nil
    }

    func knockDown(near p: SCNVector3, radius: Float) -> Bool {
        var hit = false
        for a in agents where (a.isPed || a.isStatic) && !a.taken && a.knockedTimer <= 0 {
            let dx = a.node.position.x - p.x
            let dz = a.node.position.z - p.z
            if dx * dx + dz * dz < radius * radius {
                a.knockedTimer = 3.0
                a.node.eulerAngles.x = -Float.pi / 2
                a.node.position.y = 0.5
                a.bubble?.isHidden = true
                hit = true
            }
        }
        return hit
    }

    func detachVehicle(at index: Int) -> (SCNNode, Float)? {
        guard index < agents.count, agents[index].isVehicle,
              !agents[index].taken else { return nil }
        agents[index].taken = true
        return (agents[index].node, agents[index].heading)
    }

    func solidObstacles() -> [(x: Float, z: Float, r: Float)] {
        agents.compactMap { a in
            (a.taken || a.knockedTimer > 0)
                ? nil
                : (a.node.position.x, a.node.position.z, a.radius)
        }
    }

    func nearestPerson(to p: SCNVector3, range: Float) -> Int? {
        var best: (Int, Float)? = nil
        for (i, a) in agents.enumerated() where (a.isPed || a.isStatic) && !a.taken {
            let dx = a.node.position.x - p.x, dz = a.node.position.z - p.z
            let d = dx * dx + dz * dz
            if d < range * range && (best == nil || d < best!.1) { best = (i, d) }
        }
        return best?.0
    }

    func waveAt(index: Int, player: SCNVector3) {
        guard index < agents.count else { return }
        let a = agents[index]
        if let bubble = a.bubble {
            bubble.isHidden = false
            bubble.removeAllActions()
            let hide = SCNAction.run { (node: SCNNode) in node.isHidden = true }
            bubble.runAction(SCNAction.sequence([SCNAction.wait(duration: 2.5), hide]))
        }
        if let rig = a.rig {
            let arm = rig.rightArm
            arm.removeAllActions()
            let up = SCNAction.rotateTo(x: -2.4, y: 0, z: 0, duration: 0.2)
            let waveA = SCNAction.rotateTo(x: -2.0, y: 0, z: 0.3, duration: 0.15)
            let waveB = SCNAction.rotateTo(x: -2.4, y: 0, z: -0.3, duration: 0.15)
            let down = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2)
            let flap = SCNAction.repeat(SCNAction.sequence([waveA, waveB]), count: 3)
            arm.runAction(SCNAction.sequence([up, flap, down]))
        }
    }

    struct VehicleInfo {
        let index: Int
        let x: Float
        let z: Float
        let radius: Float
    }

    func vehicles() -> [VehicleInfo] {
        var out: [VehicleInfo] = []
        for (i, a) in agents.enumerated() where a.isVehicle && !a.taken {
            out.append(VehicleInfo(index: i, x: a.node.position.x,
                                   z: a.node.position.z, radius: 2.1))
        }
        return out
    }

    func pedestrianCount(near p: SCNVector3, radius: Float) -> Int {
        var n = 0
        for a in agents where a.isPed {
            let dx = a.node.position.x - p.x
            let dz = a.node.position.z - p.z
            if dx * dx + dz * dz < radius * radius { n += 1 }
        }
        return n
    }

    func crashVehicle(at index: Int) {
        guard index < agents.count else { return }
        agents[index].pauseTimer = 1.6
    }

    private func spawnPedestrians(count: Int) {
        for k in 0..<count {
            let (bx, bz) = randomBlockCenter()
            let r: Float = 17.5
            var wps: [SIMD2<Float>]
            if k % 3 == 0 {

                let span = CityBuilder.pitch
                wps = [SIMD2<Float>(bx - r, bz - r),
                       SIMD2<Float>(bx - r, bz + r),
                       SIMD2<Float>(bx - r + span, bz + r),
                       SIMD2<Float>(bx - r + span, bz - r)]
            } else {
                wps = [SIMD2<Float>(bx - r, bz - r), SIMD2<Float>(bx + r, bz - r),
                       SIMD2<Float>(bx + r, bz + r), SIMD2<Float>(bx - r, bz + r)]
            }
            if Bool.random() { wps.reverse() }

            let rig = Self.makeHuman(shirt: shirtColors.randomElement()!,
                                     pants: UIColor(white: 0.25, alpha: 1))
            let start = wps.randomElement()!
            rig.root.position = SCNVector3(start.x, 0.24, start.y)
            root.addChildNode(rig.root)

            let a = Agent(node: rig.root, wps: wps, speed: Float.random(in: 1.6...2.4))
            a.rig = rig
            a.isPed = true
            a.radius = 0.5
            a.bubble = Self.makeBubble(text: pedGreetings.randomElement()!,
                                       on: rig.root, height: 2.15)
            a.idx = Int.random(in: 0..<wps.count)
            agents.append(a)
        }
    }

    private func spawnVehicles(count: Int) {

        let lane: Float = CityBuilder.carOffset
        for k in 0..<count {
            let (bx, bz) = randomBlockCenter()
            let r = CityBuilder.blockSize / 2 + CityBuilder.roadW / 2

            var wps = [SIMD2<Float>(bx - r + lane, bz - r - lane),
                       SIMD2<Float>(bx + r + lane, bz - r + lane),
                       SIMD2<Float>(bx + r - lane, bz + r + lane),
                       SIMD2<Float>(bx - r - lane, bz + r - lane)]
            if k % 2 == 1 { wps.reverse() }

            let car = Self.makeCar(color: carColors.randomElement()!)
            let start = wps[0]
            car.position = SCNVector3(start.x, 0, start.y)
            root.addChildNode(car)

            let a = Agent(node: car, wps: wps, speed: Float.random(in: 4.5...6.5))
            a.isVehicle = true
            a.radius = 2.0
            a.idx = Int.random(in: 0..<wps.count)
            agents.append(a)
        }
    }

    private func carAhead(_ a: Agent) -> Bool {
        let fx = -sin(a.heading), fz = -cos(a.heading)
        for other in agents where other !== a && other.isVehicle && !other.taken {
            let dx = other.node.position.x - a.node.position.x
            let dz = other.node.position.z - a.node.position.z
            let dist = sqrt(dx * dx + dz * dz)
            if dist < 9.0 && dist > 0.01 {
                let dot = (dx / dist) * fx + (dz / dist) * fz
                if dot > 0.6 { return true }
            }
        }
        return false
    }

    private func spawnCyclists(count: Int) {
        for _ in 0..<count {
            let (bx, bz) = randomBlockCenter()

            let r = CityBuilder.blockSize / 2 + CityBuilder.bikeOffset
            var wps = [SIMD2<Float>(bx - r, bz - r), SIMD2<Float>(bx + r, bz - r),
                       SIMD2<Float>(bx + r, bz + r), SIMD2<Float>(bx - r, bz + r)]
            if Bool.random() { wps.reverse() }
            let bike = Self.makeBicycle(shirt: shirtColors.randomElement()!)
            let start = wps[0]
            bike.position = SCNVector3(start.x, 0, start.y)
            root.addChildNode(bike)
            let a = Agent(node: bike, wps: wps, speed: Float.random(in: 5.5...7))
            a.radius = 0.7
            a.idx = Int.random(in: 0..<wps.count)
            agents.append(a)
        }
    }

    private func spawnGreeters(spots: [(SCNVector3, Float)], text: String, shirt: UIColor) {
        for (pos, heading) in spots {
            let rig = Self.makeHuman(shirt: shirt, pants: UIColor(white: 0.3, alpha: 1))
            rig.root.position = SCNVector3(pos.x, 0.24, pos.z)
            rig.root.eulerAngles.y = heading
            root.addChildNode(rig.root)
            let a = Agent(node: rig.root, wps: [], speed: 0)
            a.rig = rig
            a.isStatic = true
            a.heading = heading
            a.bubble = Self.makeBubble(text: text, on: rig.root, height: 2.15)
            agents.append(a)
        }
    }

    private func randomBlockCenter() -> (Float, Float) {
        let i = Int.random(in: 0..<CityBuilder.blocks)
        let j = Int.random(in: 0..<CityBuilder.blocks)
        let off = CityBuilder.total / 2
        let bx = CityBuilder.roadW + Float(i) * CityBuilder.pitch + CityBuilder.blockSize / 2 - off
        let bz = CityBuilder.roadW + Float(j) * CityBuilder.pitch + CityBuilder.blockSize / 2 - off
        return (bx, bz)
    }

    static func makeHuman(shirt: UIColor, pants: UIColor) -> HumanRig {
        let node = SCNNode()
        let skin = UIColor(red: 0.85, green: 0.65, blue: 0.5, alpha: 1)

        let torso = SCNNode(geometry: SCNCapsule(capRadius: 0.18, height: 0.58))
        torso.geometry?.firstMaterial?.diffuse.contents = shirt
        torso.position = SCNVector3(0, 1.18, 0)
        node.addChildNode(torso)

        let head = SCNNode(geometry: SCNSphere(radius: 0.15))
        head.geometry?.firstMaterial?.diffuse.contents = skin
        head.position = SCNVector3(0, 1.62, 0)
        node.addChildNode(head)

        func arm(x: Float) -> SCNNode {
            let pivot = SCNNode()
            pivot.position = SCNVector3(x, 1.4, 0)
            let limb = SCNNode(geometry: SCNCapsule(capRadius: 0.065, height: 0.5))
            limb.geometry?.firstMaterial?.diffuse.contents = shirt
            limb.position = SCNVector3(0, -0.24, 0)
            pivot.addChildNode(limb)
            node.addChildNode(pivot)
            return pivot
        }
        func leg(x: Float) -> SCNNode {
            let pivot = SCNNode()
            pivot.position = SCNVector3(x, 0.88, 0)
            let limb = SCNNode(geometry: SCNCapsule(capRadius: 0.08, height: 0.76))
            limb.geometry?.firstMaterial?.diffuse.contents = pants
            limb.position = SCNVector3(0, -0.38, 0)
            pivot.addChildNode(limb)
            node.addChildNode(pivot)
            return pivot
        }
        return HumanRig(root: node,
                        leftArm: arm(x: -0.27), rightArm: arm(x: 0.27),
                        leftLeg: leg(x: -0.12), rightLeg: leg(x: 0.12))
    }

    static func makeCar(color: UIColor) -> SCNNode {
        let node = SCNNode()
        let body = SCNNode(geometry: SCNBox(width: 1.9, height: 0.8, length: 4.2,
                                            chamferRadius: 0.25))
        body.geometry?.firstMaterial?.diffuse.contents = color
        body.position = SCNVector3(0, 0.8, 0)
        node.addChildNode(body)
        let cabin = SCNNode(geometry: SCNBox(width: 1.65, height: 0.6, length: 1.9,
                                             chamferRadius: 0.28))
        cabin.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.55, green: 0.78, blue: 0.92, alpha: 1)
        cabin.position = SCNVector3(0, 1.42, 0.1)
        node.addChildNode(cabin)
        for (x, z) in [(-0.9, -1.35), (0.9, -1.35), (-0.9, 1.35), (0.9, 1.35)] {
            let wheel = SCNNode(geometry: SCNCylinder(radius: 0.38, height: 0.28))
            wheel.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.08, alpha: 1)
            wheel.eulerAngles.z = .pi / 2
            wheel.position = SCNVector3(Float(x), 0.38, Float(z))
            node.addChildNode(wheel)
        }
        return node
    }

    static func makeBicycle(shirt: UIColor) -> SCNNode {
        let node = SCNNode()
        for z: Float in [-0.55, 0.55] {
            let wheel = SCNNode(geometry: SCNCylinder(radius: 0.34, height: 0.06))
            wheel.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.1, alpha: 1)
            wheel.eulerAngles.z = .pi / 2
            wheel.position = SCNVector3(0, 0.34, z)
            node.addChildNode(wheel)
        }
        let frame = SCNNode(geometry: SCNBox(width: 0.08, height: 0.08, length: 1.1,
                                             chamferRadius: 0.02))
        frame.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        frame.position = SCNVector3(0, 0.6, 0)
        node.addChildNode(frame)

        let rider = makeHuman(shirt: shirt, pants: UIColor(white: 0.25, alpha: 1))
        rider.root.position = SCNVector3(0, 0.45, 0.1)
        rider.root.eulerAngles.x = -0.25
        rider.leftLeg.eulerAngles.x = 0.9
        rider.rightLeg.eulerAngles.x = 0.5
        rider.leftArm.eulerAngles.x = -0.6
        rider.rightArm.eulerAngles.x = -0.6
        node.addChildNode(rider.root)
        return node
    }

    static func makeStreetcar() -> SCNNode {
        let node = SCNNode()
        let red = UIColor(red: 0.78, green: 0.1, blue: 0.12, alpha: 1)

        let body = SCNNode(geometry: SCNBox(width: 2.4, height: 2.4, length: 10,
                                            chamferRadius: 0.3))
        body.geometry?.firstMaterial?.diffuse.contents = red
        body.position = SCNVector3(0, 1.55, 0)
        node.addChildNode(body)

        let stripe = SCNNode(geometry: SCNBox(width: 2.45, height: 0.35, length: 10.05,
                                              chamferRadius: 0.05))
        stripe.geometry?.firstMaterial?.diffuse.contents = UIColor.white
        stripe.position = SCNVector3(0, 0.7, 0)
        node.addChildNode(stripe)

        let windows = SCNNode(geometry: SCNBox(width: 2.45, height: 0.8, length: 9.2,
                                               chamferRadius: 0.05))
        windows.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.5, green: 0.7, blue: 0.85, alpha: 1)
        windows.position = SCNVector3(0, 2.1, 0)
        node.addChildNode(windows)

        let pole = SCNNode(geometry: SCNCylinder(radius: 0.05, height: 1.2))
        pole.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.2, alpha: 1)
        pole.position = SCNVector3(0, 3.3, -2)
        pole.eulerAngles.x = 0.5
        node.addChildNode(pole)
        return node
    }

    static func makeBubble(text: String, on parent: SCNNode, height: Float) -> SCNNode {

        let safe = text.isEmpty ? "..." : text
        let panel = CityBuilder.textPanel(safe, width: 2.6, height: 0.7,
                                          textColor: UIColor(white: 0.1, alpha: 1),
                                          bgColor: UIColor(white: 0.97, alpha: 1))
        let holder = SCNNode()
        holder.position = SCNVector3(0, height, 0)
        holder.addChildNode(panel)
        holder.constraints = [SCNBillboardConstraint()]
        holder.isHidden = true
        parent.addChildNode(holder)
        return holder
    }

    private static func settle(rig: HumanRig, dt: Float) {
        let k = 1 - exp(-8 * dt)
        rig.leftArm.eulerAngles.x *= (1 - k)
        rig.rightArm.eulerAngles.x *= (1 - k)
        rig.leftLeg.eulerAngles.x *= (1 - k)
        rig.rightLeg.eulerAngles.x *= (1 - k)
    }

    private static func lerpAngle(_ a: Float, _ b: Float, _ t: Float) -> Float {
        var d = (b - a).truncatingRemainder(dividingBy: 2 * .pi)
        if d > .pi { d -= 2 * .pi }
        if d < -.pi { d += 2 * .pi }
        return a + d * t
    }
}
