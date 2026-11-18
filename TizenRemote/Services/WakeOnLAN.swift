import Foundation
import Network

/// Sends a Wake-on-LAN "magic packet" to turn the TV on.
/// Requires "Power On with Mobile" / network standby enabled on the TV.
enum WakeOnLAN {
    static func wake(mac: String, ip: String) {
        let bytes = mac.split(whereSeparator: { $0 == ":" || $0 == "-" }).compactMap { UInt8($0, radix: 16) }
        guard bytes.count == 6 else { return }

        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet.append(contentsOf: bytes) }

        // Unicast to the TV, plus the subnet broadcast address.
        // (Broadcast may be blocked by iOS without the multicast entitlement; unicast still often works.)
        var targets = [ip]
        let parts = ip.split(separator: ".")
        if parts.count == 4 { targets.append(parts.prefix(3).joined(separator: ".") + ".255") }

        for target in targets {
            for port: NWEndpoint.Port in [9, 7] {
                let connection = NWConnection(host: NWEndpoint.Host(target), port: port, using: .udp)
                connection.stateUpdateHandler = { state in
                    if case .failed = state { connection.cancel() }
                }
                connection.start(queue: .global(qos: .userInitiated))
                connection.send(content: packet, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
    }
}
