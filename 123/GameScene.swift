import SpriteKit

struct Offer {
    let id = UUID()
    let restaurantName: String
    let pay: Int
    let restaurant: CGPoint
    let customer: CGPoint
}

enum OrderPhase {
    case none
    case toRestaurant
    case toCustomer
}

enum PlayerMode { case walking, driving }

class GameScene: SKScene {

    let tileSize: CGFloat = 64
    let walkSpeed: CGFloat = 150
    let driveSpeed: CGFloat = 360
    let interactRadius: CGFloat = 110

    var player: SKShapeNode!
    var car: SKShapeNode!
    var restaurantTiles: [CGPoint] = []
    var houseTiles: [CGPoint] = []
    var marker: SKShapeNode!

    var cam: SKCameraNode!
    var moneyLabel: SKLabelNode!
    var statusLabel: SKLabelNode!
    var actionButton: SKShapeNode!
    var actionLabel: SKLabelNode!
    var ordersButton: SKShapeNode!
    var ordersButtonLabel: SKLabelNode!
    var ordersPanel: SKNode!

    var joystickBase: SKShapeNode?
    var joystickKnob: SKShapeNode?
    var joystickTouch: UITouch?
    var joystickVector = CGVector.zero

    var mode: PlayerMode = .walking
    var phase: OrderPhase = .none
    var offers: [Offer] = []
    var activeOffer: Offer?
    var money = 0
    var acceptedAt: TimeInterval = 0
    var currentTime: TimeInterval = 0
    var panelOpen = false

    let catPlayer: UInt32 = 0x1 << 0
    let catWall:   UInt32 = 0x1 << 1
    let catCar:    UInt32 = 0x1 << 2

    let map = [
        "WWWWWWWWWWWWWWWWWWWWWW",
        "W....................W",
        "W.RRRRRRRRRRRRRRRRRR.W",
        "W.R................R.W",
        "W.R.BB.FF.BB.FF.BB.R.W",
        "W.R.BB.FF.BB.FF.BB.R.W",
        "W.R................R.W",
        "W.RRRRRRRRRRRRRRRRRR.W",
        "W.R................R.W",
        "W.R.HH.BB.HH.BB.HH.R.W",
        "W.R.HH.BB.HH.BB.HH.R.W",
        "W.R................R.W",
        "W.RRRRRRRRRRRRRRRRRR.W",
        "W.R................R.W",
        "W.R.FF.HH.BB.HH.FF.R.W",
        "W.R.FF.HH.BB.HH.FF.R.W",
        "W.R................R.W",
        "W.RRRRRRRRRRRRRRRRRR.W",
        "W....................W",
        "WWWWWWWWWWWWWWWWWWWWWW",
    ]

    let restaurantNames = ["Burger Barn", "Pizza Palace", "Sushi Spot",
                           "Taco Town", "Noodle Nook", "Curry Corner"]

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.55, green: 0.75, blue: 0.45, alpha: 1)
        view.isMultipleTouchEnabled = true
        physicsWorld.gravity = .zero

        buildWorld()
        buildPlayerAndCar()
        buildMarker()
        buildCameraAndHUD()
        spawnInitialOffers()

        run(.repeatForever(.sequence([
            .wait(forDuration: 6),
            .run { [weak self] in self?.refillOffers() }
        ])))
    }

    func tileCenter(col: Int, row: Int) -> CGPoint {

        let rows = map.count
        return CGPoint(x: (CGFloat(col) + 0.5) * tileSize,
                       y: (CGFloat(rows - 1 - row) + 0.5) * tileSize)
    }

    func buildWorld() {
        for (row, line) in map.enumerated() {
            for (col, ch) in line.enumerated() {
                let pos = tileCenter(col: col, row: row)
                switch ch {
                case "R":
                    let road = SKSpriteNode(color: SKColor(white: 0.35, alpha: 1),
                                            size: CGSize(width: tileSize, height: tileSize))
                    road.position = pos
                    road.zPosition = -10
                    addChild(road)
                case "B", "F", "H", "W":
                    let color: SKColor
                    switch ch {
                    case "F": color = SKColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1)
                    case "H": color = SKColor(red: 0.25, green: 0.55, blue: 0.85, alpha: 1)
                    case "W": color = SKColor(white: 0.15, alpha: 1)
                    default:  color = SKColor(white: 0.55, alpha: 1)
                    }
                    let b = SKSpriteNode(color: color,
                                         size: CGSize(width: tileSize - 4, height: tileSize - 4))
                    b.position = pos
                    b.zPosition = 5
                    b.physicsBody = SKPhysicsBody(rectangleOf: b.size)
                    b.physicsBody?.isDynamic = false
                    b.physicsBody?.categoryBitMask = catWall
                    addChild(b)

                    if ch == "F" { restaurantTiles.append(pos) }
                    if ch == "H" { houseTiles.append(pos) }
                default:
                    break
                }
            }
        }
    }

    func buildPlayerAndCar() {

        player = SKShapeNode(circleOfRadius: 14)
        player.fillColor = SKColor(red: 0.95, green: 0.85, blue: 0.3, alpha: 1)
        player.strokeColor = .black
        player.lineWidth = 2
        player.position = tileCenter(col: 3, row: 2)
        player.zPosition = 20
        player.physicsBody = SKPhysicsBody(circleOfRadius: 14)
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.linearDamping = 8
        player.physicsBody?.categoryBitMask = catPlayer
        player.physicsBody?.collisionBitMask = catWall | catCar
        addChild(player)

        car = SKShapeNode(rectOf: CGSize(width: 34, height: 58), cornerRadius: 8)
        car.fillColor = SKColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1)
        car.strokeColor = .black
        car.lineWidth = 2

        let glass = SKShapeNode(rectOf: CGSize(width: 24, height: 12), cornerRadius: 3)
        glass.fillColor = SKColor(red: 0.6, green: 0.85, blue: 1, alpha: 1)
        glass.strokeColor = .clear
        glass.position = CGPoint(x: 0, y: 12)
        car.addChild(glass)

        car.position = tileCenter(col: 5, row: 2)
        car.zPosition = 15
        car.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 34, height: 58))
        car.physicsBody?.allowsRotation = false
        car.physicsBody?.linearDamping = 6
        car.physicsBody?.categoryBitMask = catCar
        car.physicsBody?.collisionBitMask = catWall
        addChild(car)
    }

    func buildMarker() {

        let path = CGMutablePath()
        path.move(to: CGPoint(x: -14, y: 24))
        path.addLine(to: CGPoint(x: 14, y: 24))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        marker = SKShapeNode(path: path)
        marker.fillColor = .yellow
        marker.strokeColor = .black
        marker.lineWidth = 2
        marker.zPosition = 50
        marker.isHidden = true
        marker.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 12, duration: 0.4),
            .moveBy(x: 0, y: -12, duration: 0.4)
        ])))
        addChild(marker)
    }

    func buildCameraAndHUD() {
        cam = SKCameraNode()
        cam.setScale(1.3)
        camera = cam
        addChild(cam)

        let w = size.width, h = size.height

        moneyLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        moneyLabel.fontSize = 26
        moneyLabel.fontColor = .white
        moneyLabel.horizontalAlignmentMode = .left
        moneyLabel.position = CGPoint(x: -w/2 + 24, y: h/2 - 50)
        moneyLabel.zPosition = 100
        moneyLabel.text = "$0"
        cam.addChild(moneyLabel)

        statusLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        statusLabel.fontSize = 18
        statusLabel.fontColor = .white
        statusLabel.position = CGPoint(x: 0, y: h/2 - 50)
        statusLabel.zPosition = 100
        statusLabel.text = "Open the order board to start earning"
        cam.addChild(statusLabel)

        actionButton = SKShapeNode(rectOf: CGSize(width: 170, height: 60), cornerRadius: 14)
        actionButton.fillColor = SKColor(red: 0.15, green: 0.65, blue: 0.35, alpha: 0.95)
        actionButton.strokeColor = .white
        actionButton.lineWidth = 2
        actionButton.position = CGPoint(x: w/2 - 110, y: -h/2 + 80)
        actionButton.zPosition = 100
        actionButton.name = "action"
        actionLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        actionLabel.fontSize = 20
        actionLabel.fontColor = .white
        actionLabel.verticalAlignmentMode = .center
        actionLabel.name = "action"
        actionButton.addChild(actionLabel)
        actionButton.isHidden = true
        cam.addChild(actionButton)

        ordersButton = SKShapeNode(rectOf: CGSize(width: 130, height: 44), cornerRadius: 12)
        ordersButton.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 0.95)
        ordersButton.strokeColor = .white
        ordersButton.lineWidth = 2
        ordersButton.position = CGPoint(x: w/2 - 90, y: h/2 - 44)
        ordersButton.zPosition = 100
        ordersButton.name = "ordersToggle"
        ordersButtonLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        ordersButtonLabel.fontSize = 17
        ordersButtonLabel.fontColor = .white
        ordersButtonLabel.verticalAlignmentMode = .center
        ordersButtonLabel.name = "ordersToggle"
        ordersButtonLabel.text = "Orders (0)"
        ordersButton.addChild(ordersButtonLabel)
        cam.addChild(ordersButton)

        ordersPanel = SKNode()
        ordersPanel.zPosition = 110
        ordersPanel.isHidden = true
        cam.addChild(ordersPanel)
    }

    func spawnInitialOffers() {
        for _ in 0..<3 { generateOffer() }
        rebuildPanel()
    }

    func refillOffers() {
        guard offers.count < 3 else { return }
        generateOffer()
        rebuildPanel()
    }

    func generateOffer() {
        guard let r = restaurantTiles.randomElement(),
              let h = houseTiles.randomElement() else { return }
        let dist = hypot(r.x - h.x, r.y - h.y)
        let pay = 5 + Int(dist / 150)
        offers.append(Offer(restaurantName: restaurantNames.randomElement()!,
                            pay: pay, restaurant: r, customer: h))
    }

    func rebuildPanel() {
        ordersButtonLabel.text = "Orders (\(offers.count))"
        ordersPanel.removeAllChildren()

        let w = size.width, h = size.height
        let panelW: CGFloat = 320
        let rowH: CGFloat = 64
        let bg = SKShapeNode(rectOf: CGSize(width: panelW, height: rowH * 3 + 60),
                             cornerRadius: 16)
        bg.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.14, alpha: 0.95)
        bg.strokeColor = .white
        bg.position = CGPoint(x: w/2 - panelW/2 - 20, y: h/2 - 220)
        ordersPanel.addChild(bg)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "Available Orders"
        title.fontSize = 18
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: rowH * 1.5 + 4)
        bg.addChild(title)

        if offers.isEmpty {
            let empty = SKLabelNode(fontNamed: "AvenirNext-Medium")
            empty.text = "No orders right now…"
            empty.fontSize = 16
            empty.fontColor = .lightGray
            bg.addChild(empty)
        }

        for (i, offer) in offers.enumerated() {
            let row = SKShapeNode(rectOf: CGSize(width: panelW - 24, height: rowH - 10),
                                  cornerRadius: 10)
            row.fillColor = SKColor(red: 0.2, green: 0.25, blue: 0.32, alpha: 1)
            row.strokeColor = .clear
            row.position = CGPoint(x: 0, y: rowH * 1.0 - CGFloat(i) * rowH - 10)
            row.name = "offer_\(i)"
            bg.addChild(row)

            let dist = Int(hypot(offer.restaurant.x - offer.customer.x,
                                 offer.restaurant.y - offer.customer.y))
            let l1 = SKLabelNode(fontNamed: "AvenirNext-Bold")
            l1.text = "\(offer.restaurantName)  —  $\(offer.pay) + tip"
            l1.fontSize = 16
            l1.fontColor = .white
            l1.position = CGPoint(x: 0, y: 4)
            l1.name = "offer_\(i)"
            row.addChild(l1)

            let l2 = SKLabelNode(fontNamed: "AvenirNext-Medium")
            l2.text = "trip ≈ \(dist)m · tap to accept"
            l2.fontSize = 13
            l2.fontColor = .lightGray
            l2.position = CGPoint(x: 0, y: -16)
            l2.name = "offer_\(i)"
            row.addChild(l2)
        }
    }

    func accept(offerIndex: Int) {
        guard phase == .none, offerIndex < offers.count else { return }
        activeOffer = offers.remove(at: offerIndex)
        phase = .toRestaurant
        acceptedAt = currentTime
        panelOpen = false
        ordersPanel.isHidden = true
        marker.isHidden = false
        rebuildPanel()
    }

    func currentTip() -> Int {
        guard let offer = activeOffer else { return 0 }
        let maxTip = max(2, offer.pay / 2)
        let elapsed = currentTime - acceptedAt
        return max(0, maxTip - Int(elapsed / 10))
    }

    enum ActionKind { case none, enterCar, exitCar, pickUp, deliver }

    func availableAction() -> ActionKind {
        if mode == .driving { return .exitCar }

        if let offer = activeOffer {
            if phase == .toRestaurant,
               distance(player.position, offer.restaurant) < interactRadius {
                return .pickUp
            }
            if phase == .toCustomer,
               distance(player.position, offer.customer) < interactRadius {
                return .deliver
            }
        }
        if distance(player.position, car.position) < interactRadius * 0.8 {
            return .enterCar
        }
        return .none
    }

    func performAction() {
        switch availableAction() {
        case .enterCar:
            mode = .driving
            player.isHidden = true
            player.physicsBody?.isDynamic = false
        case .exitCar:
            mode = .walking
            car.physicsBody?.velocity = .zero
            player.position = CGPoint(x: car.position.x + 45, y: car.position.y)
            player.isHidden = false
            player.physicsBody?.isDynamic = true
        case .pickUp:
            phase = .toCustomer
            flash(text: "Picked up! 🍔 Deliver it fresh!")
        case .deliver:
            guard let offer = activeOffer else { return }
            let tip = currentTip()
            money += offer.pay + tip
            moneyLabel.text = "$\(money)"
            flash(text: "Delivered! +$\(offer.pay) pay, +$\(tip) tip")
            activeOffer = nil
            phase = .none
            marker.isHidden = true
        case .none:
            break
        }
    }

    func flash(text: String) {
        let l = SKLabelNode(fontNamed: "AvenirNext-Bold")
        l.text = text
        l.fontSize = 24
        l.fontColor = .yellow
        l.position = CGPoint(x: 0, y: 40)
        l.zPosition = 200
        cam.addChild(l)
        l.run(.sequence([.wait(forDuration: 1.6),
                         .fadeOut(withDuration: 0.4),
                         .removeFromParent()]))
    }

    func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let camLoc = touch.location(in: cam)
            let hit = cam.nodes(at: camLoc)

            if hit.contains(where: { $0.name == "action" }) {
                performAction()
                continue
            }
            if hit.contains(where: { $0.name == "ordersToggle" }) {
                panelOpen.toggle()
                ordersPanel.isHidden = !panelOpen
                continue
            }
            var tappedOffer = false
            for node in hit {
                if let name = node.name, name.hasPrefix("offer_"),
                   let idx = Int(name.dropFirst(6)) {
                    accept(offerIndex: idx)
                    tappedOffer = true
                    break
                }
            }
            if tappedOffer { continue }

            if joystickTouch == nil && camLoc.x < 0 {
                joystickTouch = touch
                let base = SKShapeNode(circleOfRadius: 55)
                base.strokeColor = SKColor(white: 1, alpha: 0.5)
                base.lineWidth = 3
                base.position = camLoc
                base.zPosition = 150
                cam.addChild(base)
                let knob = SKShapeNode(circleOfRadius: 26)
                knob.fillColor = SKColor(white: 1, alpha: 0.6)
                knob.strokeColor = .clear
                knob.position = camLoc
                knob.zPosition = 151
                cam.addChild(knob)
                joystickBase = base
                joystickKnob = knob
                joystickVector = .zero
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let jt = joystickTouch, touches.contains(jt),
              let base = joystickBase, let knob = joystickKnob else { return }
        let loc = jt.location(in: cam)
        var dx = loc.x - base.position.x
        var dy = loc.y - base.position.y
        let len = max(1, hypot(dx, dy))
        let capped = min(len, 55)
        dx = dx / len * capped
        dy = dy / len * capped
        knob.position = CGPoint(x: base.position.x + dx, y: base.position.y + dy)
        joystickVector = CGVector(dx: dx / 55, dy: dy / 55)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endJoystick(if: touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endJoystick(if: touches)
    }

    func endJoystick(if touches: Set<UITouch>) {
        guard let jt = joystickTouch, touches.contains(jt) else { return }
        joystickTouch = nil
        joystickBase?.removeFromParent()
        joystickKnob?.removeFromParent()
        joystickBase = nil
        joystickKnob = nil
        joystickVector = .zero
    }

    override func update(_ time: TimeInterval) {
        currentTime = time

        let controlled: SKShapeNode = (mode == .driving) ? car : player
        let speed: CGFloat = (mode == .driving) ? driveSpeed : walkSpeed
        controlled.physicsBody?.velocity = CGVector(dx: joystickVector.dx * speed,
                                                    dy: joystickVector.dy * speed)

        if mode == .driving, let v = car.physicsBody?.velocity,
           hypot(v.dx, v.dy) > 20 {
            car.zRotation = atan2(v.dy, v.dx) - .pi / 2
        }
        if mode == .driving { player.position = car.position }

        cam.position = controlled.position

        if let offer = activeOffer {
            let target = (phase == .toRestaurant) ? offer.restaurant : offer.customer
            marker.position = CGPoint(x: target.x, y: target.y + 40)
        }

        switch phase {
        case .none:
            statusLabel.text = "No active order — check the board"
        case .toRestaurant:
            statusLabel.text = "Pick up at \(activeOffer!.restaurantName) (walk in!) · tip $\(currentTip())"
        case .toCustomer:
            statusLabel.text = "Deliver to the blue house! · tip $\(currentTip())"
        }

        switch availableAction() {
        case .none:
            actionButton.isHidden = true
        case .enterCar:
            actionButton.isHidden = false; actionLabel.text = "Enter Car 🚗"
        case .exitCar:
            actionButton.isHidden = false; actionLabel.text = "Exit Car 🚶"
        case .pickUp:
            actionButton.isHidden = false; actionLabel.text = "Pick Up 🍔"
        case .deliver:
            actionButton.isHidden = false; actionLabel.text = "Deliver 📦"
        }
    }
}
