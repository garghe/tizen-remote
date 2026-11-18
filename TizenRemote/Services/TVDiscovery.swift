import Foundation

/// Finds Samsung TVs by probing every address on the local /24 subnet
/// for Samsung's REST endpoint (http://<ip>:8001/api/v2/).
/// This avoids SSDP multicast, which needs a special Apple entitlement.
@MainActor
final class TVDiscovery: ObservableObject {
    @Published private(set) var tvs: [SamsungTV] = Storage.knownTVs
    @Published private(set) var isScanning = false
    @Published var errorMessage: String?

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1.5
        config.timeoutIntervalForResource = 2.5
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    func scan() async {
        guard !isScanning else { return }
        guard let prefix = NetworkInfo.subnetPrefix() else {
            errorMessage = "Connect your iPhone to the same Wi-Fi as your TV."
            return
        }
        isScanning = true
        errorMessage = nil
        defer { isScanning = false }

        let hosts = (1...254).map { "\(prefix).\($0)" }
        var iterator = hosts.makeIterator()
        let maxConcurrent = 48

        await withTaskGroup(of: SamsungTV?.self) { group in
            for _ in 0..<maxConcurrent {
                if let host = iterator.next() { group.addTask { await Self.probe(host) } }
            }
            while let result = await group.next() {
                if let tv = result { add(tv) }
                if let host = iterator.next() { group.addTask { await Self.probe(host) } }
            }
        }

        if tvs.isEmpty {
            errorMessage = "No Samsung TVs found. Make sure the TV is on and on the same Wi-Fi."
        }
    }

    /// Checks a single IP (used for manual entry).
    func add(ip: String) async -> SamsungTV? {
        guard let tv = await Self.probe(ip.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = "No Samsung TV answered at \(ip)."
            return nil
        }
        add(tv)
        return tv
    }

    func forget(_ tv: SamsungTV) {
        Storage.forget(tv)
        tvs.removeAll { $0.id == tv.id }
    }

    private func add(_ tv: SamsungTV) {
        if let index = tvs.firstIndex(where: { $0.id == tv.id }) {
            tvs[index] = tv   // refresh IP in case it changed
        } else {
            tvs.append(tv)
        }
    }

    nonisolated static func probe(_ ip: String) async -> SamsungTV? {
        guard let url = URL(string: "http://\(ip):8001/api/v2/") else { return nil }
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let info = try? JSONDecoder().decode(DeviceInfo.self, from: data),
              let device = info.device else { return nil }

        let isSamsungTV = (device.type?.localizedCaseInsensitiveContains("tv") ?? false)
            || device.OS?.lowercased() == "tizen"
        guard isSamsungTV else { return nil }

        return SamsungTV(
            id: device.id ?? info.id ?? ip,
            name: (device.name ?? info.name ?? "Samsung TV").htmlDecoded,
            ip: ip,
            model: device.modelName,
            mac: device.wifiMac
        )
    }

    private struct DeviceInfo: Decodable {
        struct Device: Decodable {
            let id: String?
            let name: String?
            let modelName: String?
            let wifiMac: String?
            let type: String?
            let OS: String?
        }
        let device: Device?
        let id: String?
        let name: String?
    }
}

private extension String {
    var htmlDecoded: String {
        replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
