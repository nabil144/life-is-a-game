import Foundation

public struct MazeJoystick: Sendable {
    public let offset: CGPoint
    public let direction: MazeGameBoard.Direction?
    public let speed: Double

    public init(displacement: CGPoint) {
        let radius: CGFloat = 44
        let deadZone: CGFloat = 8
        let distance = hypot(displacement.x, displacement.y)
        guard distance.isFinite, distance > deadZone else {
            offset = .zero
            direction = nil
            speed = 0
            return
        }
        let scale = min(1, radius / distance)
        offset = CGPoint(x: displacement.x * scale, y: displacement.y * scale)
        if abs(displacement.x) > abs(displacement.y) {
            direction = displacement.x > 0 ? .right : .left
        } else {
            direction = displacement.y > 0 ? .down : .up
        }
        speed = Double(0.35 + 0.65 * min(1, (distance - deadZone) / (radius - deadZone)))
    }
}
