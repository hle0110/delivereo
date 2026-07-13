import SpriteKit

struct HUDOffer {
    let title: String
    let subtitle: String
}

final class HUDScene: SKScene {

    private(set) var joystick = CGVector.zero
    private(set) var gasDown = false
    private(set) var brakeDown = false

    var onAction: (() -> Void)?
    var onOfferSelected: ((Int) -> Void)?

    private var moneyLabel: SKLabelNode!
    private var statusLabel: SKLabelNode!
    private var statusBG: SKShapeNode!
    private var arrow: SKShapeNode!
    private var distanceLabel: SKLabelNode!
    private var actionButton: SKShapeNode!
    private var actionLabel: SKLabelNode!
    private var gasPedal: SKShapeNode!
    private var brakePedal: SKShapeNode!
    private var ordersButton: SKShapeNode!
    private var ordersButtonLabel: SKLabelNode!
    private var hintLabel: SKLabelNode!
    private var panel: SKNode!

    private var joyTouch: UITouch?
    private var joyBase: SKShapeNode?
    private var joyKnob: SKShapeNode?
    private var gasTouch: UITouch?
    private var brakeTouch: UITouch?

    private var panelOpen = false
    private var offers: [HUDOffer] = []

    private var minimapRoot: SKNode!
    private var mapSprite: SKSpriteNode?
    private var playerArrow: SKShapeNode!
    private var carDot: SKShapeNode!
    private var pickupDot: SKShapeNode!
    private var dropDot: SKShapeNode!
    private var mapCrop: SKCropNode!
    private var worldMin: Float = -120
    private var worldMax: Float = 120
    private var zoom: CGFloat = 2.6
    private let mapSize: CGFloat = 78

    private var menuRoot: SKNode!
    private var lastMenu: (String, String?, [(String, String)])?
    private var pauseButton: SKShapeNode!
    private var doorsButton: SKShapeNode!
    private var isTransit = false
    var onPause: (() -> Void)?
    var onMenuButton: ((String) -> Void)?
    var onDoors: (() -> Void)?
    var onHonk: (() -> Void)?
    private var honkButton: SKShapeNode!
    private var exitButton: SKShapeNode!

    private var dialogueBG: SKShapeNode!
    private var dialogueName: SKLabelNode!
    private var dialogueLine: SKLabelNode!

    private var streetLabel: SKLabelNode!
    private var streetBG: SKShapeNode!

    private var sprintButton: SKShapeNode!
    private var jumpButton: SKShapeNode!
    private var crouchButton: SKShapeNode!
    private var sprintTouch: UITouch?
    private(set) var sprintDown = false
    var onJump: (() -> Void)?
    var onCrouch: (() -> Void)?

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        isUserInteractionEnabled = true
        build()
        layout()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard moneyLabel != nil else { return }
        layout()

        if let m = lastMenu, !menuRoot.isHidden {
            showMenu(title: m.0, subtitle: m.1, buttons: m.2)
        }
    }

    private func build() {
        moneyLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        moneyLabel.fontSize = 30
        moneyLabel.fontColor = .white
        moneyLabel.horizontalAlignmentMode = .left
        moneyLabel.text = "$0"
        moneyLabel.zPosition = 100
        addChild(moneyLabel)

        statusBG = SKShapeNode(rectOf: CGSize(width: 460, height: 34), cornerRadius: 17)
        statusBG.fillColor = SKColor(white: 0, alpha: 0.45)
        statusBG.strokeColor = .clear
        statusBG.zPosition = 99
        addChild(statusBG)

        statusLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        statusLabel.fontSize = 16
        statusLabel.fontColor = .white
        statusLabel.verticalAlignmentMode = .center
        statusLabel.zPosition = 100
        statusLabel.text = "Welcome to the city!"
        addChild(statusLabel)

        streetBG = SKShapeNode(rectOf: CGSize(width: 260, height: 30), cornerRadius: 15)
        streetBG.fillColor = SKColor(red: 0.1, green: 0.12, blue: 0.2, alpha: 0.8)
        streetBG.strokeColor = SKColor(red: 0.95, green: 0.85, blue: 0.4, alpha: 0.9)
        streetBG.lineWidth = 1.5
        streetBG.zPosition = 99
        streetBG.isHidden = true
        addChild(streetBG)
        streetLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        streetLabel.fontSize = 15
        streetLabel.fontColor = SKColor(red: 0.98, green: 0.9, blue: 0.5, alpha: 1)
        streetLabel.verticalAlignmentMode = .center
        streetLabel.zPosition = 100
        streetLabel.isHidden = true
        addChild(streetLabel)

        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: 16))
        p.addLine(to: CGPoint(x: 11, y: -10))
        p.addLine(to: CGPoint(x: 0, y: -4))
        p.addLine(to: CGPoint(x: -11, y: -10))
        p.closeSubpath()
        arrow = SKShapeNode(path: p)
        arrow.fillColor = .yellow
        arrow.strokeColor = .black
        arrow.lineWidth = 1.5
        arrow.zPosition = 100
        arrow.isHidden = true
        addChild(arrow)

        distanceLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        distanceLabel.fontSize = 15
        distanceLabel.fontColor = .yellow
        distanceLabel.horizontalAlignmentMode = .center
        distanceLabel.zPosition = 100
        distanceLabel.isHidden = true
        addChild(distanceLabel)

        actionButton = SKShapeNode(rectOf: CGSize(width: 150, height: 50), cornerRadius: 13)
        actionButton.fillColor = SKColor(red: 0.15, green: 0.68, blue: 0.35, alpha: 0.95)
        actionButton.strokeColor = .white
        actionButton.lineWidth = 2.5
        actionButton.name = "action"
        actionButton.zPosition = 100
        actionLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        actionLabel.fontSize = 16
        actionLabel.fontColor = .white
        actionLabel.verticalAlignmentMode = .center
        actionLabel.name = "action"
        actionButton.addChild(actionLabel)
        actionButton.isHidden = true
        addChild(actionButton)

        gasPedal = iconPedal(kind: "gas",
                             color: SKColor(red: 0.15, green: 0.62, blue: 0.32, alpha: 0.92),
                             name: "gas")
        brakePedal = iconPedal(kind: "brake",
                               color: SKColor(red: 0.72, green: 0.16, blue: 0.16, alpha: 0.92),
                               name: "brake")
        gasPedal.isHidden = true
        brakePedal.isHidden = true
        addChild(gasPedal)
        addChild(brakePedal)

        ordersButton = SKShapeNode(rectOf: CGSize(width: 140, height: 48), cornerRadius: 12)
        ordersButton.fillColor = SKColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 0.95)
        ordersButton.strokeColor = .white
        ordersButton.lineWidth = 2
        ordersButton.name = "ordersToggle"
        ordersButton.zPosition = 100
        ordersButtonLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        ordersButtonLabel.fontSize = 17
        ordersButtonLabel.fontColor = .white
        ordersButtonLabel.verticalAlignmentMode = .center
        ordersButtonLabel.name = "ordersToggle"
        ordersButtonLabel.text = "Orders (0)"
        ordersButton.addChild(ordersButtonLabel)
        addChild(ordersButton)

        hintLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        hintLabel.fontSize = 15
        hintLabel.fontColor = SKColor(white: 1, alpha: 0.85)
        hintLabel.text = "Drag on the LEFT side to move · tap Orders to start"
        hintLabel.zPosition = 100
        addChild(hintLabel)
        hintLabel.run(.sequence([.wait(forDuration: 8), .fadeOut(withDuration: 1),
                                 .removeFromParent()]))

        panel = SKNode()
        panel.zPosition = 110
        panel.isHidden = true
        addChild(panel)

        minimapRoot = SKNode()
        minimapRoot.zPosition = 100
        let radius = mapSize / 2
        let mapFrame = SKShapeNode(circleOfRadius: radius + 5)
        mapFrame.fillColor = SKColor(white: 0, alpha: 0.4)
        mapFrame.strokeColor = SKColor(white: 1, alpha: 0.85)
        mapFrame.lineWidth = 3
        mapFrame.zPosition = 0
        minimapRoot.addChild(mapFrame)

        mapCrop = SKCropNode()
        let mask = SKShapeNode(circleOfRadius: radius)
        mask.fillColor = .white
        mask.strokeColor = .clear
        mapCrop.maskNode = mask
        mapCrop.zPosition = 1
        minimapRoot.addChild(mapCrop)

        let ap = CGMutablePath()
        ap.move(to: CGPoint(x: 0, y: 7))
        ap.addLine(to: CGPoint(x: 5, y: -5))
        ap.addLine(to: CGPoint(x: -5, y: -5))
        ap.closeSubpath()
        playerArrow = SKShapeNode(path: ap)
        playerArrow.fillColor = .white
        playerArrow.strokeColor = .black
        playerArrow.lineWidth = 1
        playerArrow.zPosition = 3
        minimapRoot.addChild(playerArrow)

        carDot = SKShapeNode(circleOfRadius: 4)
        carDot.fillColor = .red
        carDot.strokeColor = .white
        carDot.zPosition = 2
        minimapRoot.addChild(carDot)

        pickupDot = SKShapeNode(rectOf: CGSize(width: 9, height: 9), cornerRadius: 2)
        pickupDot.fillColor = SKColor.orange
        pickupDot.strokeColor = .white
        pickupDot.zPosition = 2
        pickupDot.isHidden = true
        minimapRoot.addChild(pickupDot)

        dropDot = SKShapeNode(circleOfRadius: 5)
        dropDot.fillColor = .yellow
        dropDot.strokeColor = .black
        dropDot.zPosition = 2
        dropDot.isHidden = true
        minimapRoot.addChild(dropDot)

        addChild(minimapRoot)

        pauseButton = SKShapeNode(circleOfRadius: 24)
        pauseButton.fillColor = SKColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 0.95)
        pauseButton.strokeColor = .white
        pauseButton.lineWidth = 2
        pauseButton.name = "pause"
        pauseButton.zPosition = 100
        let pl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        pl.text = "II"
        pl.fontSize = 18
        pl.fontColor = .white
        pl.verticalAlignmentMode = .center
        pl.name = "pause"
        pauseButton.addChild(pl)
        addChild(pauseButton)

        doorsButton = SKShapeNode(circleOfRadius: 52)
        doorsButton.fillColor = SKColor(red: 0.85, green: 0.65, blue: 0.1, alpha: 0.92)
        doorsButton.strokeColor = .white
        doorsButton.lineWidth = 3
        doorsButton.name = "doors"
        doorsButton.zPosition = 100
        let dl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        dl.text = "DOORS"
        dl.fontSize = 15
        dl.fontColor = .white
        dl.verticalAlignmentMode = .center
        dl.name = "doors"
        doorsButton.addChild(dl)
        doorsButton.isHidden = true
        addChild(doorsButton)

        sprintButton = pedal(text: "SPRINT",
                             color: SKColor(red: 0.2, green: 0.4, blue: 0.75, alpha: 0.92),
                             name: "sprint")
        addChild(sprintButton)
        jumpButton = pedal(text: "JUMP",
                           color: SKColor(red: 0.4, green: 0.3, blue: 0.7, alpha: 0.92),
                           name: "jump")
        jumpButton.setScale(0.9)
        addChild(jumpButton)
        crouchButton = pedal(text: "CROUCH",
                             color: SKColor(red: 0.35, green: 0.35, blue: 0.4, alpha: 0.92),
                             name: "crouch")
        crouchButton.setScale(0.85)
        addChild(crouchButton)

        honkButton = iconPedal(kind: "horn",
                               color: SKColor(red: 0.85, green: 0.6, blue: 0.1, alpha: 0.92),
                               name: "honk")
        honkButton.setScale(0.9)
        honkButton.isHidden = true
        addChild(honkButton)

        dialogueBG = SKShapeNode(rectOf: CGSize(width: 420, height: 76), cornerRadius: 16)
        dialogueBG.fillColor = SKColor(red: 0.08, green: 0.09, blue: 0.14, alpha: 0.95)
        dialogueBG.strokeColor = SKColor(red: 1, green: 0.8, blue: 0.3, alpha: 1)
        dialogueBG.lineWidth = 2
        dialogueBG.zPosition = 190
        dialogueBG.isHidden = true
        addChild(dialogueBG)
        dialogueName = SKLabelNode(fontNamed: "AvenirNext-Bold")
        dialogueName.fontSize = 15
        dialogueName.fontColor = SKColor(red: 1, green: 0.85, blue: 0.4, alpha: 1)
        dialogueName.zPosition = 191
        dialogueName.isHidden = true
        addChild(dialogueName)
        dialogueLine = SKLabelNode(fontNamed: "AvenirNext-Medium")
        dialogueLine.fontSize = 16
        dialogueLine.fontColor = .white
        dialogueLine.zPosition = 191
        dialogueLine.isHidden = true
        addChild(dialogueLine)

        exitButton = iconPedal(kind: "door",
                               color: SKColor(red: 0.35, green: 0.4, blue: 0.5, alpha: 0.94),
                               name: "action")
        exitButton.setScale(0.95)
        exitButton.isHidden = true
        addChild(exitButton)

        menuRoot = SKNode()
        menuRoot.zPosition = 300
        menuRoot.isHidden = true
        addChild(menuRoot)
    }

    private func pedal(text: String, color: SKColor, name: String) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: 25)
        node.fillColor = color
        node.strokeColor = .white
        node.lineWidth = 3
        node.name = name
        node.zPosition = 100
        let l = SKLabelNode(fontNamed: "AvenirNext-Bold")
        l.text = text
        l.fontSize = 10
        l.fontColor = .white
        l.verticalAlignmentMode = .center
        l.name = name
        node.addChild(l)
        return node
    }

    private func iconPedal(kind: String, color: SKColor, name: String) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: 26)
        node.fillColor = color
        node.strokeColor = .white
        node.lineWidth = 3
        node.name = name
        node.zPosition = 100

        let glyph: SKShapeNode
        if kind == "gas" {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -12, y: -1)); p.addLine(to: CGPoint(x: 0, y: 12))
            p.addLine(to: CGPoint(x: 12, y: -1))
            p.move(to: CGPoint(x: -12, y: -12)); p.addLine(to: CGPoint(x: 0, y: 1))
            p.addLine(to: CGPoint(x: 12, y: -12))
            glyph = SKShapeNode(path: p)
            glyph.strokeColor = .white
            glyph.lineWidth = 4
            glyph.lineCap = .round
            glyph.lineJoin = .round
        } else if kind == "brake" {
            let p = CGMutablePath()
            let r: CGFloat = 13
            for i in 0..<8 {
                let a = CGFloat(i) * .pi / 4 + .pi / 8
                let pt = CGPoint(x: cos(a) * r, y: sin(a) * r)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            glyph = SKShapeNode(path: p)
            glyph.fillColor = .white
            glyph.strokeColor = .white
            glyph.lineWidth = 2
        } else if kind == "horn" {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -11, y: -5))
            p.addLine(to: CGPoint(x: -4, y: -5))
            p.addLine(to: CGPoint(x: 3, y: -12))
            p.addLine(to: CGPoint(x: 3, y: 12))
            p.addLine(to: CGPoint(x: -4, y: 5))
            p.addLine(to: CGPoint(x: -11, y: 5))
            p.closeSubpath()

            p.move(to: CGPoint(x: 7, y: -6));  p.addCurve(to: CGPoint(x: 7, y: 6),
                    control1: CGPoint(x: 11, y: -2), control2: CGPoint(x: 11, y: 2))
            p.move(to: CGPoint(x: 11, y: -10)); p.addCurve(to: CGPoint(x: 11, y: 10),
                    control1: CGPoint(x: 17, y: -3), control2: CGPoint(x: 17, y: 3))
            glyph = SKShapeNode(path: p)
            glyph.fillColor = .clear
            glyph.strokeColor = .white
            glyph.lineWidth = 2.2
            glyph.lineJoin = .round
        } else {
            let p = CGMutablePath()

            p.addRoundedRect(in: CGRect(x: -11, y: -12, width: 20, height: 24),
                             cornerWidth: 3, cornerHeight: 3)

            p.addRoundedRect(in: CGRect(x: -7, y: 1, width: 12, height: 7),
                             cornerWidth: 2, cornerHeight: 2)
            glyph = SKShapeNode(path: p)
            glyph.fillColor = .clear
            glyph.strokeColor = .white
            glyph.lineWidth = 2.2

            let handle = SKShapeNode(rectOf: CGSize(width: 8, height: 2.4), cornerRadius: 1.2)
            handle.fillColor = .white
            handle.strokeColor = .white
            handle.position = CGPoint(x: -1, y: -4)
            handle.name = name
            node.addChild(handle)

            let ap = CGMutablePath()
            ap.move(to: CGPoint(x: 13, y: 0)); ap.addLine(to: CGPoint(x: 21, y: 0))
            ap.move(to: CGPoint(x: 17, y: 4)); ap.addLine(to: CGPoint(x: 21, y: 0))
            ap.addLine(to: CGPoint(x: 17, y: -4))
            let arrowG = SKShapeNode(path: ap)
            arrowG.strokeColor = .white
            arrowG.lineWidth = 2.2
            arrowG.lineCap = .round
            arrowG.name = name
            node.addChild(arrowG)
        }
        glyph.name = name
        node.addChild(glyph)
        return node
    }

    private func layout() {
        let w = size.width, h = size.height
        moneyLabel.position = CGPoint(x: 24, y: h - 58)
        statusBG.position = CGPoint(x: w / 2, y: h - 40)
        statusLabel.position = CGPoint(x: w / 2, y: h - 40)
        streetBG.position = CGPoint(x: w / 2, y: h - 74)
        streetLabel.position = CGPoint(x: w / 2, y: h - 74)
        arrow.position = CGPoint(x: w / 2 - 26, y: h - 84)
        distanceLabel.position = CGPoint(x: w / 2 + 16, y: h - 90)
        ordersButton.position = CGPoint(x: w - 94, y: h - 46)
        actionButton.position = CGPoint(x: w - 92, y: 208)
        gasPedal.position = CGPoint(x: w - 52, y: 62)
        brakePedal.position = CGPoint(x: w - 122, y: 62)
        exitButton.position = CGPoint(x: w - 52, y: 136)
        hintLabel.position = CGPoint(x: w / 2, y: 40)

        let inset = view?.safeAreaInsets.left ?? 0
        minimapRoot.position = CGPoint(x: max(20, inset) + mapSize / 2 + 8,
                                       y: h - 96 - mapSize / 2)
        pauseButton.position = CGPoint(x: w - 200, y: h - 46)
        doorsButton.position = CGPoint(x: w - 330, y: 96)
        sprintButton.position = CGPoint(x: w - 52, y: 62)
        jumpButton.position = CGPoint(x: w - 120, y: 62)
        crouchButton.position = CGPoint(x: w - 52, y: 130)
        honkButton.position = CGPoint(x: w - 192, y: 62)
        dialogueBG.position = CGPoint(x: w / 2, y: 118)
        dialogueName.position = CGPoint(x: w / 2, y: 138)
        dialogueLine.position = CGPoint(x: w / 2, y: 108)

        layoutPanel()
    }

    func setMoney(_ value: Int) { moneyLabel.text = "$\(value)" }
    func setStatus(_ text: String) { statusLabel.text = text }

    func showDialogue(speaker: String, line: String) {
        dialogueName.text = speaker
        dialogueLine.text = "\u{201C}" + line + "\u{201D}"

        var nodes: [SKNode] = []
        if let bg = dialogueBG as SKNode? { nodes.append(bg) }
        if let nm = dialogueName as SKNode? { nodes.append(nm) }
        if let ln = dialogueLine as SKNode? { nodes.append(ln) }

        for n in nodes {
            n.removeAllActions()
            n.isHidden = false
            n.alpha = 1
            let hide = SKAction.run { n.isHidden = true }
            n.run(SKAction.sequence([SKAction.wait(forDuration: 3.0),
                                     SKAction.fadeOut(withDuration: 0.5),
                                     hide]))
        }
    }

    func setStreet(_ text: String) {
        streetLabel.text = "🛣  " + text
        streetLabel.isHidden = false
        streetBG.isHidden = false
    }

    func setAction(_ title: String?) {
        guard let t = title else {
            actionButton.isHidden = true
            exitButton.isHidden = true
            return
        }

        let isExit = t.hasPrefix("Exit") || t.hasPrefix("Get Off")
        exitButton.isHidden = !isExit
        actionButton.isHidden = isExit
        if !isExit { actionLabel.text = t }
    }

    func setDriving(_ driving: Bool) {
        gasPedal.isHidden = !driving
        brakePedal.isHidden = !driving
        doorsButton.isHidden = true
        sprintButton.isHidden = driving
        jumpButton.isHidden = driving
        crouchButton.isHidden = driving
        honkButton.isHidden = !driving

    }

    func setTransit(_ transit: Bool) {
        isTransit = transit
        doorsButton.isHidden = true
    }

    func setArrow(angle: CGFloat?, visible: Bool, metres: Float? = nil) {
        arrow.isHidden = !visible
        if let a = angle { arrow.zRotation = a }

        if visible, let m = metres {
            distanceLabel.isHidden = false

            if m >= 1000 {
                distanceLabel.text = String(format: "%.1f km", m / 1000)
            } else {
                distanceLabel.text = "\(Int(m)) m"
            }

            distanceLabel.fontColor = m < 10 ? SKColor.green : SKColor.yellow
        } else {
            distanceLabel.isHidden = true
        }
    }

    func setOffers(_ rows: [HUDOffer]) {
        offers = rows
        ordersButtonLabel.text = "Orders (\(rows.count))"
        layoutPanel()
    }

    private var flashLabel: SKLabelNode?

    func flash(_ text: String) {
        let l: SKLabelNode
        if let existing = flashLabel {
            l = existing
        } else {
            l = SKLabelNode(fontNamed: "AvenirNext-Bold")
            l.fontSize = 26
            l.fontColor = .yellow
            l.zPosition = 200
            addChild(l)
            flashLabel = l
        }
        l.removeAllActions()
        l.text = text
        l.alpha = 1
        l.position = CGPoint(x: size.width / 2, y: size.height / 2 + 70)
        l.run(.sequence([.wait(forDuration: 1.4), .fadeOut(withDuration: 0.4)]))
    }

    func configureMinimap(image: UIImage, worldMin: Float, worldMax: Float) {
        self.worldMin = worldMin
        self.worldMax = worldMax
        mapSprite?.removeFromParent()
        let sprite = SKSpriteNode(texture: SKTexture(image: image))

        sprite.size = CGSize(width: mapSize * zoom, height: mapSize * zoom)
        mapCrop.addChild(sprite)
        mapSprite = sprite
    }

    private func mapPoint(_ x: Float, _ z: Float) -> CGPoint {
        let range = worldMax - worldMin
        let px = (CGFloat((x - worldMin) / range) - 0.5) * mapSize * zoom
        let py = (0.5 - CGFloat((z - worldMin) / range)) * mapSize * zoom

        let maxR = mapSize / 2 - 6
        let len = sqrt(px * px + py * py)
        if len > maxR { return CGPoint(x: px / len * maxR, y: py / len * maxR) }
        return CGPoint(x: px, y: py)
    }

    func updateMinimap(playerX: Float, playerZ: Float, playerHeading: Float,
                       carX: Float, carZ: Float,
                       pickupX: Float?, pickupZ: Float?,
                       dropX: Float?, dropZ: Float?) {

        let p = mapPoint(playerX, playerZ)
        let shift = CGPoint(x: -p.x, y: -p.y)
        mapSprite?.position = shift
        playerArrow.position = .zero
        playerArrow.zRotation = CGFloat(playerHeading)
        carDot.position = CGPoint(x: mapPoint(carX, carZ).x + shift.x,
                                  y: mapPoint(carX, carZ).y + shift.y)
        func clamped(_ wx: Float, _ wz: Float) -> CGPoint {
            let m = mapPoint(wx, wz)
            var pt = CGPoint(x: m.x + shift.x, y: m.y + shift.y)

            let maxR = mapSize / 2 - 7
            let len = sqrt(pt.x * pt.x + pt.y * pt.y)
            if len > maxR { pt = CGPoint(x: pt.x / len * maxR, y: pt.y / len * maxR) }
            return pt
        }
        if let x = pickupX, let z = pickupZ {
            pickupDot.isHidden = false
            pickupDot.position = clamped(x, z)
        } else { pickupDot.isHidden = true }
        if let x = dropX, let z = dropZ {
            dropDot.isHidden = false
            dropDot.position = clamped(x, z)
        } else { dropDot.isHidden = true }
    }

    func showMenu(title: String, subtitle: String?, buttons: [(String, String)]) {
        lastMenu = (title, subtitle, buttons)
        menuRoot.removeAllChildren()
        menuRoot.isHidden = false
        let cx = size.width / 2, cy = size.height / 2

        let dim = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        dim.fillColor = SKColor(white: 0, alpha: 0.6)
        dim.strokeColor = .clear
        dim.position = CGPoint(x: cx, y: cy)
        menuRoot.addChild(dim)

        let panelH = CGFloat(150 + buttons.count * 68)
        let panel = SKShapeNode(rectOf: CGSize(width: 380, height: panelH), cornerRadius: 20)
        panel.fillColor = SKColor(red: 0.09, green: 0.09, blue: 0.14, alpha: 0.98)
        panel.strokeColor = .white
        panel.lineWidth = 2
        panel.position = CGPoint(x: cx, y: cy)
        menuRoot.addChild(panel)

        let t = SKLabelNode(fontNamed: "AvenirNext-Bold")
        t.text = title
        t.fontSize = 28
        t.fontColor = .white
        t.position = CGPoint(x: 0, y: panelH / 2 - 52)
        panel.addChild(t)

        if let sub = subtitle {
            let st = SKLabelNode(fontNamed: "AvenirNext-Medium")
            st.text = sub
            st.fontSize = 14
            st.fontColor = .lightGray
            st.position = CGPoint(x: 0, y: panelH / 2 - 78)
            panel.addChild(st)
        }

        for (i, (id, label)) in buttons.enumerated() {
            let b = SKShapeNode(rectOf: CGSize(width: 300, height: 54), cornerRadius: 14)
            b.fillColor = SKColor(red: 0.15, green: 0.55, blue: 0.35, alpha: 1)
            b.strokeColor = .white
            b.lineWidth = 2
            b.position = CGPoint(x: 0, y: panelH / 2 - 130 - CGFloat(i) * 68)
            b.name = "menu_" + id
            panel.addChild(b)
            let bl = SKLabelNode(fontNamed: "AvenirNext-Bold")
            bl.text = label
            bl.fontSize = 20
            bl.fontColor = .white
            bl.verticalAlignmentMode = .center
            bl.name = "menu_" + id
            b.addChild(bl)
        }
    }

    func hideMenu() {
        menuRoot.isHidden = true
        lastMenu = nil
    }

    private func layoutPanel() {
        panel.removeAllChildren()
        let w = size.width, h = size.height
        let panelW: CGFloat = 280
        let rowH: CGFloat = 48
        let bg = SKShapeNode(rectOf: CGSize(width: panelW, height: rowH * 3 + 58),
                             cornerRadius: 16)
        bg.fillColor = SKColor(red: 0.07, green: 0.07, blue: 0.11, alpha: 0.96)
        bg.strokeColor = .white
        bg.position = CGPoint(x: w - panelW / 2 - 20, y: h - 200 - rowH)
        panel.addChild(bg)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "Available Orders"
        title.fontSize = 18
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: rowH * 1.5 + 2)
        bg.addChild(title)

        if offers.isEmpty {
            let empty = SKLabelNode(fontNamed: "AvenirNext-Medium")
            empty.text = "No orders right now…"
            empty.fontSize = 15
            empty.fontColor = .lightGray
            bg.addChild(empty)
        }

        for (i, offer) in offers.enumerated() {
            let row = SKShapeNode(rectOf: CGSize(width: panelW - 24, height: rowH - 8),
                                  cornerRadius: 10)
            row.fillColor = SKColor(red: 0.18, green: 0.22, blue: 0.3, alpha: 1)
            row.strokeColor = .clear
            row.position = CGPoint(x: 0, y: rowH - CGFloat(i) * rowH - 14)
            row.name = "offer_\(i)"
            bg.addChild(row)

            let l1 = SKLabelNode(fontNamed: "AvenirNext-Bold")
            l1.text = offer.title
            l1.fontSize = 13
            l1.fontColor = .white
            l1.position = CGPoint(x: 0, y: 4)
            l1.name = "offer_\(i)"
            row.addChild(l1)

            let l2 = SKLabelNode(fontNamed: "AvenirNext-Medium")
            l2.text = offer.subtitle
            l2.fontSize = 10
            l2.fontColor = .lightGray
            l2.position = CGPoint(x: 0, y: -12)
            l2.name = "offer_\(i)"
            row.addChild(l2)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {

        if !menuRoot.isHidden {
            for touch in touches {
                let loc = touch.location(in: self)
                for node in nodes(at: loc) {
                    if let name = node.name, name.hasPrefix("menu_") {
                        onMenuButton?(String(name.dropFirst(5)))
                        return
                    }
                }
            }
            return
        }
        for touch in touches {
            let loc = touch.location(in: self)
            let hit = nodes(at: loc)

            if hit.contains(where: { $0.name == "pause" }) { onPause?(); continue }
            if hit.contains(where: { $0.name == "doors" }) { onDoors?(); continue }
            if hit.contains(where: { $0.name == "honk" }) { onHonk?(); continue }
            if hit.contains(where: { $0.name == "jump" }) { onJump?(); continue }
            if hit.contains(where: { $0.name == "crouch" }) { onCrouch?(); continue }
            if hit.contains(where: { $0.name == "sprint" }) {
                sprintTouch = touch; sprintDown = true; continue
            }
            if hit.contains(where: { $0.name == "action" }) { onAction?(); continue }
            if hit.contains(where: { $0.name == "ordersToggle" }) {
                panelOpen.toggle()
                panel.isHidden = !panelOpen
                continue
            }
            if hit.contains(where: { $0.name == "gas" }) {
                gasTouch = touch; gasDown = true; continue
            }
            if hit.contains(where: { $0.name == "brake" }) {
                brakeTouch = touch; brakeDown = true; continue
            }
            var tapped = false
            for node in hit {
                if let name = node.name, name.hasPrefix("offer_"),
                   let idx = Int(name.dropFirst(6)) {
                    panelOpen = false
                    panel.isHidden = true
                    onOfferSelected?(idx)
                    tapped = true
                    break
                }
            }
            if tapped { continue }

            if joyTouch == nil && loc.x < size.width / 2 {
                joyTouch = touch
                let base = SKShapeNode(circleOfRadius: 58)
                base.strokeColor = SKColor(white: 1, alpha: 0.55)
                base.lineWidth = 3
                base.position = loc
                base.zPosition = 150
                addChild(base)
                let knob = SKShapeNode(circleOfRadius: 27)
                knob.fillColor = SKColor(white: 1, alpha: 0.65)
                knob.strokeColor = .clear
                knob.position = loc
                knob.zPosition = 151
                addChild(knob)
                joyBase = base
                joyKnob = knob
                joystick = .zero
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let jt = joyTouch, touches.contains(jt),
              let base = joyBase, let knob = joyKnob else { return }
        let loc = jt.location(in: self)
        var dx = loc.x - base.position.x
        var dy = loc.y - base.position.y
        let len = max(1, hypot(dx, dy))
        let capped = min(len, 58)
        dx = dx / len * capped
        dy = dy / len * capped
        knob.position = CGPoint(x: base.position.x + dx, y: base.position.y + dy)
        joystick = CGVector(dx: dx / 58, dy: dy / 58)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        release(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        release(touches)
    }

    private func release(_ touches: Set<UITouch>) {
        if let jt = joyTouch, touches.contains(jt) {
            joyTouch = nil
            joyBase?.removeFromParent()
            joyKnob?.removeFromParent()
            joyBase = nil
            joyKnob = nil
            joystick = .zero
        }
        if let gt = gasTouch, touches.contains(gt) { gasTouch = nil; gasDown = false }
        if let bt = brakeTouch, touches.contains(bt) { brakeTouch = nil; brakeDown = false }
        if let st = sprintTouch, touches.contains(st) { sprintTouch = nil; sprintDown = false }
    }
}
