import UIKit
import SceneKit
import SpriteKit

enum VehicleType { case car, bike, scooter }

final class PlayerVehicle {
    let type: VehicleType
    var node = SCNNode()
    var heading: Float = 0
    var speed: Float = 0
    var wheels: [SCNNode] = []
    var doors: [SCNNode] = []
    var doorsOpen = false
    var spawnPos = SCNVector3(0, 0, 0)
    var rentalCost = 0

    let maxSpeed: Float
    let accel: Float
    let brakePower: Float
    let maxReverse: Float
    let radius: Float
    let enterRadius: Float

    init(type: VehicleType) {
        self.type = type
        switch type {
        case .car:
            maxSpeed = 24; accel = 12; brakePower = 18; maxReverse = -7
            radius = 1.5; enterRadius = 4
        case .bike:
            maxSpeed = 10; accel = 8; brakePower = 12; maxReverse = -2
            radius = 0.6; enterRadius = 3
        case .scooter:
            maxSpeed = 12; accel = 10; brakePower = 12; maxReverse = -2
            radius = 0.5; enterRadius = 3
        }
    }

    var displayName: String {
        switch type {
        case .car: return "Car 🚗"
        case .bike: return "Bike 🚲"
        case .scooter: return "E-Scooter 🛴"
        }
    }
}

class GameViewController: UIViewController {

    var scnView: SCNView!
    let scene = SCNScene()
    var hud: HUDScene!
    var city = CityData()
    var npcs: NPCSystem!
    var displayLink: CADisplayLink?

    let playerNode = SCNNode()
    var leftArm = SCNNode()
    var rightArm = SCNNode()
    var leftLeg = SCNNode()
    var rightLeg = SCNNode()
    var bodyGroup = SCNNode()
    var walkPhase: Float = 0
    var moveAmount: Float = 0
    var playerHeading: Float = 0
    var jumpY: Float = 0
    var vy: Float = 0
    var crouching = false
    var ridePhase: Float = 0
    var idlePhase: Float = 0
    var trafficLights: [TrafficLight] = []
    struct WaitingRider { let node: SCNNode; var respawnAt: Double }
    var waitingRiders: [WaitingRider] = []

    var garage: [PlayerVehicle] = []
    var activeVehicle: PlayerVehicle?
    var camYaw: Float = 0

    let walkSpeed: Float = 4.6
    let pickupRadius: Float = 3.5
    let deliverRadius: Float = 6

    struct Offer {
        let name: String
        let pay: Int
        let restaurant: SCNVector3
        let customer: SCNVector3
        let customerName: String
        let address: String
    }

    let firstNames = ["Aisha", "Marcus", "Priya", "Jordan", "Wei", "Sofia",
                      "Liam", "Fatima", "Diego", "Chloe", "Omar", "Hannah"]
    let customerLines = [
        "Finally! I'm starving.",
        "You got here fast — nice!",
        "Ooh, smells amazing. Thanks!",
        "Right on time, thank you!",
        "Just leave it on the table, thanks!",
        "You're a lifesaver, seriously.",
        "Hope it's still hot!",
        "Thanks for coming all the way up!",
    ]
    enum Phase { case none, toRestaurant, toCustomer }
    var offers: [Offer] = []
    var activeOrder: Offer?
    var phase: Phase = .none
    var money = 0
    var acceptedAt: CFTimeInterval = 0

    var paused = true
    var deliveries = 0
    var streak = 0
    var crashCooldown: Float = 0
    var coins: [SCNNode] = []
    var venueWorkers: [SCNNode] = []

    let restaurantNames = ["Burger Barn", "Pizza Palace", "Sushi Spot",
                           "Taco Town", "Noodle Nook", "Curry Corner"]

    var lastActionTitle: String? = "…"
    var lastStatus = "…"
    var lastStreet = ""

    let nsStreets = ["Bathurst St", "Spadina Ave", "University Ave", "Bay St",
                     "Yonge St", "Church St", "Jarvis St", "Parliament St"]
    let ewStreets = ["Bloor St", "College St", "Dundas St", "Queen St",
                     "King St", "Front St", "Lake Shore", "Harbour St"]

    override func viewDidLoad() {
        super.viewDidLoad()

        if let existing = self.view as? SCNView {
            scnView = existing
        } else {
            scnView = SCNView(frame: view.bounds)
            scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(scnView)
        }
        scnView.scene = scene
        scnView.rendersContinuously = true
        scnView.backgroundColor = UIColor(red: 0.62, green: 0.78, blue: 0.94, alpha: 1)

        scnView.preferredFramesPerSecond = 60
        #if targetEnvironment(simulator)
        scnView.antialiasingMode = .none
        #else
        scnView.antialiasingMode = .multisampling2X
        #endif

        setupSkyAndLights()
        city = CityBuilder.build(into: scene)
        buildCharacter()
        buildGarage()
        buildCamera()
        buildMarker()
        setupHUD()
        #if targetEnvironment(simulator)
        npcs = NPCSystem(scene: scene, city: city, reduced: true)
        #else
        npcs = NPCSystem(scene: scene, city: city, reduced: false)
        #endif
        buildCoins()
        buildVenueWorkers()
        buildStopRiders()
        buildTrafficLights()

        hud.configureMinimap(image: CityBuilder.minimapImage(data: city),
                             worldMin: -CityBuilder.total / 2,
                             worldMax: CityBuilder.total / 2)

        for _ in 0..<3 { generateOffer() }
        pushOffersToHUD()

        Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            guard let self = self, self.offers.count < 3 else { return }
            self.generateOffer()
            self.pushOffersToHUD()
        }

        hud.onPause = { [weak self] in self?.showPauseMenu() }
        hud.onMenuButton = { [weak self] id in self?.handleMenu(id) }
        hud.onJump = { [weak self] in self?.tryJump() }
        hud.onHonk = { SoundManager.shared.honk() }
        npcs.onHonk = { SoundManager.shared.honk() }
        npcs.onTramDoors = { SoundManager.shared.doors() }
        hud.onCrouch = { [weak self] in self?.toggleCrouch() }

        displayLink = CADisplayLink(target: self, selector: #selector(step(_:)))
        displayLink?.add(to: .main, forMode: .common)

        showMainMenu()
    }

    deinit { displayLink?.invalidate() }

    func setupSkyAndLights() {
        scene.background.contents = skyGradientImage()
        scene.fogStartDistance = 90
        scene.fogEndDistance = 380
        scene.fogColor = UIColor(red: 0.75, green: 0.83, blue: 0.92, alpha: 1)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 550
        ambient.light!.color = UIColor(red: 0.85, green: 0.88, blue: 0.95, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light!.type = .directional
        sun.light!.intensity = 1000
        sun.light!.color = UIColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 1)
        #if !targetEnvironment(simulator)
        sun.light!.castsShadow = true
        sun.light!.shadowMapSize = CGSize(width: 1024, height: 1024)
        sun.light!.shadowColor = UIColor(white: 0, alpha: 0.4)
        sun.light!.shadowRadius = 3
        sun.light!.automaticallyAdjustsShadowProjection = true
        #endif
        sun.eulerAngles = SCNVector3(-Float.pi / 3.2, Float.pi / 4.5, 0)
        scene.rootNode.addChildNode(sun)
    }

    func skyGradientImage() -> UIImage {
        let size = CGSize(width: 64, height: 256)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 1).cgColor,
                          UIColor(red: 0.78, green: 0.86, blue: 0.94, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors as CFArray, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero,
                                             end: CGPoint(x: 0, y: size.height),
                                             options: [])
        }
    }

    func buildCharacter() {
        playerNode.position = city.playerSpawn
        scene.rootNode.addChildNode(playerNode)
        playerNode.addChildNode(bodyGroup)

        let skin  = UIColor(red: 0.80, green: 0.62, blue: 0.48, alpha: 1)
        let jacket = UIColor(red: 0.88, green: 0.34, blue: 0.14, alpha: 1)
        let jacketDark = UIColor(red: 0.62, green: 0.22, blue: 0.09, alpha: 1)
        let denim = UIColor(red: 0.20, green: 0.26, blue: 0.38, alpha: 1)
        let hair  = UIColor(red: 0.16, green: 0.12, blue: 0.10, alpha: 1)

        let chest = SCNNode(geometry: SCNBox(width: 0.44, height: 0.40, length: 0.24,
                                             chamferRadius: 0.11))
        chest.geometry?.firstMaterial?.diffuse.contents = jacket
        chest.position = SCNVector3(0, 1.34, 0)
        bodyGroup.addChildNode(chest)

        let waist = SCNNode(geometry: SCNBox(width: 0.36, height: 0.26, length: 0.21,
                                             chamferRadius: 0.09))
        waist.geometry?.firstMaterial?.diffuse.contents = jacketDark
        waist.position = SCNVector3(0, 1.03, 0)
        bodyGroup.addChildNode(waist)

        for sx: Float in [-0.24, 0.24] {
            let shoulder = SCNNode(geometry: SCNSphere(radius: 0.115))
            shoulder.geometry?.firstMaterial?.diffuse.contents = jacket
            shoulder.position = SCNVector3(sx, 1.49, 0)
            bodyGroup.addChildNode(shoulder)
        }

        let zip = SCNNode(geometry: SCNBox(width: 0.035, height: 0.38, length: 0.02,
                                           chamferRadius: 0.01))
        zip.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.9, alpha: 1)
        zip.position = SCNVector3(0, 1.34, -0.125)
        bodyGroup.addChildNode(zip)

        let neck = SCNNode(geometry: SCNCylinder(radius: 0.055, height: 0.1))
        neck.geometry?.firstMaterial?.diffuse.contents = skin
        neck.position = SCNVector3(0, 1.575, 0)
        bodyGroup.addChildNode(neck)

        let head = SCNNode(geometry: SCNSphere(radius: 0.135))
        head.geometry?.firstMaterial?.diffuse.contents = skin
        head.scale = SCNVector3(0.92, 1.12, 1.0)
        head.position = SCNVector3(0, 1.72, 0)
        bodyGroup.addChildNode(head)

        let hairCap = SCNNode(geometry: SCNSphere(radius: 0.138))
        hairCap.geometry?.firstMaterial?.diffuse.contents = hair
        hairCap.scale = SCNVector3(0.94, 0.78, 1.02)
        hairCap.position = SCNVector3(0, 1.79, 0.012)
        bodyGroup.addChildNode(hairCap)

        for ex: Float in [-0.125, 0.125] {
            let ear = SCNNode(geometry: SCNSphere(radius: 0.032))
            ear.geometry?.firstMaterial?.diffuse.contents = skin
            ear.scale = SCNVector3(0.5, 1, 0.8)
            ear.position = SCNVector3(ex, 1.72, 0.01)
            bodyGroup.addChildNode(ear)
        }

        for ex: Float in [-0.052, 0.052] {
            let white = SCNNode(geometry: SCNSphere(radius: 0.028))
            white.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.97, alpha: 1)
            white.position = SCNVector3(ex, 1.745, -0.108)
            bodyGroup.addChildNode(white)

            let iris = SCNNode(geometry: SCNSphere(radius: 0.014))
            iris.geometry?.firstMaterial?.diffuse.contents =
                UIColor(red: 0.22, green: 0.16, blue: 0.12, alpha: 1)
            iris.position = SCNVector3(ex, 1.745, -0.128)
            bodyGroup.addChildNode(iris)

            let brow = SCNNode(geometry: SCNBox(width: 0.055, height: 0.014, length: 0.02,
                                                chamferRadius: 0.005))
            brow.geometry?.firstMaterial?.diffuse.contents = hair
            brow.position = SCNVector3(ex, 1.787, -0.115)
            bodyGroup.addChildNode(brow)
        }

        let nose = SCNNode(geometry: SCNSphere(radius: 0.022))
        nose.geometry?.firstMaterial?.diffuse.contents = skin
        nose.scale = SCNVector3(0.8, 1.1, 1.3)
        nose.position = SCNVector3(0, 1.712, -0.132)
        bodyGroup.addChildNode(nose)

        let mouth = SCNNode(geometry: SCNBox(width: 0.05, height: 0.011, length: 0.015,
                                             chamferRadius: 0.005))
        mouth.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.55, green: 0.32, blue: 0.30, alpha: 1)
        mouth.position = SCNVector3(0, 1.665, -0.126)
        bodyGroup.addChildNode(mouth)

        let cap = SCNNode(geometry: SCNSphere(radius: 0.142))
        cap.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.75, green: 0.13, blue: 0.13, alpha: 1)
        cap.scale = SCNVector3(1.0, 0.55, 1.0)
        cap.position = SCNVector3(0, 1.815, 0)
        bodyGroup.addChildNode(cap)

        let brim = SCNNode(geometry: SCNBox(width: 0.2, height: 0.022, length: 0.13,
                                            chamferRadius: 0.012))
        brim.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.62, green: 0.10, blue: 0.10, alpha: 1)
        brim.position = SCNVector3(0, 1.79, -0.155)
        bodyGroup.addChildNode(brim)

        let bag = SCNNode(geometry: SCNBox(width: 0.34, height: 0.4, length: 0.17,
                                           chamferRadius: 0.05))
        bag.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.08, green: 0.55, blue: 0.5, alpha: 1)
        bag.position = SCNVector3(0, 1.32, 0.21)
        bodyGroup.addChildNode(bag)
        for sx: Float in [-0.12, 0.12] {
            let strap = SCNNode(geometry: SCNBox(width: 0.05, height: 0.34, length: 0.03,
                                                 chamferRadius: 0.01))
            strap.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.15, alpha: 1)
            strap.position = SCNVector3(sx, 1.36, 0.11)
            bodyGroup.addChildNode(strap)
        }

        func makeArm(x: Float) -> SCNNode {
            let pivot = SCNNode()
            pivot.position = SCNVector3(x, 1.47, 0)

            let upper = SCNNode(geometry: SCNCapsule(capRadius: 0.058, height: 0.32))
            upper.geometry?.firstMaterial?.diffuse.contents = jacket
            upper.position = SCNVector3(0, -0.15, 0)
            pivot.addChildNode(upper)

            let fore = SCNNode(geometry: SCNCapsule(capRadius: 0.05, height: 0.3))
            fore.geometry?.firstMaterial?.diffuse.contents = jacket
            fore.position = SCNVector3(0, -0.42, 0)
            pivot.addChildNode(fore)

            let hand = SCNNode(geometry: SCNSphere(radius: 0.055))
            hand.geometry?.firstMaterial?.diffuse.contents = skin
            hand.scale = SCNVector3(0.85, 1.1, 0.7)
            hand.position = SCNVector3(0, -0.6, 0)
            pivot.addChildNode(hand)

            bodyGroup.addChildNode(pivot)
            return pivot
        }
        leftArm = makeArm(x: -0.27)
        rightArm = makeArm(x: 0.27)

        func makeLeg(x: Float) -> SCNNode {
            let pivot = SCNNode()
            pivot.position = SCNVector3(x, 0.92, 0)

            let thigh = SCNNode(geometry: SCNCapsule(capRadius: 0.075, height: 0.44))
            thigh.geometry?.firstMaterial?.diffuse.contents = denim
            thigh.position = SCNVector3(0, -0.21, 0)
            pivot.addChildNode(thigh)

            let shin = SCNNode(geometry: SCNCapsule(capRadius: 0.062, height: 0.42))
            shin.geometry?.firstMaterial?.diffuse.contents = denim
            shin.position = SCNVector3(0, -0.6, 0)
            pivot.addChildNode(shin)

            let shoe = SCNNode(geometry: SCNBox(width: 0.13, height: 0.075, length: 0.26,
                                                chamferRadius: 0.035))
            shoe.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.93, alpha: 1)
            shoe.position = SCNVector3(0, -0.84, -0.045)
            pivot.addChildNode(shoe)

            let sole = SCNNode(geometry: SCNBox(width: 0.135, height: 0.028, length: 0.265,
                                                chamferRadius: 0.012))
            sole.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.35, alpha: 1)
            sole.position = SCNVector3(0, -0.875, -0.045)
            pivot.addChildNode(sole)

            bodyGroup.addChildNode(pivot)
            return pivot
        }
        leftLeg = makeLeg(x: -0.115)
        rightLeg = makeLeg(x: 0.115)
    }

    func buildGarage() {

        let car = PlayerVehicle(type: .car)
        let paint = SCNMaterial()
        paint.diffuse.contents = UIColor(red: 0.05, green: 0.3, blue: 0.7, alpha: 1)
        paint.specular.contents = UIColor.white
        paint.shininess = 90

        let body = SCNNode(geometry: SCNBox(width: 2.0, height: 0.55, length: 4.6,
                                            chamferRadius: 0.24))
        body.geometry?.materials = [paint]
        body.position = SCNVector3(0, 0.62, 0)
        car.node.addChildNode(body)

        let hood = SCNNode(geometry: SCNBox(width: 1.85, height: 0.16, length: 1.2,
                                            chamferRadius: 0.08))
        hood.geometry?.materials = [paint]
        hood.position = SCNVector3(0, 0.94, -1.5)
        car.node.addChildNode(hood)

        let glassMat = SCNMaterial()
        glassMat.diffuse.contents = UIColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 1)
        glassMat.specular.contents = UIColor.white
        glassMat.shininess = 100
        let cabin = SCNNode(geometry: SCNBox(width: 1.66, height: 0.5, length: 2.0,
                                             chamferRadius: 0.24))
        cabin.geometry?.materials = [glassMat]
        cabin.position = SCNVector3(0, 1.14, 0.15)
        car.node.addChildNode(cabin)

        let wing = SCNNode(geometry: SCNBox(width: 1.7, height: 0.07, length: 0.42,
                                            chamferRadius: 0.03))
        wing.geometry?.materials = [paint]
        wing.position = SCNVector3(0, 1.18, 2.15)
        car.node.addChildNode(wing)
        for wx: Float in [-0.6, 0.6] {
            let post = SCNNode(geometry: SCNBox(width: 0.08, height: 0.3, length: 0.08,
                                                chamferRadius: 0.01))
            post.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.15, alpha: 1)
            post.position = SCNVector3(wx, 1.0, 2.15)
            car.node.addChildNode(post)
        }

        for mx: Float in [-1.02, 1.02] {
            let mirror = SCNNode(geometry: SCNBox(width: 0.14, height: 0.1, length: 0.2,
                                                  chamferRadius: 0.03))
            mirror.geometry?.materials = [paint]
            mirror.position = SCNVector3(mx, 1.05, -0.65)
            car.node.addChildNode(mirror)
        }

        for (x, z) in [(-0.95, -1.5), (0.95, -1.5), (-0.95, 1.5), (0.95, 1.5)] {
            let hubNode = SCNNode()
            hubNode.position = SCNVector3(Float(x), 0.42, Float(z))
            let tire = SCNNode(geometry: SCNCylinder(radius: 0.42, height: 0.3))
            tire.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.06, alpha: 1)
            tire.eulerAngles.z = .pi / 2
            hubNode.addChildNode(tire)
            let rim = SCNNode(geometry: SCNCylinder(radius: 0.24, height: 0.32))
            rim.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.8, alpha: 1)
            rim.geometry?.firstMaterial?.specular.contents = UIColor.white
            rim.eulerAngles.z = .pi / 2
            hubNode.addChildNode(rim)
            car.node.addChildNode(hubNode)
            car.wheels.append(hubNode)
        }
        for x: Float in [-0.65, 0.65] {
            let headL = SCNNode(geometry: SCNBox(width: 0.45, height: 0.1, length: 0.08,
                                                 chamferRadius: 0.03))
            headL.geometry?.firstMaterial?.emission.contents = UIColor.white
            headL.position = SCNVector3(x, 0.72, -2.32)
            car.node.addChildNode(headL)
            let tail = SCNNode(geometry: SCNBox(width: 0.45, height: 0.1, length: 0.08,
                                                chamferRadius: 0.03))
            tail.geometry?.firstMaterial?.emission.contents = UIColor.red
            tail.position = SCNVector3(x, 0.72, 2.32)
            car.node.addChildNode(tail)
        }
        car.spawnPos = city.carSpawn
        car.node.position = car.spawnPos
        scene.rootNode.addChildNode(car.node)
        garage.append(car)

        let bike = makeBikeVehicle()
        bike.spawnPos = SCNVector3(city.carSpawn.x + 7, 0, city.carSpawn.z)
        bike.node.position = bike.spawnPos
        scene.rootNode.addChildNode(bike.node)
        garage.append(bike)

        let stationBlocks: [(Int, Int)] = [(1, 3), (5, 3), (3, 1)]
        let off = CityBuilder.total / 2
        for (i, j) in stationBlocks {
            let bx = CityBuilder.roadW + Float(i) * CityBuilder.pitch
                     + CityBuilder.blockSize / 2 - off
            let bz = CityBuilder.roadW + Float(j) * CityBuilder.pitch
                     + CityBuilder.blockSize / 2 - off

            let rack = SCNNode(geometry: SCNBox(width: 5, height: 0.15, length: 1.4,
                                                chamferRadius: 0.03))
            rack.geometry?.firstMaterial?.diffuse.contents =
                UIColor(red: 0.1, green: 0.45, blue: 0.3, alpha: 1)
            rack.position = SCNVector3(bx, 0.4, bz - 17)
            scene.rootNode.addChildNode(rack)

            let rentBike = makeBikeVehicle()
            rentBike.rentalCost = 2
            rentBike.spawnPos = SCNVector3(bx - 1.4, 0, bz - 17)
            rentBike.node.position = rentBike.spawnPos
            scene.rootNode.addChildNode(rentBike.node)
            garage.append(rentBike)

            let scooter = makeScooterVehicle()
            scooter.rentalCost = 2
            scooter.spawnPos = SCNVector3(bx + 1.4, 0, bz - 17)
            scooter.node.position = scooter.spawnPos
            scene.rootNode.addChildNode(scooter.node)
            garage.append(scooter)
        }
    }

    func makeBikeVehicle() -> PlayerVehicle {
        let bike = PlayerVehicle(type: .bike)
        for z: Float in [-0.55, 0.55] {
            let wheel = SCNNode(geometry: SCNCylinder(radius: 0.34, height: 0.06))
            wheel.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.1, alpha: 1)
            wheel.eulerAngles.z = .pi / 2
            wheel.position = SCNVector3(0, 0.34, z)
            bike.node.addChildNode(wheel)
            bike.wheels.append(wheel)
        }
        let frame = SCNNode(geometry: SCNBox(width: 0.08, height: 0.08, length: 1.1,
                                             chamferRadius: 0.02))
        frame.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.9, green: 0.55, blue: 0.1, alpha: 1)
        frame.position = SCNVector3(0, 0.6, 0)
        bike.node.addChildNode(frame)

        let seatTube = SCNNode(geometry: SCNCylinder(radius: 0.035, height: 0.4))
        seatTube.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.9, green: 0.55, blue: 0.1, alpha: 1)
        seatTube.position = SCNVector3(0, 0.78, 0.35)
        bike.node.addChildNode(seatTube)
        let headTube = SCNNode(geometry: SCNCylinder(radius: 0.035, height: 0.5))
        headTube.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.2, alpha: 1)
        headTube.eulerAngles.x = 0.3
        headTube.position = SCNVector3(0, 0.72, -0.5)
        bike.node.addChildNode(headTube)
        let bars = SCNNode(geometry: SCNBox(width: 0.55, height: 0.05, length: 0.05,
                                            chamferRadius: 0.02))
        bars.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.2, alpha: 1)
        bars.position = SCNVector3(0, 0.98, -0.55)
        bike.node.addChildNode(bars)
        let seat = SCNNode(geometry: SCNBox(width: 0.22, height: 0.06, length: 0.3,
                                            chamferRadius: 0.03))
        seat.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.1, alpha: 1)
        seat.position = SCNVector3(0, 0.98, 0.35)
        bike.node.addChildNode(seat)
        return bike
    }

    func makeScooterVehicle() -> PlayerVehicle {
        let sc = PlayerVehicle(type: .scooter)
        let deck = SCNNode(geometry: SCNBox(width: 0.3, height: 0.07, length: 1.1,
                                            chamferRadius: 0.03))
        deck.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.15, alpha: 1)
        deck.position = SCNVector3(0, 0.22, 0)
        sc.node.addChildNode(deck)
        for z: Float in [-0.5, 0.5] {
            let wheel = SCNNode(geometry: SCNCylinder(radius: 0.14, height: 0.08))
            wheel.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.08, alpha: 1)
            wheel.eulerAngles.z = .pi / 2
            wheel.position = SCNVector3(0, 0.14, z)
            sc.node.addChildNode(wheel)
            sc.wheels.append(wheel)
        }
        let stem = SCNNode(geometry: SCNCylinder(radius: 0.035, height: 1.0))
        stem.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.1, green: 0.65, blue: 0.4, alpha: 1)
        stem.position = SCNVector3(0, 0.75, -0.5)
        sc.node.addChildNode(stem)
        let bars = SCNNode(geometry: SCNBox(width: 0.5, height: 0.05, length: 0.05,
                                            chamferRadius: 0.02))
        bars.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.2, alpha: 1)
        bars.position = SCNVector3(0, 1.26, -0.5)
        sc.node.addChildNode(bars)
        return sc
    }

    func buildVenueWorkers() {

        for v in city.venues {
            let shirt: UIColor
            switch v.kind {
            case .restaurant: shirt = UIColor(red: 0.95, green: 0.95, blue: 0.92, alpha: 1)
            case .bank:       shirt = UIColor(red: 0.2, green: 0.25, blue: 0.4, alpha: 1)
            case .grocery:    shirt = UIColor(red: 0.2, green: 0.5, blue: 0.3, alpha: 1)
            case .shop:       shirt = UIColor(red: 0.45, green: 0.35, blue: 0.55, alpha: 1)
            }
            let rig = NPCSystem.makeHuman(shirt: shirt,
                                          pants: UIColor(white: 0.28, alpha: 1))
            rig.root.position = SCNVector3(v.workerPos.x, 0.24, v.workerPos.z)
            rig.root.eulerAngles.y = v.workerHeading
            scene.rootNode.addChildNode(rig.root)
            venueWorkers.append(rig.root)
        }
    }

    func buildStopRiders() {
        for stop in city.streetcarStops {
            for k in 0..<2 {
                let rig = NPCSystem.makeHuman(
                    shirt: UIColor(red: 0.45, green: 0.5, blue: 0.65, alpha: 1),
                    pants: UIColor(white: 0.3, alpha: 1))
                rig.root.position = SCNVector3(stop.x + Float(k) * 1.4 - 0.7, 0.24,
                                               stop.z + 2.2)
                scene.rootNode.addChildNode(rig.root)
                waitingRiders.append(WaitingRider(node: rig.root, respawnAt: 0))
            }
        }
    }

    var lastLightUpdate: Double = 0

    func buildTrafficLights() {

        for (i, pos) in city.trafficLightPositions.enumerated() {
            let tl = TrafficLight(at: pos, offset: Double(i % 4) * 2.5)
            scene.rootNode.addChildNode(tl.node)
            trafficLights.append(tl)
        }
    }

    func updateTrafficLights(playerPos: SCNVector3) {
        let now = CACurrentMediaTime()
        guard now - lastLightUpdate > 0.25 else { return }
        lastLightUpdate = now
        for tl in trafficLights {
            let dx = tl.node.position.x - playerPos.x
            let dz = tl.node.position.z - playerPos.z
            if dx * dx + dz * dz < 90 * 90 {
                tl.update(time: now)
            }
        }
    }

    func buildCamera() {
        let camNode = SCNNode()
        camNode.camera = SCNCamera()
        camNode.camera!.zFar = 700
        camNode.camera!.fieldOfView = 62
        scene.rootNode.addChildNode(camNode)
        self.camNode = camNode
        snapCamera()
    }
    var camNode = SCNNode()

    func buildMarker() {
        let beam = SCNNode(geometry: SCNCylinder(radius: 1.1, height: 45))
        beam.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 1, green: 0.9, blue: 0.2, alpha: 0.25)
        beam.geometry?.firstMaterial?.emission.contents =
            UIColor(red: 1, green: 0.9, blue: 0.2, alpha: 1)
        beam.geometry?.firstMaterial?.isDoubleSided = true
        beam.castsShadow = false
        beam.position = SCNVector3(0, 22.5, 0)
        markerNode.addChildNode(beam)
        markerNode.isHidden = true
        markerNode.runAction(.repeatForever(.sequence([
            .fadeOpacity(to: 0.4, duration: 0.5),
            .fadeOpacity(to: 1.0, duration: 0.5),
        ])))
        scene.rootNode.addChildNode(markerNode)
    }
    let markerNode = SCNNode()

    func setupHUD() {
        hud = HUDScene(size: view.bounds.size)
        scnView.overlaySKScene = hud
        hud.onAction = { [weak self] in self?.performAction() }
        hud.onOfferSelected = { [weak self] idx in self?.accept(idx) }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hud?.size = view.bounds.size
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }

    var saveExists: Bool { UserDefaults.standard.bool(forKey: "save.exists") }

    func saveGame() {
        let d = UserDefaults.standard
        d.set(true, forKey: "save.exists")
        d.set(money, forKey: "save.money")
        d.set(deliveries, forKey: "save.deliveries")
    }

    func loadGame() {
        let d = UserDefaults.standard
        money = d.integer(forKey: "save.money")
        deliveries = d.integer(forKey: "save.deliveries")
        hud.setMoney(money)
    }

    func rankName() -> String {
        if deliveries >= 15 { return "Six Legend" }
        if deliveries >= 5 { return "City Pro" }
        return "Rookie"
    }

    func statsLine() -> String {
        "Cash $\(money) · Deliveries \(deliveries) · Rank: \(rankName())"
    }

    func showMainMenu() {
        paused = true
        var buttons: [(String, String)] = []
        if saveExists { buttons.append(("continue", "Continue")) }
        buttons.append(("new", "New Game"))
        hud.showMenu(title: "Delivereo",
                     subtitle: saveExists ? statsLine() : "Deliver food. Get paid. Don't crash.",
                     buttons: buttons)
    }

    func showPauseMenu() {
        guard !paused else { return }
        paused = true
        hud.showMenu(title: "Paused",
                     subtitle: statsLine(),
                     buttons: [("resume", "Resume"),
                               ("save", "Save Game"),
                               ("mainmenu", "Main Menu")])
    }

    func handleMenu(_ id: String) {
        switch id {
        case "new":
            resetProgress()
            hud.hideMenu()
            paused = false
        case "continue":
            loadGame()
            hud.hideMenu()
            paused = false
        case "resume":
            hud.hideMenu()
            paused = false
        case "save":
            saveGame()
            hud.hideMenu()
            paused = false
            hud.flash("Game saved! 💾")
        case "mainmenu":
            saveGame()
            showMainMenu()
        default:
            break
        }
    }

    func resetProgress() {
        ridingTram = nil
        money = 0
        deliveries = 0
        streak = 0
        hud.setMoney(0)
        activeOrder = nil
        phase = .none
        markerNode.isHidden = true
        exitVehicleState()
        playerNode.position = city.playerSpawn
        playerHeading = 0
        for v in garage {
            v.node.position = v.spawnPos
            v.speed = 0
            v.heading = 0
            v.node.eulerAngles.y = v.heading
        }
        for c in coins { c.isHidden = false }
        snapCamera()
        saveGame()
    }

    func exitVehicleState() {
        activeVehicle = nil
        playerNode.isHidden = false
        hud.setDriving(false)
    }

    func buildCoins() {
        for _ in 0..<18 {
            let i = Int.random(in: 0..<CityBuilder.blocks)
            let j = Int.random(in: 0..<CityBuilder.blocks)
            let off = CityBuilder.total / 2
            let bx = CityBuilder.roadW + Float(i) * CityBuilder.pitch
                     + CityBuilder.blockSize / 2 - off
            let bz = CityBuilder.roadW + Float(j) * CityBuilder.pitch
                     + CityBuilder.blockSize / 2 - off
            let corner: [(Float, Float)] = [(-16, 0), (16, 0), (0, -16), (0, 16)]
            guard let (cx, cz) = corner.randomElement() else { continue }

            let spinner = SCNNode()
            spinner.position = SCNVector3(bx + cx, 0.85, bz + cz)
            let disc = SCNNode(geometry: SCNCylinder(radius: 0.35, height: 0.08))
            disc.geometry?.firstMaterial?.diffuse.contents =
                UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
            disc.geometry?.firstMaterial?.emission.contents =
                UIColor(red: 0.8, green: 0.65, blue: 0.1, alpha: 1)
            disc.eulerAngles.x = .pi / 2
            spinner.addChildNode(disc)
            spinner.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 2)))
            scene.rootNode.addChildNode(spinner)
            coins.append(spinner)
        }
    }

    func checkCoins() {
        let p = activeVehicle?.node.position ?? playerNode.position
        for c in coins where !c.isHidden {
            let dx = c.position.x - p.x, dz = c.position.z - p.z
            if dx * dx + dz * dz < 2.0 {
                c.isHidden = true
                money += 1
                hud.setMoney(money)
                SoundManager.shared.coin()
                hud.flash("+$1 coin!")
            }
        }
    }

    func generateOffer() {
        guard !city.restaurantDoors.isEmpty, !city.houseDoors.isEmpty else { return }

        let ri = Int.random(in: 0..<city.restaurantDoors.count)
        let r = city.restaurantDoors[ri]
        let venueName = (ri < city.restaurantNames.count)
                        ? city.restaurantNames[ri] : "Local Kitchen"

        let hi = Int.random(in: 0..<city.houseDoors.count)
        let h = city.houseDoors[hi]
        let addr = (hi < city.houseAddresses.count)
                   ? city.houseAddresses[hi]
                   : CityBuilder.randomAddress()

        let dist = distXZ(r, h)
        let pay = 5 + Int(dist / 30)
        offers.append(Offer(name: venueName,
                            pay: pay, restaurant: r, customer: h,
                            customerName: firstNames.randomElement()!,
                            address: addr))
    }

    func pushOffersToHUD() {
        let rows = offers.map { o in
            HUDOffer(title: "\(o.name)  →  \(o.customerName)  ·  $\(o.pay)",
                     subtitle: "\(o.address) · \(Int(distXZ(o.restaurant, o.customer)))m")
        }
        hud.setOffers(rows)
    }

    func accept(_ index: Int) {
        guard phase == .none, index < offers.count else { return }
        activeOrder = offers.remove(at: index)
        phase = .toRestaurant
        acceptedAt = CACurrentMediaTime()
        markerNode.position = activeOrder!.restaurant
        markerNode.isHidden = false
        pushOffersToHUD()
    }

    func currentTip() -> Int {
        guard let o = activeOrder else { return 0 }
        let maxTip = max(2, o.pay / 2)
        let elapsed = CACurrentMediaTime() - acceptedAt
        return max(0, maxTip - Int(elapsed / 12))
    }

    enum ActionKind: Equatable {
        case none, enter(Int), enterNPC(Int), talk(Int), exit, pickUp, deliver
        case boardTram, alightTram
    }

    func availableAction() -> ActionKind {
        if ridingTram != nil { return .alightTram }
        if activeVehicle != nil { return .exit }
        if let o = activeOrder {
            if phase == .toRestaurant,
               distXZ(playerNode.position, o.restaurant) < pickupRadius { return .pickUp }
            if phase == .toCustomer,
               distXZ(playerNode.position, o.customer) < deliverRadius { return .deliver }
        }

        var best: (Int, Float)? = nil
        for (i, v) in garage.enumerated() {
            let d = distXZ(playerNode.position, v.node.position)
            if d < v.enterRadius && (best == nil || d < best!.1) { best = (i, d) }
        }
        if let b = best { return .enter(b.0) }

        if nearbyBoardableTram() != nil { return .boardTram }

        for v in npcs.vehicles() {
            if distXZ(playerNode.position, SCNVector3(v.x, 0, v.z)) < 3.2 {
                return .enterNPC(v.index)
            }
        }

        if let pi = npcs.nearestPerson(to: playerNode.position, range: 3) {
            return .talk(pi)
        }
        return .none
    }

    func actionTitle(_ kind: ActionKind) -> String? {
        switch kind {
        case .none: return nil
        case .enter(let i):
            guard i >= 0 && i < garage.count else { return nil }
            return "Enter \(garage[i].displayName)"
        case .enterNPC: return "Take Car 🚗"
        case .boardTram: return "Board Streetcar 🚋"
        case .alightTram: return "Get Off 🚶"
        case .talk: return "Talk 👋"
        case .exit: return "Exit \(activeVehicle?.displayName ?? "Vehicle")"
        case .pickUp: return "Pick Up 🍔"
        case .deliver: return "Deliver 📦"
        }
    }

    func performAction() {
        switch availableAction() {
        case .enter(let i):
            guard i >= 0 && i < garage.count else { return }
            let v = garage[i]
            if v.rentalCost > 0 {
                guard money >= v.rentalCost else {
                    hud.flash("Need $\(v.rentalCost) to rent!")
                    return
                }
                money -= v.rentalCost
                hud.setMoney(money)
                hud.flash("Rented! -$\(v.rentalCost)")
            }
            activeVehicle = v

            playerNode.isHidden = !(v.type == .bike || v.type == .scooter)
            hud.setDriving(true)
            if v.type != .bike { SoundManager.shared.startEngine() }
            snapCamera()
        case .exit:
            guard let v = activeVehicle else { return }
            v.speed = 0
            let right = rightVec(v.heading)
            playerNode.position = SCNVector3(v.node.position.x + right.x * (v.radius + 1.2), 0,
                                             v.node.position.z + right.z * (v.radius + 1.2))
            playerHeading = v.heading
            resetRiderPose()
            SoundManager.shared.stopEngine()
            exitVehicleState()
            snapCamera()
        case .pickUp:
            phase = .toCustomer
            markerNode.position = activeOrder!.customer
            hud.flash("Picked up! 🍔 Keep it warm!")
        case .deliver:
            guard let o = activeOrder else { return }
            let tip = currentTip()
            deliveries += 1
            if tip > 0 { streak += 1 } else { streak = 0 }
            let bonus = streak >= 2 ? streak : 0
            money += o.pay + tip + bonus
            hud.setMoney(money)
            SoundManager.shared.delivered()

            let line = customerLines.randomElement() ?? "Thanks!"
            hud.showDialogue(speaker: o.customerName, line: line)

            var msg = "Delivered! +$\(o.pay) +$\(tip) tip"
            if bonus > 0 { msg += " · 🔥 +$\(bonus)" }
            hud.flash(msg)
            activeOrder = nil
            phase = .none
            markerNode.isHidden = true
            saveGame()
        case .boardTram:
            if let tram = nearbyBoardableTram() { boardTram(tram) }
        case .alightTram:
            alightTram()
        case .enterNPC(let idx):
            guard let (node, heading) = npcs.detachVehicle(at: idx) else { return }
            let v = PlayerVehicle(type: .car)
            v.node = node
            v.heading = heading
            v.spawnPos = node.position
            garage.append(v)
            activeVehicle = v
            playerNode.isHidden = true
            hud.setDriving(true)
            hud.flash("Borrowed a ride 🚗")
            snapCamera()
        case .talk(let idx):
            npcs.waveAt(index: idx, player: playerNode.position)
            playerWave()
        case .none:
            break
        }
    }

    var waveTimer: Float = 0
    func playerWave() {
        waveTimer = 1.2
        rightArm.removeAllActions()
        let up = SCNAction.rotateTo(x: -2.4, y: 0, z: 0, duration: 0.2)
        let waveA = SCNAction.rotateTo(x: -2.0, y: 0, z: 0.3, duration: 0.15)
        let waveB = SCNAction.rotateTo(x: -2.4, y: 0, z: -0.3, duration: 0.15)
        let down = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2)
        let flap = SCNAction.repeat(SCNAction.sequence([waveA, waveB]), count: 2)
        rightArm.runAction(SCNAction.sequence([up, flap, down]))
    }

    func pushOutOfNPCs() {
        let pr: Float = 0.5
        for o in npcs.solidObstacles() {
            let dx = playerNode.position.x - o.x
            let dz = playerNode.position.z - o.z
            let dist = sqrt(dx * dx + dz * dz)
            let minD = pr + o.r
            if dist < minD && dist > 0.001 {
                let nx = dx / dist, nz = dz / dist
                playerNode.position.x += nx * (minD - dist)
                playerNode.position.z += nz * (minD - dist)
            }
        }
    }

    @objc func step(_ link: CADisplayLink) {
        let dt = Float(min(0.05, link.targetTimestamp - link.timestamp))
        guard dt > 0, !paused else { return }

        let joy = hud.joystick
        if ridingTram != nil {

            updateRiding()
            npcs.update(dt: dt, playerPos: playerNode.position,
                        playerCarPos: SCNVector3(9999, 0, 9999))
            updateTrafficLights(playerPos: playerNode.position)
            updateCamera(dt: dt)
            updateHUDState()
            return
        }
        if let v = activeVehicle {
            updateVehicle(v, dt: dt, steer: Float(joy.dx))
            playerNode.position = v.node.position
            if v.type == .bike || v.type == .scooter { poseRider(on: v, dt: dt) }
        } else {
            updateWalk(dt: dt, joyX: Float(joy.dx), joyY: Float(joy.dy))
            pushOutOfNPCs()

            if vy != 0 || jumpY > 0 {
                vy -= 13 * dt
                jumpY = max(0, jumpY + vy * dt)
                if jumpY == 0 { vy = 0 }
            }
            playerNode.position.y = groundHeight(playerNode.position.x,
                                                 playerNode.position.z) + jumpY
            let targetScale: Float = crouching ? 0.62 : 1
            bodyGroup.scale.y += (targetScale - bodyGroup.scale.y) * min(1, 10 * dt)
        }
        animateCharacter(dt: dt)
        updateFares()
        updateTrafficLights(playerPos: playerNode.position)
        let vehiclePos = activeVehicle?.node.position ?? SCNVector3(9999, 0, 9999)
        npcs.update(dt: dt, playerPos: playerNode.position, playerCarPos: vehiclePos)
        checkCoins()
        updateCamera(dt: dt)
        updateHUDState()
    }

    func updateVehicle(_ v: PlayerVehicle, dt: Float, steer: Float) {
        if hud.gasDown {
            v.speed = min(v.maxSpeed, v.speed + v.accel * dt)
        } else if hud.brakeDown {
            v.speed = max(v.maxReverse, v.speed - v.brakePower * dt)
        } else {
            let decel = 7 * dt
            if v.speed > 0 { v.speed = max(0, v.speed - decel) }
            else { v.speed = min(0, v.speed + decel) }
        }
        let turnRate: Float = 1.9
        let speedFactor = max(-1, min(1, v.speed / 10))
        v.heading -= steer * turnRate * speedFactor * dt

        let fwd = forwardVec(v.heading)
        let delta = SIMD2<Float>(fwd.x * v.speed * dt, fwd.z * v.speed * dt)
        let resolved = resolveMove(from: v.node.position, delta: delta, radius: v.radius)
        if resolved.hitWall { v.speed *= 0.2 }
        v.node.position = resolved.pos
        v.node.eulerAngles.y = v.heading
        v.node.position.y = groundHeight(v.node.position.x, v.node.position.z)
        for w in v.wheels { w.eulerAngles.x -= v.speed * dt / 0.42 }
        SoundManager.shared.updateEngine(speed01: abs(v.speed) / v.maxSpeed)

        if abs(v.speed) > 6 {
            if npcs.knockDown(near: v.node.position, radius: v.radius + 0.5) {
                v.speed *= 0.6
                hud.flash("😱 Watch out!")
                streak = 0
            }
        }

        crashCooldown = max(0, crashCooldown - dt)
        if v.type != .bike, crashCooldown == 0, abs(v.speed) > 7 {
            for other in npcs.vehicles() {
                let dx = v.node.position.x - other.x
                let dz = v.node.position.z - other.z
                let dist = sqrt(dx * dx + dz * dz)
                let minD = (v.radius + other.radius) * 0.75
                if dist < minD {
                    let nx = dx / max(0.001, dist)
                    let nz = dz / max(0.001, dist)
                    v.node.position.x += nx * (minD - dist)
                    v.node.position.z += nz * (minD - dist)
                    v.speed *= 0.6
                    npcs.crashVehicle(at: other.index)
                    crashCooldown = 2.0
                    break
                }
            }
        }
    }

    func updateWalk(dt: Float, joyX: Float, joyY: Float) {
        let mag = min(1, sqrt(joyX * joyX + joyY * joyY))
        moveAmount = mag > 0.12 ? mag : 0
        guard moveAmount > 0 else { return }

        let fwd = forwardVec(camYaw)
        let right = rightVec(camYaw)
        var dir = SIMD2<Float>(fwd.x * joyY + right.x * joyX,
                               fwd.z * joyY + right.z * joyX)
        let len = max(0.0001, sqrt(dir.x * dir.x + dir.y * dir.y))
        dir /= len

        let targetHeading = atan2(-dir.x, -dir.y)
        playerHeading = lerpAngle(playerHeading, targetHeading, 1 - exp(-12 * dt))

        var speed = walkSpeed * mag
        if hud.sprintDown && !crouching { speed *= 1.8 }
        if crouching { speed *= 0.5 }
        let delta = dir * speed * dt
        let resolved = resolveMove(from: playerNode.position, delta: delta, radius: 0.5)
        playerNode.position = resolved.pos
        playerNode.eulerAngles.y = playerHeading
    }

    func animateCharacter(dt: Float) {
        guard activeVehicle == nil else { return }
        if waveTimer > 0 { waveTimer -= dt; return }
        if moveAmount > 0 {
            let sprinting = hud.sprintDown && !crouching
            walkPhase += dt * (sprinting ? 14 : 9) * moveAmount
            let sw = sin(walkPhase)
            let amp: Float = sprinting ? 0.95 : 0.7
            let swing = sw * amp * moveAmount

            leftArm.eulerAngles.x = swing
            rightArm.eulerAngles.x = -swing
            leftArm.eulerAngles.z = 0.06
            rightArm.eulerAngles.z = -0.06

            leftLeg.eulerAngles.x = -swing * 0.95
            rightLeg.eulerAngles.x = swing * 0.95

            bodyGroup.eulerAngles.y = -sw * 0.09 * moveAmount
            bodyGroup.eulerAngles.x = sprinting ? 0.13 : 0.04
            bodyGroup.position.y = abs(sin(walkPhase)) * (sprinting ? 0.07 : 0.045)
        } else {
            let k = 1 - exp(-10 * dt)
            leftArm.eulerAngles.x *= (1 - k)
            rightArm.eulerAngles.x *= (1 - k)
            leftLeg.eulerAngles.x *= (1 - k)
            rightLeg.eulerAngles.x *= (1 - k)
            bodyGroup.position.y *= (1 - k)
            bodyGroup.eulerAngles.y *= (1 - k)
            bodyGroup.eulerAngles.x *= (1 - k)

            idlePhase += dt * 1.6
            bodyGroup.position.y += sin(idlePhase) * 0.006
        }
    }

    struct CamParams { let dist: Float; let height: Float; let pitch: Float; let side: Float }

    func camParams() -> CamParams {
        if let v = activeVehicle {
            switch v.type {
            case .car:       return CamParams(dist: 8.5, height: 3.2, pitch: -0.17, side: 0)
            case .bike:      return CamParams(dist: 5.5, height: 2.5, pitch: -0.15, side: 0)
            case .scooter:   return CamParams(dist: 5.0, height: 2.4, pitch: -0.15, side: 0)
            }
        }
        if ridingTram != nil {
            return CamParams(dist: 11, height: 5.5, pitch: -0.28, side: 0)
        }
        if insideVenue(playerNode.position) || insideHouse(playerNode.position) {
            return CamParams(dist: 2.6, height: 5.2, pitch: -0.85, side: 0)
        }
        return CamParams(dist: 3.4, height: 1.95, pitch: -0.12, side: 0.55)
    }

    func insideVenue(_ p: SCNVector3) -> Bool {
        let pt = CGPoint(x: CGFloat(p.x), y: CGFloat(p.z))
        for v in city.venues where v.zone.contains(pt) { return true }
        return false
    }

    func insideHouse(_ p: SCNVector3) -> Bool {
        let pt = CGPoint(x: CGFloat(p.x), y: CGFloat(p.z))
        for zone in city.houseZones where zone.contains(pt) { return true }
        return false
    }

    func desiredCamPosition(yaw: Float, target: SCNVector3, p: CamParams) -> SCNVector3 {
        let fwd = forwardVec(yaw)
        let right = rightVec(yaw)
        return SCNVector3(target.x - fwd.x * p.dist + right.x * p.side,
                          p.height,
                          target.z - fwd.z * p.dist + right.z * p.side)
    }

    func updateCamera(dt: Float) {
        let targetYaw = activeVehicle?.heading ?? playerHeading
        camYaw = lerpAngle(camYaw, targetYaw,
                           1 - exp(-((activeVehicle != nil) ? 2.8 : 4.0) * dt))

        let target = activeVehicle?.node.position ?? playerNode.position
        let p = camParams()
        let desired = desiredCamPosition(yaw: camYaw, target: target, p: p)

        let k = 1 - exp(-10 * dt)
        camNode.position = SCNVector3(camNode.position.x + (desired.x - camNode.position.x) * k,
                                      camNode.position.y + (desired.y - camNode.position.y) * k,
                                      camNode.position.z + (desired.z - camNode.position.z) * k)
        camNode.eulerAngles = SCNVector3(p.pitch, camYaw, 0)
    }

    func snapCamera() {
        camYaw = activeVehicle?.heading ?? playerHeading
        let target = activeVehicle?.node.position ?? playerNode.position
        let p = camParams()
        camNode.position = desiredCamPosition(yaw: camYaw, target: target, p: p)
        camNode.eulerAngles = SCNVector3(p.pitch, camYaw, 0)
    }

    func updateHUDState() {
        let kind = availableAction()
        let title = actionTitle(kind)

        let status: String
        switch phase {
        case .none:
            status = "No active order — check the board"
        case .toRestaurant:
            status = "Pick up at \(activeOrder!.name) · tip $\(currentTip())"
        case .toCustomer:
            status = "Deliver to \(activeOrder!.customerName), \(activeOrder!.address) · tip $\(currentTip())"
        }

        var arrowAngle: CGFloat? = nil
        var arrowVisible = false
        if let o = activeOrder {
            let t = (phase == .toRestaurant) ? o.restaurant : o.customer
            let bearing = atan2(-(t.x - playerNode.position.x),
                                -(t.z - playerNode.position.z))
            arrowAngle = CGFloat(bearing - camYaw)
            arrowVisible = true
        }

        if title != lastActionTitle { lastActionTitle = title; hud.setAction(title) }
        if status != lastStatus { lastStatus = status; hud.setStatus(status) }

        let street = currentStreet(playerNode.position)
        if street != lastStreet { lastStreet = street; hud.setStreet(street) }
        hud.setArrow(angle: arrowAngle, visible: arrowVisible)

        let pickup = (phase == .toRestaurant) ? activeOrder?.restaurant : nil
        let drop = activeOrder?.customer
        let carV = garage.first { $0.type == .car }
        hud.updateMinimap(playerX: playerNode.position.x, playerZ: playerNode.position.z,
                          playerHeading: activeVehicle?.heading ?? playerHeading,
                          carX: carV?.node.position.x ?? 0,
                          carZ: carV?.node.position.z ?? 0,
                          pickupX: pickup?.x, pickupZ: pickup?.z,
                          dropX: drop?.x, dropZ: drop?.z)
    }

    var ridingTram: SCNNode?

    func nearbyBoardableTram() -> SCNNode? {
        guard activeVehicle == nil, ridingTram == nil else { return nil }
        return npcs.boardableTram(near: playerNode.position, radius: 5.5)
    }

    func boardTram(_ tram: SCNNode) {
        ridingTram = tram
        playerNode.isHidden = true
        hud.flash("🚋 All aboard!")
        SoundManager.shared.doors()
    }

    func alightTram() {
        guard let tram = ridingTram else { return }

        let right = rightVec(tram.eulerAngles.y)
        playerNode.position = SCNVector3(tram.position.x + right.x * 3.4, 0,
                                         tram.position.z + right.z * 3.4)
        playerHeading = tram.eulerAngles.y
        playerNode.isHidden = false
        ridingTram = nil
        hud.flash("👋 Watch your step!")
        snapCamera()
    }

    func updateRiding() {
        guard let tram = ridingTram else { return }
        playerNode.position = SCNVector3(tram.position.x, 0.9, tram.position.z)
        playerHeading = tram.eulerAngles.y
    }

    func tryJump() {
        guard activeVehicle == nil, jumpY == 0, !crouching, !paused else { return }
        vy = 5.6
    }

    func toggleCrouch() {
        guard activeVehicle == nil, !paused else { return }
        crouching.toggle()
    }

    func poseRider(on v: PlayerVehicle, dt: Float) {
        playerNode.isHidden = false
        playerNode.position = v.node.position
        playerNode.eulerAngles.y = v.heading
        playerHeading = v.heading
        if v.type == .bike {
            bodyGroup.position.y = 0.34
            leftArm.eulerAngles.x = -0.55
            rightArm.eulerAngles.x = -0.55
            if abs(v.speed) > 0.5 {
                ridePhase += v.speed * dt * 2.2
                leftLeg.eulerAngles.x = 0.9 + sin(ridePhase) * 0.45
                rightLeg.eulerAngles.x = 0.9 - sin(ridePhase) * 0.45
            } else {
                leftLeg.eulerAngles.x = 0.9
                rightLeg.eulerAngles.x = 0.9
            }
        } else {

            bodyGroup.position.y = 0.16
            leftArm.eulerAngles.x = -0.45
            rightArm.eulerAngles.x = -0.45
            leftLeg.eulerAngles.x = 0.12
            rightLeg.eulerAngles.x = -0.05
        }
    }

    func resetRiderPose() {
        bodyGroup.position.y = 0
        leftArm.eulerAngles.x = 0
        rightArm.eulerAngles.x = 0
        leftLeg.eulerAngles.x = 0
        rightLeg.eulerAngles.x = 0
    }

    func updateFares() {
        let now = CACurrentMediaTime()
        for i in waitingRiders.indices where !waitingRiders[i].node.isHidden {

            if npcs.boardableTram(near: waitingRiders[i].node.position,
                                  radius: 6.0) != nil {
                waitingRiders[i].node.isHidden = true
                waitingRiders[i].respawnAt = now + 25
            }
        }
        for i in waitingRiders.indices
        where waitingRiders[i].node.isHidden && waitingRiders[i].respawnAt > 0
              && now > waitingRiders[i].respawnAt {
            waitingRiders[i].node.isHidden = false
            waitingRiders[i].respawnAt = 0
        }
    }

    func groundHeight(_ x: Float, _ z: Float) -> Float {

        func onBlock(_ c: Float) -> Bool {
            let off = CityBuilder.total / 2
            let local = c + off - CityBuilder.roadW
            guard local >= 0 else { return false }
            let i = (local / CityBuilder.pitch).rounded(.down)
            guard i < Float(CityBuilder.blocks) else { return false }
            let center = CityBuilder.roadW + i * CityBuilder.pitch
                         + CityBuilder.blockSize / 2 - off
            return abs(c - center) <= (CityBuilder.blockSize + 2) / 2
        }
        return (onBlock(x) && onBlock(z)) ? 0.24 : 0
    }

    func currentStreet(_ p: SCNVector3) -> String {
        let off = CityBuilder.total / 2
        func nearest(_ v: Float, names: [String]) -> (String, Float) {
            var best = (names[0], Float.greatestFiniteMagnitude)
            for k in 0...CityBuilder.blocks {
                let c = Float(k) * CityBuilder.pitch + CityBuilder.roadW / 2 - off
                let d = abs(v - c)
                if d < best.1 && k < names.count { best = (names[k], d) }
            }
            return best
        }
        let ns = nearest(p.x, names: nsStreets)
        let ew = nearest(p.z, names: ewStreets)

        if ns.1 < 6 && ew.1 < 6 { return "\(ns.0) & \(ew.0)" }
        return ns.1 < ew.1 ? ns.0 : ew.0
    }

    struct MoveResult { let pos: SCNVector3; let hitWall: Bool }

    func resolveMove(from p: SCNVector3, delta: SIMD2<Float>, radius: Float) -> MoveResult {
        func blocked(_ x: Float, _ z: Float) -> Bool {
            if x < city.minBound || x > city.maxBound ||
               z < city.minBound || z > city.maxBound { return true }
            for r in city.buildingRects {
                let grown = r.insetBy(dx: CGFloat(-radius), dy: CGFloat(-radius))
                if grown.contains(CGPoint(x: CGFloat(x), y: CGFloat(z))) { return true }
            }
            return false
        }
        let nx = p.x + delta.x
        let nz = p.z + delta.y
        if !blocked(nx, nz) { return MoveResult(pos: SCNVector3(nx, p.y, nz), hitWall: false) }
        if !blocked(nx, p.z) { return MoveResult(pos: SCNVector3(nx, p.y, p.z), hitWall: true) }
        if !blocked(p.x, nz) { return MoveResult(pos: SCNVector3(p.x, p.y, nz), hitWall: true) }
        return MoveResult(pos: p, hitWall: true)
    }

    func forwardVec(_ h: Float) -> SIMD3<Float> { SIMD3(-sin(h), 0, -cos(h)) }
    func rightVec(_ h: Float) -> SIMD3<Float> { SIMD3(cos(h), 0, -sin(h)) }

    func distXZ(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = a.x - b.x, dz = a.z - b.z
        return sqrt(dx * dx + dz * dz)
    }

    func angleDiff(_ a: Float, _ b: Float) -> Float {
        var d = (b - a).truncatingRemainder(dividingBy: 2 * .pi)
        if d > .pi { d -= 2 * .pi }
        if d < -.pi { d += 2 * .pi }
        return d
    }

    func lerpAngle(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + angleDiff(a, b) * t
    }
}

final class TrafficLight {
    let node = SCNNode()
    let lamps: [SCNNode]
    let offset: Double

    private static let poleGeo: SCNGeometry = {
        let g = SCNCylinder(radius: 0.08, height: 4.4)
        g.firstMaterial?.diffuse.contents = UIColor(white: 0.2, alpha: 1)
        g.firstMaterial?.lightingModel = .lambert
        return g
    }()
    private static let housingGeo: SCNGeometry = {
        let g = SCNBox(width: 0.36, height: 1.0, length: 0.3, chamferRadius: 0.05)
        g.firstMaterial?.diffuse.contents = UIColor(white: 0.12, alpha: 1)
        g.firstMaterial?.lightingModel = .lambert
        return g
    }()

    init(at pos: SCNVector3, offset: Double) {
        self.offset = offset

        let pole = SCNNode(geometry: TrafficLight.poleGeo)
        pole.position = SCNVector3(0, 2.2, 0)
        node.addChildNode(pole)

        let housing = SCNNode(geometry: TrafficLight.housingGeo)
        housing.position = SCNVector3(0, 4.6, 0)
        node.addChildNode(housing)

        var built: [SCNNode] = []
        for dy: Float in [0.32, 0, -0.32] {
            let sphere = SCNSphere(radius: 0.11)
            sphere.segmentCount = 8
            sphere.firstMaterial?.diffuse.contents = UIColor(white: 0.1, alpha: 1)
            sphere.firstMaterial?.lightingModel = .lambert
            let lamp = SCNNode(geometry: sphere)
            lamp.position = SCNVector3(0, 4.6 + dy, 0.16)
            node.addChildNode(lamp)
            built.append(lamp)
        }
        lamps = built
        node.position = pos
    }

    func update(time: Double) {
        let phase = (time + offset).truncatingRemainder(dividingBy: 10)
        let active = phase < 4.5 ? 2 : (phase < 6 ? 1 : 0)
        let colors: [UIColor] = [.red, .yellow, .green]
        for (i, lamp) in lamps.enumerated() {
            lamp.geometry?.firstMaterial?.emission.contents =
                (i == active) ? colors[i] : UIColor(white: 0.05, alpha: 1)
        }
    }
}
