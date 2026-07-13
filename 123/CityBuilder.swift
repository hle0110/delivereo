import SceneKit
import UIKit

enum District {
    case financial, downtown, chinatown, residential
}

struct Venue {
    enum Kind { case restaurant, bank, grocery, shop }
    let name: String
    let kind: Kind
    let door: SCNVector3
    let zone: CGRect
    let workerPos: SCNVector3
    let workerHeading: Float
}

struct CityData {
    var buildingRects: [CGRect] = []
    var venues: [Venue] = []
    var restaurantDoors: [SCNVector3] = []
    var restaurantZones: [CGRect] = []
    var restaurantNames: [String] = []
    var houseDoors: [SCNVector3] = []
    var houseZones: [CGRect] = []
    var houseAddresses: [String] = []
    var workerSpots: [(SCNVector3, Float)] = []
    var customerSpots: [(SCNVector3, Float)] = []
    var streetcarStops: [SCNVector3] = []
    var trafficLightPositions: [SCNVector3] = []
    var crosswalks: [SCNVector3] = []
    var carSpawn = SCNVector3(0, 0, 0)
    var playerSpawn = SCNVector3(0, 0, 0)
    var minBound: Float = 0
    var maxBound: Float = 0
}

final class CityBuilder {

    static let blocks = 7
    static let blockSize: Float = 36
    static let roadW: Float = 18
    static var pitch: Float { blockSize + roadW }
    static var total: Float { roadW + Float(blocks) * pitch }
    static var midRoadZ: Float { Float(blocks / 2) * pitch + roadW / 2 - total / 2 }

    static let transitLaneW: Float = 2.6
    static let carLaneW: Float = 3.2
    static let bikeLaneW: Float = 1.6

    static let transitOffset: Float = 1.4
    static let carOffset: Float = 5.2
    static let bikeOffset: Float = 7.7

    static var transitLaneEast: Float { midRoadZ - transitOffset }
    static var transitLaneWest: Float { midRoadZ + transitOffset }

    static func districtFor(i: Int, j: Int, centerBlock: Float) -> District {
        let di = Float(i) - centerBlock
        let dj = Float(j) - centerBlock
        if abs(di) <= 1 && dj >= 0.5 && dj <= 2 { return .financial }
        if abs(di) <= 1 && abs(dj) <= 1 { return .downtown }
        if di <= -1.5 && abs(dj) <= 1.5 { return .chinatown }
        return .residential
    }

    struct Brand {
        let name: String
        let kind: Venue.Kind
        let primary: UIColor
        let accent: UIColor
    }

    static let restaurantBrands: [Brand] = [
        Brand(name: "Burger Barn", kind: .restaurant,
              primary: UIColor(red: 0.85, green: 0.42, blue: 0.12, alpha: 1),
              accent: UIColor(red: 1.0, green: 0.82, blue: 0.25, alpha: 1)),
        Brand(name: "Pizza Palace", kind: .restaurant,
              primary: UIColor(red: 0.75, green: 0.18, blue: 0.16, alpha: 1),
              accent: UIColor(red: 0.95, green: 0.92, blue: 0.85, alpha: 1)),
        Brand(name: "Sushi Spot", kind: .restaurant,
              primary: UIColor(red: 0.16, green: 0.35, blue: 0.32, alpha: 1),
              accent: UIColor(red: 0.92, green: 0.88, blue: 0.78, alpha: 1)),
        Brand(name: "Taco Town", kind: .restaurant,
              primary: UIColor(red: 0.88, green: 0.62, blue: 0.12, alpha: 1),
              accent: UIColor(red: 0.35, green: 0.6, blue: 0.3, alpha: 1)),
        Brand(name: "Noodle Nook", kind: .restaurant,
              primary: UIColor(red: 0.72, green: 0.25, blue: 0.28, alpha: 1),
              accent: UIColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1)),
        Brand(name: "Curry Corner", kind: .restaurant,
              primary: UIColor(red: 0.78, green: 0.52, blue: 0.1, alpha: 1),
              accent: UIColor(red: 0.95, green: 0.85, blue: 0.5, alpha: 1)),
        Brand(name: "Shawarma Stop", kind: .restaurant,
              primary: UIColor(red: 0.5, green: 0.4, blue: 0.2, alpha: 1),
              accent: UIColor(red: 0.9, green: 0.8, blue: 0.4, alpha: 1)),
        Brand(name: "Poutine Place", kind: .restaurant,
              primary: UIColor(red: 0.62, green: 0.3, blue: 0.18, alpha: 1),
              accent: UIColor(red: 0.95, green: 0.9, blue: 0.7, alpha: 1)),
    ]

    static let bankBrands: [Brand] = [
        Brand(name: "Scotiabank", kind: .bank,
              primary: UIColor(red: 0.90, green: 0.12, blue: 0.16, alpha: 1),
              accent: UIColor.white),
        Brand(name: "TD Bank", kind: .bank,
              primary: UIColor(red: 0.02, green: 0.53, blue: 0.30, alpha: 1),
              accent: UIColor.white),
        Brand(name: "RBC Royal Bank", kind: .bank,
              primary: UIColor(red: 0.00, green: 0.35, blue: 0.66, alpha: 1),
              accent: UIColor(red: 1.0, green: 0.85, blue: 0.15, alpha: 1)),
        Brand(name: "BMO", kind: .bank,
              primary: UIColor(red: 0.05, green: 0.30, blue: 0.60, alpha: 1),
              accent: UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1)),
        Brand(name: "CIBC", kind: .bank,
              primary: UIColor(red: 0.75, green: 0.12, blue: 0.15, alpha: 1),
              accent: UIColor(red: 0.85, green: 0.75, blue: 0.2, alpha: 1)),
    ]

    static let groceryBrands: [Brand] = [
        Brand(name: "No Frills", kind: .grocery,
              primary: UIColor(red: 0.95, green: 0.85, blue: 0.10, alpha: 1),
              accent: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1)),
        Brand(name: "Walmart", kind: .grocery,
              primary: UIColor(red: 0.00, green: 0.44, blue: 0.76, alpha: 1),
              accent: UIColor(red: 1.0, green: 0.79, blue: 0.10, alpha: 1)),
        Brand(name: "Costco", kind: .grocery,
              primary: UIColor(red: 0.90, green: 0.20, blue: 0.20, alpha: 1),
              accent: UIColor(red: 0.10, green: 0.30, blue: 0.65, alpha: 1)),
        Brand(name: "Loblaws", kind: .grocery,
              primary: UIColor(red: 0.85, green: 0.30, blue: 0.15, alpha: 1),
              accent: UIColor.white),
        Brand(name: "Metro", kind: .grocery,
              primary: UIColor(red: 0.10, green: 0.45, blue: 0.25, alpha: 1),
              accent: UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1)),
    ]

    static let shopBrands: [Brand] = [
        Brand(name: "Tim Hortons", kind: .shop,
              primary: UIColor(red: 0.78, green: 0.15, blue: 0.18, alpha: 1),
              accent: UIColor(red: 0.95, green: 0.85, blue: 0.6, alpha: 1)),
        Brand(name: "Shoppers", kind: .shop,
              primary: UIColor(red: 0.85, green: 0.15, blue: 0.35, alpha: 1),
              accent: UIColor.white),
        Brand(name: "Canadian Tire", kind: .shop,
              primary: UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1),
              accent: UIColor(red: 0.15, green: 0.5, blue: 0.25, alpha: 1)),
        Brand(name: "LCBO", kind: .shop,
              primary: UIColor(red: 0.15, green: 0.35, blue: 0.55, alpha: 1),
              accent: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)),
        Brand(name: "Book Nook", kind: .shop,
              primary: UIColor(red: 0.45, green: 0.3, blue: 0.55, alpha: 1),
              accent: UIColor(red: 0.95, green: 0.9, blue: 0.75, alpha: 1)),
        Brand(name: "Hardware Co", kind: .shop,
              primary: UIColor(red: 0.35, green: 0.45, blue: 0.5, alpha: 1),
              accent: UIColor(red: 0.9, green: 0.65, blue: 0.2, alpha: 1)),
    ]

    static let addrStreets = ["Queen St W", "King St E", "Dundas St W",
                              "College St", "Bloor St W", "Front St E",
                              "Yonge St", "Bay St", "Spadina Ave"]

    static func randomAddress() -> String {
        let num = Int.random(in: 12...899)
        let street = addrStreets.randomElement() ?? "Yonge St"
        return String(num) + " " + street
    }

    private static var signRoot = SCNNode()

    static func build(into scene: SCNScene) -> CityData {
        var data = CityData()
        let offset = total / 2
        data.minBound = -offset - 300
        data.maxBound = offset + 460

        let root = SCNNode()
        scene.rootNode.addChildNode(root)

        signRoot = SCNNode()
        signRoot.name = "signs"

        buildGroundAndLake(root, offset: offset)
        buildRoads(root, offset: offset)
        buildTransitWay(root)
        buildCrosswalksAndLights(root, offset: offset, data: &data)
        buildStreetcarStops(root, data: &data)
        buildBlocks(root, offset: offset, data: &data)
        buildLandmarks(root, offset: offset)

        data.carSpawn = SCNVector3(0, 0, midRoadZ + carOffset)
        data.playerSpawn = SCNVector3(7, 0, midRoadZ + carOffset + 5)

        root.name = "city"
        scene.rootNode.addChildNode(signRoot)
        return data
    }

    private static func buildGroundAndLake(_ root: SCNNode, offset: Float) {
        let ground = SCNNode(geometry: SCNPlane(width: CGFloat(total + 1000),
                                                height: CGFloat(total + 1000)))
        ground.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.45, green: 0.6, blue: 0.35, alpha: 1)
        ground.geometry?.firstMaterial?.lightingModel = .lambert
        ground.eulerAngles.x = -.pi / 2
        root.addChildNode(ground)

        let lake = SCNNode(geometry: SCNBox(width: CGFloat(total + 1000), height: 0.05,
                                            length: 700, chamferRadius: 0))
        let water = SCNMaterial()
        water.diffuse.contents = UIColor(red: 0.15, green: 0.35, blue: 0.55, alpha: 1)
        water.lightingModel = .lambert
        lake.geometry?.materials = [water]
        lake.position = SCNVector3(0, 0.03, offset + 380)
        root.addChildNode(lake)

        let beach = SCNNode(geometry: SCNBox(width: CGFloat(total + 1000), height: 0.07,
                                             length: 18, chamferRadius: 0))
        beach.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.87, green: 0.8, blue: 0.6, alpha: 1)
        beach.geometry?.firstMaterial?.lightingModel = .lambert
        beach.position = SCNVector3(0, 0.035, offset + 25)
        root.addChildNode(beach)
    }

    private static func buildRoads(_ root: SCNNode, offset: Float) {
        let asphalt = SCNMaterial()
        asphalt.diffuse.contents = UIColor(white: 0.2, alpha: 1)
        asphalt.lightingModel = .lambert

        let bikeBed = SCNMaterial()
        bikeBed.diffuse.contents = UIColor(red: 0.14, green: 0.36, blue: 0.22, alpha: 1)
        bikeBed.lightingModel = .lambert

        let paint = SCNMaterial()
        paint.diffuse.contents = UIColor(red: 0.95, green: 0.9, blue: 0.55, alpha: 1)
        paint.lightingModel = .lambert

        for k in 0...blocks {
            let c = Float(k) * pitch + roadW / 2 - offset

            for horizontal in [true, false] {
                let road = SCNNode(geometry: SCNBox(
                    width: horizontal ? CGFloat(total) : CGFloat(roadW),
                    height: 0.1,
                    length: horizontal ? CGFloat(roadW) : CGFloat(total),
                    chamferRadius: 0))
                road.geometry?.materials = [asphalt]
                road.position = horizontal ? SCNVector3(0, 0.05, c) : SCNVector3(c, 0.05, 0)
                root.addChildNode(road)

                for side: Float in [-bikeOffset, bikeOffset] {
                    let bl = SCNNode(geometry: SCNBox(
                        width: horizontal ? CGFloat(total) : CGFloat(bikeLaneW),
                        height: 0.02,
                        length: horizontal ? CGFloat(bikeLaneW) : CGFloat(total),
                        chamferRadius: 0))
                    bl.geometry?.materials = [bikeBed]
                    bl.position = horizontal ? SCNVector3(0, 0.115, c + side)
                                             : SCNVector3(c + side, 0.115, 0)
                    root.addChildNode(bl)
                }

                let centre = SCNNode(geometry: SCNBox(
                    width: horizontal ? CGFloat(total) : 0.2,
                    height: 0.02,
                    length: horizontal ? 0.2 : CGFloat(total),
                    chamferRadius: 0))
                centre.geometry?.materials = [paint]
                centre.position = horizontal ? SCNVector3(0, 0.115, c)
                                             : SCNVector3(c, 0.115, 0)
                root.addChildNode(centre)
            }
        }
    }

    private static func buildTransitWay(_ root: SCNNode) {
        let bed = SCNMaterial()
        bed.diffuse.contents = UIColor(red: 0.30, green: 0.27, blue: 0.26, alpha: 1)
        bed.lightingModel = .lambert

        let railMat = SCNMaterial()
        railMat.diffuse.contents = UIColor(white: 0.5, alpha: 1)
        railMat.lightingModel = .lambert

        for lane in [transitLaneEast, transitLaneWest] {
            let strip = SCNNode(geometry: SCNBox(width: CGFloat(total), height: 0.02,
                                                 length: CGFloat(transitLaneW),
                                                 chamferRadius: 0))
            strip.geometry?.materials = [bed]
            strip.position = SCNVector3(0, 0.118, lane)
            root.addChildNode(strip)

            for dz: Float in [-0.75, 0.75] {
                let rail = SCNNode(geometry: SCNBox(width: CGFloat(total), height: 0.04,
                                                    length: 0.14, chamferRadius: 0))
                rail.geometry?.materials = [railMat]
                rail.position = SCNVector3(0, 0.14, lane + dz)
                root.addChildNode(rail)
            }
        }
    }

    private static func buildCrosswalksAndLights(_ root: SCNNode, offset: Float,
                                                 data: inout CityData) {
        let zebra = SCNMaterial()
        zebra.diffuse.contents = UIColor(white: 0.92, alpha: 1)
        zebra.lightingModel = .lambert

        let stripeH = SCNBox(width: 0.9, height: 0.02, length: 1.6, chamferRadius: 0)
        stripeH.materials = [zebra]
        let stripeV = SCNBox(width: 1.6, height: 0.02, length: 0.9, chamferRadius: 0)
        stripeV.materials = [zebra]

        let edge = roadW / 2 + 1.2
        let corner = roadW / 2 + 1.8

        for a in 0...blocks {
            for b in 0...blocks {
                let cx = Float(a) * pitch + roadW / 2 - offset
                let cz = Float(b) * pitch + roadW / 2 - offset

                for side in 0..<4 {
                    let horizontal = side < 2
                    let ox: Float = side == 0 ? -edge : (side == 1 ? edge : 0)
                    let oz: Float = side == 2 ? -edge : (side == 3 ? edge : 0)
                    for k in 0..<5 {
                        let t = Float(k) * 3.2 - 6.4

                        let stripe = SCNNode(geometry: horizontal ? stripeH : stripeV)
                        stripe.position = SCNVector3(cx + ox + (horizontal ? 0 : t),
                                                     0.145,
                                                     cz + oz + (horizontal ? t : 0))
                        root.addChildNode(stripe)
                    }
                }
                data.crosswalks.append(SCNVector3(cx, 0, cz))

                for (sx, sz) in [(-corner, -corner), (corner, -corner),
                                 (-corner, corner), (corner, corner)] {
                    data.trafficLightPositions.append(SCNVector3(cx + sx, 0, cz + sz))
                }
            }
        }
    }

    private static func buildStreetcarStops(_ root: SCNNode, data: inout CityData) {

        let platZ = transitLaneWest + transitLaneW / 2 + 0.9

        for fx: Float in [-0.36, -0.12, 0.12, 0.36] {
            let sx = fx * total

            let platform = SCNNode(geometry: SCNBox(width: 10, height: 0.35, length: 1.7,
                                                    chamferRadius: 0.05))
            platform.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.75, alpha: 1)
            platform.geometry?.firstMaterial?.lightingModel = .lambert
            platform.position = SCNVector3(sx, 0.18, platZ)
            root.addChildNode(platform)

            let roof = SCNNode(geometry: SCNBox(width: 5.5, height: 0.14, length: 1.7,
                                                chamferRadius: 0.05))
            roof.geometry?.firstMaterial?.diffuse.contents =
                UIColor(red: 0.25, green: 0.28, blue: 0.32, alpha: 1)
            roof.geometry?.firstMaterial?.lightingModel = .lambert
            roof.position = SCNVector3(sx, 2.7, platZ)
            root.addChildNode(roof)

            for px: Float in [-2.5, 2.5] {
                let post = SCNNode(geometry: SCNCylinder(radius: 0.06, height: 2.7))
                post.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.3, alpha: 1)
                post.geometry?.firstMaterial?.lightingModel = .lambert
                post.position = SCNVector3(sx + px, 1.35, platZ)
                root.addChildNode(post)
            }

            let sign = SCNNode(geometry: SCNBox(width: 1.6, height: 0.7, length: 0.08,
                                                chamferRadius: 0.06))
            sign.geometry?.firstMaterial?.diffuse.contents =
                UIColor(red: 0.78, green: 0.1, blue: 0.12, alpha: 1)
            sign.geometry?.firstMaterial?.emission.contents =
                UIColor(red: 0.4, green: 0.05, blue: 0.06, alpha: 1)
            sign.position = SCNVector3(sx + 3.8, 2.3, platZ)
            root.addChildNode(sign)

            data.streetcarStops.append(SCNVector3(sx, 0, transitLaneWest))
        }
    }

    private static func buildBlocks(_ root: SCNNode, offset: Float, data: inout CityData) {
        struct Lot {
            let center: SCNVector3
            let doorDir: Float
            let district: District
        }
        var lots: [Lot] = []
        let centerBlock = Float(blocks - 1) / 2

        for i in 0..<blocks {
            for j in 0..<blocks {
                let bx = roadW + Float(i) * pitch + blockSize / 2 - offset
                let bz = roadW + Float(j) * pitch + blockSize / 2 - offset
                let district = districtFor(i: i, j: j, centerBlock: centerBlock)

                let sidewalk = SCNNode(geometry: SCNBox(width: CGFloat(blockSize + 2),
                                                        height: 0.24,
                                                        length: CGFloat(blockSize + 2),
                                                        chamferRadius: 0))
                sidewalk.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.62, alpha: 1)
                sidewalk.geometry?.firstMaterial?.lightingModel = .lambert
                sidewalk.position = SCNVector3(bx, 0.12, bz)
                root.addChildNode(sidewalk)

                if district == .residential {
                    for (tx, tz) in [(-16, -16), (16, -16), (-16, 16), (16, 16)] {
                        addTree(to: root, at: SCNVector3(bx + Float(tx), 0.24, bz + Float(tz)))
                    }
                }

                for (lx, lz) in [(-9, -9), (9, -9), (-9, 9), (9, 9)] {
                    lots.append(Lot(center: SCNVector3(bx + Float(lx), 0, bz + Float(lz)),
                                    doorDir: Float(lz) > 0 ? 1 : -1,
                                    district: district))
                }
            }
        }

        func addCollision(_ cx: Float, _ cz: Float, _ w: Float, _ d: Float) {
            data.buildingRects.append(CGRect(x: CGFloat(cx - w / 2), y: CGFloat(cz - d / 2),
                                             width: CGFloat(w), height: CGFloat(d)))
        }

        let glassMats: [SCNMaterial] = [
            UIColor(red: 0.45, green: 0.55, blue: 0.62, alpha: 1),
            UIColor(red: 0.38, green: 0.47, blue: 0.55, alpha: 1),
            UIColor(red: 0.5, green: 0.58, blue: 0.6, alpha: 1),
        ].map { base in
            let m = SCNMaterial()
            m.diffuse.contents = windowTexture(base: base,
                pane: UIColor(red: 0.55, green: 0.65, blue: 0.74, alpha: 1), litChance: 0.12)
            m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
            m.lightingModel = .lambert
            return m
        }
        let stoneMats: [SCNMaterial] = [
            UIColor(red: 0.62, green: 0.58, blue: 0.52, alpha: 1),
            UIColor(red: 0.55, green: 0.52, blue: 0.5, alpha: 1),
            UIColor(red: 0.68, green: 0.63, blue: 0.55, alpha: 1),
        ].map { base in
            let m = SCNMaterial()
            m.diffuse.contents = windowTexture(base: base,
                pane: UIColor(red: 0.22, green: 0.25, blue: 0.3, alpha: 1), litChance: 0.2)
            m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
            m.lightingModel = .lambert
            return m
        }
        let brickMats: [SCNMaterial] = [
            UIColor(red: 0.6, green: 0.38, blue: 0.3, alpha: 1),
            UIColor(red: 0.68, green: 0.55, blue: 0.42, alpha: 1),
            UIColor(red: 0.55, green: 0.5, blue: 0.48, alpha: 1),
        ].map { base in
            let m = SCNMaterial()
            m.diffuse.contents = windowTexture(base: base,
                pane: UIColor(red: 0.15, green: 0.17, blue: 0.22, alpha: 1), litChance: 0.25)
            m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
            m.lightingModel = .lambert
            return m
        }
        let roofMat = SCNMaterial()
        roofMat.diffuse.contents = UIColor(white: 0.3, alpha: 1)
        roofMat.lightingModel = .lambert

        for lot in lots where lot.district == .financial || lot.district == .downtown {
            let c = lot.center
            let isBank = (lot.district == .financial)
            let w = Float.random(in: 11...14)
            let d = Float.random(in: 11...14)
            let h: Float = isBank ? Float.random(in: 55...105) : Float.random(in: 28...65)
            let wall = (isBank ? stoneMats : glassMats).randomElement()!.copy() as! SCNMaterial

            let style = Int.random(in: 0..<3)
            if style == 0 {
                let lowH = h * 0.35
                tower(root, wall, roofMat, c, w, d, lowH, 0.24)
                tower(root, wall, roofMat, c, w * 0.74, d * 0.74, h - lowH, 0.24 + lowH)
            } else if style == 1 {
                tower(root, wall, roofMat, c, w, d, h, 0.24)
            } else {
                let lowH = h * 0.55
                tower(root, wall, roofMat, c, w, d * 0.8, lowH, 0.24)
                tower(root, wall, roofMat, c, w * 0.62, d * 0.62, h - lowH, 0.24 + lowH)
            }

            let podium = SCNNode(geometry: SCNBox(width: CGFloat(w + 1.6), height: 5.0,
                                                  length: CGFloat(d + 1.6), chamferRadius: 0.3))
            podium.geometry?.firstMaterial?.diffuse.contents =
                UIColor(red: 0.34, green: 0.36, blue: 0.4, alpha: 1)
            podium.geometry?.firstMaterial?.lightingModel = .lambert
            podium.position = SCNVector3(c.x, 2.7, c.z)
            root.addChildNode(podium)

            let crown = SCNNode(geometry: SCNBox(width: CGFloat(w + 0.4), height: 1.0,
                                                 length: CGFloat(d + 0.4), chamferRadius: 0.1))
            let crownColor = isBank
                ? UIColor(red: 0.95, green: 0.8, blue: 0.4, alpha: 1)
                : UIColor(red: 0.5, green: 0.75, blue: 0.95, alpha: 1)
            crown.geometry?.firstMaterial?.diffuse.contents = crownColor
            crown.geometry?.firstMaterial?.emission.contents = crownColor
            crown.position = SCNVector3(c.x, h + 0.24, c.z)
            root.addChildNode(crown)

            addCollision(c.x, c.z, w, d)
        }

        for lot in lots where lot.district == .chinatown {
            let c = lot.center
            let w = Float.random(in: 11...13)
            let d = Float.random(in: 11...13)
            let h = Float.random(in: 6...11)
            let reds: [UIColor] = [
                UIColor(red: 0.72, green: 0.18, blue: 0.16, alpha: 1),
                UIColor(red: 0.85, green: 0.35, blue: 0.12, alpha: 1),
                UIColor(red: 0.62, green: 0.22, blue: 0.24, alpha: 1),
            ]
            let node = matteBox(w: w, h: h, d: d, color: reds.randomElement()!)
            node.position = SCNVector3(c.x, h / 2 + 0.24, c.z)
            root.addChildNode(node)

            let cornice = SCNNode(geometry: SCNBox(width: CGFloat(w + 0.8), height: 0.5,
                                                   length: CGFloat(d + 0.8), chamferRadius: 0.05))
            cornice.geometry?.firstMaterial?.diffuse.contents =
                UIColor(red: 0.85, green: 0.7, blue: 0.25, alpha: 1)
            cornice.geometry?.firstMaterial?.lightingModel = .lambert
            cornice.position = SCNVector3(c.x, h + 0.24, c.z)
            root.addChildNode(cornice)

            let neon: [UIColor] = [
                UIColor(red: 1, green: 0.25, blue: 0.2, alpha: 1),
                UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1),
                UIColor(red: 0.3, green: 0.9, blue: 0.6, alpha: 1),
            ]
            let nc = neon.randomElement()!
            let banner = SCNNode(geometry: SCNBox(width: 0.9, height: 4.2, length: 0.25,
                                                  chamferRadius: 0.05))
            banner.geometry?.firstMaterial?.diffuse.contents = nc
            banner.geometry?.firstMaterial?.emission.contents = nc
            banner.position = SCNVector3(c.x + w / 2 - 0.6, h * 0.55,
                                         c.z + lot.doorDir * (d / 2 + 0.3))
            root.addChildNode(banner)

            addCollision(c.x, c.z, w, d)
        }

        let outer = lots.filter { $0.district == .residential }.shuffled()

        var brandQueue: [Brand] = []
        brandQueue.append(contentsOf: restaurantBrands)
        brandQueue.append(contentsOf: bankBrands)
        brandQueue.append(contentsOf: groceryBrands)
        brandQueue.append(contentsOf: shopBrands)

        var vi = 0
        var housesBuilt = 0
        let housesWanted = 16

        for lot in outer {
            let c = lot.center
            let dir = lot.doorDir

            if vi < brandQueue.count {
                let brand = brandQueue[vi]
                vi += 1
                buildVenue(root, brand: brand, c: c, dir: dir, data: &data)
            } else if housesBuilt < housesWanted {
                housesBuilt += 1
                buildHouse(root, c: c, dir: dir, data: &data)
            } else {
                let w = Float.random(in: 10...13)
                let d = Float.random(in: 10...13)
                let h = Float.random(in: 7...16)
                let geo = SCNBox(width: CGFloat(w), height: CGFloat(h),
                                 length: CGFloat(d), chamferRadius: 0)
                let wall = brickMats.randomElement()!.copy() as! SCNMaterial
                wall.diffuse.contentsTransform = SCNMatrix4MakeScale(w / 10, h / 7, 1)
                geo.materials = [wall, wall, wall, wall, roofMat, roofMat]
                let node = SCNNode(geometry: geo)
                node.position = SCNVector3(c.x, h / 2 + 0.24, c.z)
                root.addChildNode(node)
                addCollision(c.x, c.z, w, d)
            }
        }
    }

    private static func buildVenue(_ root: SCNNode, brand: Brand,
                                   c: SCNVector3, dir: Float, data: inout CityData) {
        let w: Float = 14, d: Float = 14, wallH: Float = 4.0, t: Float = 0.4
        let doorGap: Float = 4.5

        let floorColor: UIColor
        switch brand.kind {
        case .restaurant: floorColor = UIColor(red: 0.62, green: 0.5, blue: 0.38, alpha: 1)
        case .bank:       floorColor = UIColor(red: 0.78, green: 0.76, blue: 0.72, alpha: 1)
        case .grocery:    floorColor = UIColor(red: 0.85, green: 0.85, blue: 0.84, alpha: 1)
        case .shop:       floorColor = UIColor(red: 0.7, green: 0.68, blue: 0.66, alpha: 1)
        }
        let floor = SCNNode(geometry: SCNBox(width: CGFloat(w - 0.6), height: 0.12,
                                             length: CGFloat(d - 0.6), chamferRadius: 0))
        floor.geometry?.firstMaterial?.diffuse.contents = floorColor
        floor.geometry?.firstMaterial?.lightingModel = .lambert
        floor.position = SCNVector3(c.x, 0.3, c.z)
        root.addChildNode(floor)

        wallBox(root, brand.primary, c.x, c.z - dir * (d / 2 - t / 2), w, t, wallH, &data)
        wallBox(root, brand.primary, c.x - (w / 2 - t / 2), c.z, t, d, wallH, &data)
        wallBox(root, brand.primary, c.x + (w / 2 - t / 2), c.z, t, d, wallH, &data)
        let seg = (w - doorGap) / 2
        for sx: Float in [-(doorGap / 2 + seg / 2), (doorGap / 2 + seg / 2)] {
            wallBox(root, brand.primary, c.x + sx, c.z + dir * (d / 2 - t / 2),
                    seg, t, wallH, &data)
        }

        for sx: Float in [-(doorGap / 2 + seg / 2), (doorGap / 2 + seg / 2)] {
            let glass = SCNNode(geometry: SCNBox(width: CGFloat(seg * 0.75), height: 2.2,
                                                 length: 0.08, chamferRadius: 0.02))
            glass.geometry?.firstMaterial?.diffuse.contents =
                UIColor(red: 0.6, green: 0.72, blue: 0.8, alpha: 1)
            glass.geometry?.firstMaterial?.lightingModel = .lambert
            glass.position = SCNVector3(c.x + sx, 1.7, c.z + dir * (d / 2 - t - 0.1))
            root.addChildNode(glass)
        }

        let header = SCNNode(geometry: SCNBox(width: CGFloat(doorGap + 0.6), height: 0.6,
                                              length: 0.6, chamferRadius: 0.05))
        header.geometry?.firstMaterial?.diffuse.contents = brand.accent
        header.geometry?.firstMaterial?.lightingModel = .lambert
        header.position = SCNVector3(c.x, wallH - 0.3, c.z + dir * (d / 2 - t / 2))
        root.addChildNode(header)

        for side: Float in [-1, 1] {
            let leaf = SCNNode(geometry: SCNBox(width: 0.1, height: 2.7, length: 1.5,
                                                chamferRadius: 0.02))
            leaf.geometry?.firstMaterial?.diffuse.contents =
                UIColor(red: 0.62, green: 0.76, blue: 0.85, alpha: 1)
            leaf.geometry?.firstMaterial?.lightingModel = .lambert
            leaf.position = SCNVector3(c.x + side * (doorGap / 2 + 0.3), 1.6,
                                       c.z + dir * (d / 2 + 0.6))
            leaf.eulerAngles.y = side * 0.6
            root.addChildNode(leaf)
        }

        let mat = SCNNode(geometry: SCNBox(width: CGFloat(doorGap), height: 0.05,
                                           length: 1.8, chamferRadius: 0))
        mat.geometry?.firstMaterial?.diffuse.contents = brand.accent
        mat.geometry?.firstMaterial?.lightingModel = .lambert
        mat.position = SCNVector3(c.x, 0.3, c.z + dir * (d / 2 + 1.2))
        root.addChildNode(mat)

        let sign = SCNNode(geometry: SCNBox(width: CGFloat(w * 0.9), height: 2.0,
                                            length: 0.3, chamferRadius: 0.08))
        sign.geometry?.firstMaterial?.diffuse.contents = brand.accent
        sign.geometry?.firstMaterial?.emission.contents =
            brand.accent.withAlphaComponent(0.55)
        sign.geometry?.firstMaterial?.lightingModel = .lambert
        sign.position = SCNVector3(c.x, wallH + 1.15, c.z + dir * (d / 2))
        root.addChildNode(sign)

        let panel = textPanel(brand.name, width: w * 0.86, height: 1.7,
                              textColor: brand.primary, bgColor: brand.accent)
        panel.position = SCNVector3(c.x, wallH + 1.15, c.z + dir * (d / 2 + 0.18))
        if dir < 0 { panel.eulerAngles.y = .pi }
        signRoot.addChildNode(panel)

        let roof = SCNNode(geometry: SCNBox(width: CGFloat(w + 0.6), height: 0.35,
                                            length: CGFloat(d + 0.6), chamferRadius: 0.05))
        roof.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.32, alpha: 1)
        roof.geometry?.firstMaterial?.lightingModel = .lambert
        roof.position = SCNVector3(c.x, wallH + 0.15, c.z)
        root.addChildNode(roof)

        let counterZ = c.z - dir * 4.4
        let counter = SCNNode(geometry: SCNBox(width: 8, height: 1.1, length: 1.0,
                                               chamferRadius: 0.06))
        counter.geometry?.firstMaterial?.diffuse.contents = brand.primary
        counter.geometry?.firstMaterial?.lightingModel = .lambert
        counter.position = SCNVector3(c.x, 0.8, counterZ)
        root.addChildNode(counter)

        switch brand.kind {
        case .restaurant:
            for tx: Float in [-4.5, 4.5] {
                let table = SCNNode(geometry: SCNCylinder(radius: 0.7, height: 0.9))
                table.geometry?.firstMaterial?.diffuse.contents =
                    UIColor(red: 0.5, green: 0.36, blue: 0.24, alpha: 1)
                table.geometry?.firstMaterial?.lightingModel = .lambert
                table.position = SCNVector3(c.x + tx, 0.7, c.z + dir * 2.6)
                root.addChildNode(table)
            }
            let menu = SCNNode(geometry: SCNBox(width: 6, height: 1.5, length: 0.1,
                                                chamferRadius: 0.03))
            menu.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.14, alpha: 1)
            menu.geometry?.firstMaterial?.emission.contents =
                UIColor(red: 0.45, green: 0.32, blue: 0.1, alpha: 1)
            menu.position = SCNVector3(c.x, 2.8, c.z - dir * (d / 2 - 0.6))
            root.addChildNode(menu)

        case .bank:
            for tx: Float in [-2.6, 0, 2.6] {
                let wicket = SCNNode(geometry: SCNBox(width: 0.08, height: 1.1, length: 0.9,
                                                      chamferRadius: 0.02))
                wicket.geometry?.firstMaterial?.diffuse.contents =
                    UIColor(white: 0.85, alpha: 1)
                wicket.geometry?.firstMaterial?.lightingModel = .lambert
                wicket.position = SCNVector3(c.x + tx, 1.75, counterZ)
                root.addChildNode(wicket)
            }
            let atm = SCNNode(geometry: SCNBox(width: 1.0, height: 1.9, length: 0.5,
                                               chamferRadius: 0.06))
            atm.geometry?.firstMaterial?.diffuse.contents = brand.primary
            atm.geometry?.firstMaterial?.lightingModel = .lambert
            atm.position = SCNVector3(c.x - 5.4, 1.2, c.z + dir * 3.2)
            root.addChildNode(atm)
            let screen = SCNNode(geometry: SCNBox(width: 0.6, height: 0.5, length: 0.06,
                                                  chamferRadius: 0.02))
            screen.geometry?.firstMaterial?.emission.contents =
                UIColor(red: 0.3, green: 0.6, blue: 0.45, alpha: 1)
            screen.position = SCNVector3(c.x - 5.4, 1.6, c.z + dir * 2.95)
            root.addChildNode(screen)

        case .grocery:
            for ax: Float in [-4.8, -1.6, 1.6, 4.8] {
                let shelf = SCNNode(geometry: SCNBox(width: 1.1, height: 1.7, length: 5.5,
                                                     chamferRadius: 0.05))
                shelf.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.74, alpha: 1)
                shelf.geometry?.firstMaterial?.lightingModel = .lambert
                shelf.position = SCNVector3(c.x + ax, 1.15, c.z + dir * 1.6)
                root.addChildNode(shelf)

                for k in 0..<4 {
                    let g = SCNNode(geometry: SCNBox(width: 0.4, height: 0.3, length: 0.4,
                                                     chamferRadius: 0.03))
                    g.geometry?.firstMaterial?.diffuse.contents =
                        UIColor(hue: CGFloat.random(in: 0...1), saturation: 0.6,
                                brightness: 0.85, alpha: 1)
                    g.geometry?.firstMaterial?.lightingModel = .lambert
                    g.position = SCNVector3(c.x + ax, 2.15,
                                            c.z + dir * (1.6 - 2.0 + Float(k) * 1.3))
                    root.addChildNode(g)
                }
            }
            let belt = SCNNode(geometry: SCNBox(width: 3, height: 0.1, length: 0.8,
                                                chamferRadius: 0.02))
            belt.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.2, alpha: 1)
            belt.geometry?.firstMaterial?.lightingModel = .lambert
            belt.position = SCNVector3(c.x, 1.15, counterZ + dir * 0.7)
            root.addChildNode(belt)

        case .shop:
            for ax: Float in [-4.5, 4.5] {
                let rack = SCNNode(geometry: SCNBox(width: 1.0, height: 1.6, length: 4.5,
                                                    chamferRadius: 0.05))
                rack.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.7, alpha: 1)
                rack.geometry?.firstMaterial?.lightingModel = .lambert
                rack.position = SCNVector3(c.x + ax, 1.1, c.z + dir * 1.6)
                root.addChildNode(rack)
            }
            let display = SCNNode(geometry: SCNBox(width: 2.6, height: 0.9, length: 1.2,
                                                   chamferRadius: 0.05))
            display.geometry?.firstMaterial?.diffuse.contents = brand.accent
            display.geometry?.firstMaterial?.lightingModel = .lambert
            display.position = SCNVector3(c.x, 0.75, c.z + dir * 4.2)
            root.addChildNode(display)
        }

        for lx: Float in [-4, 4] {
            let lamp = SCNNode(geometry: SCNBox(width: 2.8, height: 0.1, length: 0.5,
                                                chamferRadius: 0.02))
            lamp.geometry?.firstMaterial?.emission.contents =
                UIColor(red: 1, green: 0.96, blue: 0.86, alpha: 1)
            lamp.position = SCNVector3(c.x + lx, wallH - 0.35, c.z)
            root.addChildNode(lamp)
        }

        let zone = CGRect(x: CGFloat(c.x - w / 2), y: CGFloat(c.z - d / 2),
                          width: CGFloat(w), height: CGFloat(d))
        let servicePoint = SCNVector3(c.x, 0, counterZ + dir * 1.9)
        let workerPos = SCNVector3(c.x, 0, counterZ - dir * 1.3)
        let workerHeading: Float = dir > 0 ? 0 : .pi

        data.venues.append(Venue(name: brand.name, kind: brand.kind,
                                 door: servicePoint, zone: zone,
                                 workerPos: workerPos, workerHeading: workerHeading))
        data.workerSpots.append((workerPos, workerHeading))

        if brand.kind == .restaurant || brand.kind == .grocery {
            data.restaurantDoors.append(servicePoint)
            data.restaurantZones.append(zone)
            data.restaurantNames.append(brand.name)
        }
    }

    private static func buildHouse(_ root: SCNNode, c: SCNVector3, dir: Float,
                                   data: inout CityData) {
        let w: Float = 12, d: Float = 12, wallH: Float = 3.2, t: Float = 0.35
        let doorGap: Float = 3.4
        let wallColor = UIColor(red: 0.36, green: 0.54, blue: 0.74, alpha: 1)

        let floor = SCNNode(geometry: SCNBox(width: CGFloat(w - 0.6), height: 0.12,
                                             length: CGFloat(d - 0.6), chamferRadius: 0))
        floor.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.7, green: 0.6, blue: 0.5, alpha: 1)
        floor.geometry?.firstMaterial?.lightingModel = .lambert
        floor.position = SCNVector3(c.x, 0.3, c.z)
        root.addChildNode(floor)

        wallBox(root, wallColor, c.x, c.z - dir * (d / 2 - t / 2), w, t, wallH, &data)
        wallBox(root, wallColor, c.x - (w / 2 - t / 2), c.z, t, d, wallH, &data)
        wallBox(root, wallColor, c.x + (w / 2 - t / 2), c.z, t, d, wallH, &data)
        let seg = (w - doorGap) / 2
        for sx: Float in [-(doorGap / 2 + seg / 2), (doorGap / 2 + seg / 2)] {
            wallBox(root, wallColor, c.x + sx, c.z + dir * (d / 2 - t / 2),
                    seg, t, wallH, &data)
        }

        let header = SCNNode(geometry: SCNBox(width: CGFloat(doorGap + 0.5), height: 0.5,
                                              length: 0.5, chamferRadius: 0.04))
        header.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.35, green: 0.2, blue: 0.12, alpha: 1)
        header.geometry?.firstMaterial?.lightingModel = .lambert
        header.position = SCNVector3(c.x, wallH - 0.25, c.z + dir * (d / 2 - t / 2))
        root.addChildNode(header)

        let porch = SCNNode(geometry: SCNSphere(radius: 0.16))
        porch.geometry?.firstMaterial?.emission.contents =
            UIColor(red: 1, green: 0.9, blue: 0.6, alpha: 1)
        porch.position = SCNVector3(c.x + doorGap / 2 + 0.7, wallH - 0.5, c.z + dir * (d / 2))
        root.addChildNode(porch)

        let roof = SCNNode(geometry: SCNPyramid(width: CGFloat(w + 1.2), height: 2.6,
                                                length: CGFloat(d + 1.2)))
        roof.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.45, green: 0.26, blue: 0.2, alpha: 1)
        roof.geometry?.firstMaterial?.lightingModel = .lambert
        roof.position = SCNVector3(c.x, wallH + 0.24, c.z)
        root.addChildNode(roof)

        let couch = SCNNode(geometry: SCNBox(width: 2.8, height: 0.7, length: 1.0,
                                             chamferRadius: 0.12))
        couch.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.5, green: 0.35, blue: 0.3, alpha: 1)
        couch.geometry?.firstMaterial?.lightingModel = .lambert
        couch.position = SCNVector3(c.x - 2.8, 0.65, c.z - dir * 3.4)
        root.addChildNode(couch)

        let tv = SCNNode(geometry: SCNBox(width: 1.8, height: 1.0, length: 0.12,
                                          chamferRadius: 0.03))
        tv.geometry?.firstMaterial?.emission.contents =
            UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1)
        tv.position = SCNVector3(c.x + 2.9, 1.2, c.z - dir * 4.9)
        root.addChildNode(tv)

        let zone = CGRect(x: CGFloat(c.x - w / 2), y: CGFloat(c.z - d / 2),
                          width: CGFloat(w), height: CGFloat(d))
        data.houseZones.append(zone)
        data.houseDoors.append(SCNVector3(c.x, 0, c.z - dir * 1.8))
        data.customerSpots.append((SCNVector3(c.x, 0, c.z - dir * 3.8),
                                   dir > 0 ? Float.pi : 0))
        data.houseAddresses.append(randomAddress())
    }

    private static func buildLandmarks(_ root: SCNNode, offset: Float) {
        addCNTower(to: root, at: SCNVector3(-offset - 45, 0, offset + 45))
        addBMOField(to: root, at: SCNVector3(-offset - 80, 0, -40))
        addDundasSquare(to: root, at: SCNVector3(offset + 55, 0, 0))
        addScotiabankArena(to: root, at: SCNVector3(offset + 60, 0, offset + 75))
        addEatonCentre(to: root, at: SCNVector3(offset + 58, 0, -80))
        addChinatownGate(to: root, at: SCNVector3(-offset + roadW / 2, 0, 0))
    }

    private static func tower(_ root: SCNNode, _ mat: SCNMaterial, _ roof: SCNMaterial,
                              _ c: SCNVector3, _ w: Float, _ d: Float,
                              _ h: Float, _ y0: Float) {
        let geo = SCNBox(width: CGFloat(w), height: CGFloat(h),
                         length: CGFloat(d), chamferRadius: 0.2)
        let m = mat.copy() as! SCNMaterial
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(w / 8, h / 6, 1)
        geo.materials = [m, m, m, m, roof, roof]
        let node = SCNNode(geometry: geo)
        node.position = SCNVector3(c.x, y0 + h / 2, c.z)
        root.addChildNode(node)
    }

    private static func wallBox(_ root: SCNNode, _ color: UIColor,
                                _ cx: Float, _ cz: Float,
                                _ w: Float, _ dpt: Float, _ h: Float,
                                _ data: inout CityData) {
        let node = SCNNode(geometry: SCNBox(width: CGFloat(w), height: CGFloat(h),
                                            length: CGFloat(dpt), chamferRadius: 0))
        node.geometry?.firstMaterial?.diffuse.contents = color
        node.geometry?.firstMaterial?.lightingModel = .lambert
        node.position = SCNVector3(cx, h / 2 + 0.24, cz)
        root.addChildNode(node)
        data.buildingRects.append(CGRect(x: CGFloat(cx - w / 2), y: CGFloat(cz - dpt / 2),
                                         width: CGFloat(w), height: CGFloat(dpt)))
    }

    static func textPanel(_ string: String, width: Float, height: Float,
                          textColor: UIColor, bgColor: UIColor) -> SCNNode {

        let w = max(0.2, width)
        let h = max(0.1, height)
        let text = string.isEmpty ? " " : string
        let pxW = 512
        let pxH = max(64, Int(512.0 * Double(h / w)))
        let size = CGSize(width: pxW, height: pxH)

        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            bgColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            var fontSize = CGFloat(pxH) * 0.62
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            var attrs: [NSAttributedString.Key: Any] = [:]
            var textSize = CGSize.zero
            for _ in 0..<12 {
                let f = UIFont(name: "AvenirNext-Bold", size: fontSize)
                        ?? UIFont.boldSystemFont(ofSize: fontSize)
                attrs = [.font: f, .foregroundColor: textColor,
                         .paragraphStyle: para]
                textSize = (text as NSString).size(withAttributes: attrs)
                if textSize.width <= size.width * 0.92 { break }
                fontSize *= 0.88
            }
            let rect = CGRect(x: 0,
                              y: (size.height - textSize.height) / 2,
                              width: size.width,
                              height: max(1, textSize.height))
            (text as NSString).draw(in: rect, withAttributes: attrs)
        }

        let plane = SCNPlane(width: CGFloat(w), height: CGFloat(h))
        plane.firstMaterial?.diffuse.contents = image
        plane.firstMaterial?.emission.contents = image
        plane.firstMaterial?.lightingModel = .lambert
        plane.firstMaterial?.isDoubleSided = true
        return SCNNode(geometry: plane)
    }

    private static func matteBox(w: Float, h: Float, d: Float, color: UIColor) -> SCNNode {
        let geo = SCNBox(width: CGFloat(w), height: CGFloat(h),
                         length: CGFloat(d), chamferRadius: 0)
        geo.firstMaterial?.diffuse.contents = color
        geo.firstMaterial?.lightingModel = .lambert
        return SCNNode(geometry: geo)
    }

    private static let trunkGeo: SCNGeometry = {
        let g = SCNCylinder(radius: 0.22, height: 2.2)
        g.firstMaterial?.diffuse.contents =
            UIColor(red: 0.4, green: 0.28, blue: 0.18, alpha: 1)
        g.firstMaterial?.lightingModel = .lambert
        return g
    }()
    private static let leavesGeo: SCNGeometry = {
        let g = SCNSphere(radius: 1.5)
        g.segmentCount = 12
        g.firstMaterial?.diffuse.contents =
            UIColor(red: 0.22, green: 0.5, blue: 0.22, alpha: 1)
        g.firstMaterial?.lightingModel = .lambert
        return g
    }()

    private static func addTree(to root: SCNNode, at pos: SCNVector3) {
        let trunk = SCNNode(geometry: trunkGeo)
        trunk.position = SCNVector3(pos.x, pos.y + 1.1, pos.z)
        root.addChildNode(trunk)
        let leaves = SCNNode(geometry: leavesGeo)
        leaves.position = SCNVector3(pos.x, pos.y + 3.0, pos.z)
        root.addChildNode(leaves)
    }

    private static func addCNTower(to root: SCNNode, at pos: SCNVector3) {
        let concrete = SCNMaterial()
        concrete.diffuse.contents = UIColor(white: 0.82, alpha: 1)
        concrete.lightingModel = .lambert
        let shaft = SCNNode(geometry: SCNCone(topRadius: 2.2, bottomRadius: 5.5, height: 80))
        shaft.geometry?.materials = [concrete]
        shaft.position = SCNVector3(pos.x, 40, pos.z)
        root.addChildNode(shaft)
        let pod = SCNNode(geometry: SCNCylinder(radius: 8.5, height: 7))
        pod.geometry?.materials = [concrete]
        pod.position = SCNVector3(pos.x, 82, pos.z)
        root.addChildNode(pod)
        let podGlass = SCNNode(geometry: SCNCylinder(radius: 8.6, height: 2))
        podGlass.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.5, green: 0.7, blue: 0.85, alpha: 1)
        podGlass.geometry?.firstMaterial?.lightingModel = .lambert
        podGlass.position = SCNVector3(pos.x, 83.5, pos.z)
        root.addChildNode(podGlass)
        let upper = SCNNode(geometry: SCNCylinder(radius: 1.6, height: 18))
        upper.geometry?.materials = [concrete]
        upper.position = SCNVector3(pos.x, 94, pos.z)
        root.addChildNode(upper)
        let spire = SCNNode(geometry: SCNCone(topRadius: 0.05, bottomRadius: 1.0, height: 16))
        spire.geometry?.materials = [concrete]
        spire.position = SCNVector3(pos.x, 111, pos.z)
        root.addChildNode(spire)
    }

    private static func addBMOField(to root: SCNNode, at pos: SCNVector3) {
        let bowl = SCNNode(geometry: SCNTube(innerRadius: 16, outerRadius: 24, height: 9))
        bowl.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.55, alpha: 1)
        bowl.geometry?.firstMaterial?.lightingModel = .lambert
        bowl.position = SCNVector3(pos.x, 4.5, pos.z)
        root.addChildNode(bowl)

        let field = SCNNode(geometry: SCNCylinder(radius: 15.5, height: 0.15))
        field.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.2, green: 0.55, blue: 0.2, alpha: 1)
        field.geometry?.firstMaterial?.lightingModel = .lambert
        field.position = SCNVector3(pos.x, 0.1, pos.z)
        root.addChildNode(field)

        let sign = SCNNode(geometry: SCNBox(width: 12, height: 2.2, length: 0.5,
                                            chamferRadius: 0.1))
        sign.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.95, alpha: 1)
        sign.geometry?.firstMaterial?.emission.contents =
            UIColor(red: 0.1, green: 0.3, blue: 0.75, alpha: 1)
        sign.position = SCNVector3(pos.x, 10.2, pos.z + 22)
        root.addChildNode(sign)

        for (fx, fz) in [(-20.0, -20.0), (20.0, -20.0), (-20.0, 20.0), (20.0, 20.0)] {
            let mast = SCNNode(geometry: SCNCylinder(radius: 0.25, height: 16))
            mast.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.3, alpha: 1)
            mast.geometry?.firstMaterial?.lightingModel = .lambert
            mast.position = SCNVector3(pos.x + Float(fx), 8, pos.z + Float(fz))
            root.addChildNode(mast)
            let lamp = SCNNode(geometry: SCNBox(width: 2.2, height: 1.2, length: 0.4,
                                                chamferRadius: 0.1))
            lamp.geometry?.firstMaterial?.emission.contents = UIColor(white: 0.95, alpha: 1)
            lamp.position = SCNVector3(pos.x + Float(fx), 16.4, pos.z + Float(fz))
            root.addChildNode(lamp)
        }
    }

    private static func addScotiabankArena(to root: SCNNode, at pos: SCNVector3) {
        let shell = SCNNode(geometry: SCNBox(width: 48, height: 20, length: 42,
                                             chamferRadius: 3.5))
        shell.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.42, green: 0.45, blue: 0.5, alpha: 1)
        shell.geometry?.firstMaterial?.lightingModel = .lambert
        shell.position = SCNVector3(pos.x, 10, pos.z)
        root.addChildNode(shell)

        let glass = SCNNode(geometry: SCNBox(width: 46, height: 11, length: 1.2,
                                             chamferRadius: 0.6))
        glass.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.42, green: 0.56, blue: 0.7, alpha: 1)
        glass.geometry?.firstMaterial?.lightingModel = .lambert
        glass.position = SCNVector3(pos.x, 6, pos.z + 21.4)
        root.addChildNode(glass)

        let sign = SCNNode(geometry: SCNBox(width: 26, height: 4.2, length: 0.6,
                                            chamferRadius: 0.2))
        sign.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.90, green: 0.12, blue: 0.16, alpha: 1)
        sign.geometry?.firstMaterial?.emission.contents =
            UIColor(red: 0.8, green: 0.1, blue: 0.13, alpha: 1)
        sign.position = SCNVector3(pos.x, 16.6, pos.z + 21.6)
        root.addChildNode(sign)

        let panel = textPanel("SCOTIABANK ARENA", width: 22, height: 3.2,
                              textColor: .white,
                              bgColor: UIColor(red: 0.85, green: 0.1, blue: 0.13, alpha: 1))
        panel.position = SCNVector3(pos.x, 16.6, pos.z + 22.0)
        signRoot.addChildNode(panel)
    }

    private static func addEatonCentre(to root: SCNNode, at pos: SCNVector3) {
        let block = SCNNode(geometry: SCNBox(width: 32, height: 22, length: 64,
                                             chamferRadius: 1.2))
        block.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.72, green: 0.72, blue: 0.74, alpha: 1)
        block.geometry?.firstMaterial?.lightingModel = .lambert
        block.position = SCNVector3(pos.x, 11, pos.z)
        root.addChildNode(block)

        let vault = SCNNode(geometry: SCNCylinder(radius: 9, height: 62))
        vault.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.7, green: 0.85, blue: 0.92, alpha: 1)
        vault.geometry?.firstMaterial?.lightingModel = .lambert
        vault.eulerAngles.x = Float.pi / 2
        vault.position = SCNVector3(pos.x, 22.5, pos.z)
        root.addChildNode(vault)

        let sign = SCNNode(geometry: SCNBox(width: 17, height: 2.9, length: 0.5,
                                            chamferRadius: 0.15))
        sign.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.14, alpha: 1)
        sign.geometry?.firstMaterial?.emission.contents = UIColor(white: 0.3, alpha: 1)
        sign.position = SCNVector3(pos.x, 18, pos.z - 32.4)
        root.addChildNode(sign)

        let panel = textPanel("EATON CENTRE", width: 15, height: 2.4,
                              textColor: .white,
                              bgColor: UIColor(white: 0.14, alpha: 1))
        panel.position = SCNVector3(pos.x, 18, pos.z - 32.8)
        panel.eulerAngles.y = .pi
        signRoot.addChildNode(panel)
    }

    private static func addDundasSquare(to root: SCNNode, at pos: SCNVector3) {
        let plaza = SCNNode(geometry: SCNBox(width: 28, height: 0.2, length: 28,
                                             chamferRadius: 0))
        plaza.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.62, green: 0.58, blue: 0.55, alpha: 1)
        plaza.geometry?.firstMaterial?.lightingModel = .lambert
        plaza.position = SCNVector3(pos.x, 0.3, pos.z)
        root.addChildNode(plaza)

        let boardColors: [UIColor] = [
            UIColor(red: 0.9, green: 0.15, blue: 0.3, alpha: 1),
            UIColor(red: 0.15, green: 0.6, blue: 0.9, alpha: 1),
            UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1),
            UIColor(red: 0.3, green: 0.8, blue: 0.45, alpha: 1),
        ]
        let spots: [(Float, Float)] = [(-12, -12), (12, -12), (-12, 12), (12, 12)]
        for (i, sp) in spots.enumerated() {
            let mast = SCNNode(geometry: SCNBox(width: 0.6, height: 12, length: 0.6,
                                                chamferRadius: 0.05))
            mast.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.2, alpha: 1)
            mast.geometry?.firstMaterial?.lightingModel = .lambert
            mast.position = SCNVector3(pos.x + sp.0, 6, pos.z + sp.1)
            root.addChildNode(mast)

            let board = SCNNode(geometry: SCNBox(width: 7.5, height: 4.6, length: 0.3,
                                                 chamferRadius: 0.1))
            board.geometry?.firstMaterial?.diffuse.contents = boardColors[i % 4]
            board.geometry?.firstMaterial?.emission.contents = boardColors[i % 4]
            board.position = SCNVector3(pos.x + sp.0, 10.5, pos.z + sp.1)
            board.eulerAngles.y = Float(i) * Float.pi / 2
            root.addChildNode(board)
        }

        let basin = SCNNode(geometry: SCNCylinder(radius: 3.4, height: 0.6))
        basin.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.72, alpha: 1)
        basin.geometry?.firstMaterial?.lightingModel = .lambert
        basin.position = SCNVector3(pos.x, 0.6, pos.z)
        root.addChildNode(basin)

        let w2 = SCNNode(geometry: SCNCylinder(radius: 3.1, height: 0.7))
        w2.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.25, green: 0.55, blue: 0.75, alpha: 1)
        w2.geometry?.firstMaterial?.lightingModel = .lambert
        w2.position = SCNVector3(pos.x, 0.72, pos.z)
        root.addChildNode(w2)
    }

    private static func addChinatownGate(to root: SCNNode, at pos: SCNVector3) {
        let red = UIColor(red: 0.78, green: 0.15, blue: 0.14, alpha: 1)
        let gold = UIColor(red: 0.9, green: 0.75, blue: 0.28, alpha: 1)

        for px: Float in [-10.5, 10.5] {
            let pillar = SCNNode(geometry: SCNBox(width: 1.4, height: 11, length: 1.4,
                                                  chamferRadius: 0.1))
            pillar.geometry?.firstMaterial?.diffuse.contents = red
            pillar.geometry?.firstMaterial?.lightingModel = .lambert
            pillar.position = SCNVector3(pos.x + px, 5.5, pos.z)
            root.addChildNode(pillar)
        }
        for (i, y) in [(0, 11.6), (1, 13.4)] {
            let width: CGFloat = i == 0 ? 25 : 16
            let roof = SCNNode(geometry: SCNBox(width: width, height: 0.7, length: 3.4,
                                                chamferRadius: 0.2))
            roof.geometry?.firstMaterial?.diffuse.contents = gold
            roof.geometry?.firstMaterial?.emission.contents =
                UIColor(red: 0.3, green: 0.24, blue: 0.06, alpha: 1)
            roof.position = SCNVector3(pos.x, Float(y), pos.z)
            root.addChildNode(roof)
        }
        let panel = SCNNode(geometry: SCNBox(width: 13, height: 1.9, length: 0.4,
                                             chamferRadius: 0.1))
        panel.geometry?.firstMaterial?.diffuse.contents = red
        panel.geometry?.firstMaterial?.emission.contents =
            UIColor(red: 0.5, green: 0.08, blue: 0.06, alpha: 1)
        panel.position = SCNVector3(pos.x, 10.2, pos.z)
        root.addChildNode(panel)
    }

    static func minimapImage(data: CityData) -> UIImage {
        let px: CGFloat = 256
        let s = px / CGFloat(total)
        func mp(_ x: Float, _ z: Float) -> CGPoint {
            CGPoint(x: CGFloat(x + total / 2) * s, y: CGFloat(z + total / 2) * s)
        }
        return UIGraphicsImageRenderer(size: CGSize(width: px, height: px)).image { ctx in
            UIColor(red: 0.16, green: 0.24, blue: 0.16, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: px, height: px))

            UIColor(white: 0.5, alpha: 1).setFill()
            for k in 0...blocks {
                let c = CGFloat(Float(k) * pitch) * s
                ctx.fill(CGRect(x: 0, y: c, width: px, height: CGFloat(roadW) * s))
                ctx.fill(CGRect(x: c, y: 0, width: CGFloat(roadW) * s, height: px))
            }
            UIColor(red: 0.55, green: 0.58, blue: 0.68, alpha: 1).setFill()
            for r in data.buildingRects {
                let o = mp(Float(r.minX), Float(r.minY))
                ctx.fill(CGRect(x: o.x, y: o.y, width: r.width * s, height: r.height * s))
            }

            UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1).setFill()
            let ty = mp(0, midRoadZ).y
            ctx.fill(CGRect(x: 0, y: ty - 1.5, width: px, height: 3))
        }
    }

    private static func windowTexture(base: UIColor, pane: UIColor,
                                      litChance: Double) -> UIImage {
        let size = CGSize(width: 128, height: 128)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            base.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let cols = 6, rows = 8
            let cw = size.width / CGFloat(cols)
            let ch = size.height / CGFloat(rows)

            UIColor(white: 0, alpha: 0.3).setFill()
            for r in 0..<rows {
                ctx.fill(CGRect(x: 0, y: CGFloat(r) * ch + ch * 0.82,
                                width: size.width, height: ch * 0.18))
            }
            UIColor(white: 0, alpha: 0.2).setFill()
            for c in 0...cols {
                ctx.fill(CGRect(x: CGFloat(c) * cw - 1, y: 0, width: 2, height: size.height))
            }
            for r in 0..<rows {
                for c in 0..<cols {
                    let lit = Double.random(in: 0...1) < litChance
                    (lit ? UIColor(red: 1, green: 0.9, blue: 0.6, alpha: 1) : pane).setFill()
                    ctx.fill(CGRect(x: CGFloat(c) * cw + cw * 0.18,
                                    y: CGFloat(r) * ch + ch * 0.16,
                                    width: cw * 0.64, height: ch * 0.58))
                }
            }
        }
    }
}
