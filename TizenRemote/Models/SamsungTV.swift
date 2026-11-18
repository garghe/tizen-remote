import Foundation

/// A Samsung TV found on the local network.
struct SamsungTV: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var ip: String
    var model: String?
    var mac: String?
}

/// Remote control key codes understood by Tizen TVs.
enum RemoteKey: String {
    case power = "KEY_POWER"
    case source = "KEY_SOURCE"
    case mute = "KEY_MUTE"
    case volumeUp = "KEY_VOLUP"
    case volumeDown = "KEY_VOLDOWN"
    case up = "KEY_UP"
    case down = "KEY_DOWN"
    case left = "KEY_LEFT"
    case right = "KEY_RIGHT"
    case ok = "KEY_ENTER"
    case back = "KEY_RETURN"
    case home = "KEY_HOME"
}

/// App shortcuts shown on the remote.
struct TVApp: Identifiable {
    let id: String      // Tizen app id
    let name: String
    let colorHex: UInt32

    static let shortcuts: [TVApp] = [
        TVApp(id: "3201907018807", name: "Netflix", colorHex: 0xE50914),
        TVApp(id: "3201901017640", name: "Disney+", colorHex: 0x0E2C6B),
        TVApp(id: "3201807016597", name: "Apple TV", colorHex: 0x1C1C1E),
    ]
}
