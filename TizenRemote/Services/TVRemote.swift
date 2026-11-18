import Foundation
import UIKit

/// Talks to a Samsung Tizen TV over its secure WebSocket API (port 8002).
/// First connection shows an "Allow" prompt on the TV; the token is then saved.
@MainActor
final class TVRemote: NSObject, ObservableObject {
    enum State: Equatable {
        case disconnected
        case connecting
        case waitingForApproval
        case connected
        case failed(String)
    }

    @Published private(set) var state: State = .disconnected
    let tv: SamsungTV

    private static let clientName = "iPhone Remote"
    private static let session = URLSession(configuration: .default, delegate: LocalTrustDelegate(), delegateQueue: nil)
    private var session: URLSession { Self.session }
    private var poweredOff = false
    private var socket: URLSessionWebSocketTask?
    private var timeoutTask: Task<Void, Never>?

    init(tv: SamsungTV) {
        self.tv = tv
        super.init()
    }

    var isConnected: Bool { state == .connected }

    // MARK: Connection

    func connect() {
        if state == .connected || state == .connecting || state == .waitingForApproval { return }

        var components = URLComponents()
        components.scheme = "wss"
        components.host = tv.ip
        components.port = 8002
        components.path = "/api/v2/channels/samsung.remote.control"
        var query = [URLQueryItem(name: "name", value: Data(Self.clientName.utf8).base64EncodedString())]
        let token = Storage.token(for: tv.id)
        if let token { query.append(URLQueryItem(name: "token", value: token)) }
        components.queryItems = query
        guard let url = components.url else { return }

        let task = session.webSocketTask(with: url)
        socket = task
        state = token == nil ? .waitingForApproval : .connecting
        task.resume()
        listen(on: task)

        // The TV's approval prompt waits ~30s.
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(35))
            guard let self, !Task.isCancelled, self.socket === task, self.state != .connected else { return }
            self.fail("The TV didn't respond. Check it's on and try again.")
        }
    }

    func disconnect() {
        timeoutTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        state = .disconnected
    }

    private func fail(_ message: String) {
        timeoutTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        state = .failed(message)
    }

    private func listen(on task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            Task { @MainActor in
                guard let self, self.socket === task else { return }
                switch result {
                case .failure:
                    if self.poweredOff {
                        self.fail("TV is off. Tap Power to turn it on.")
                    } else {
                        self.fail(self.state == .connected
                                  ? "Connection to the TV was lost."
                                  : "Couldn't connect to the TV.")
                    }
                case .success(let message):
                    if case .string(let text) = message { self.handle(text) }
                    self.listen(on: task)
                }
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else { return }

        switch event {
        case "ms.channel.connect":
            if let payload = json["data"] as? [String: Any], let token = payload["token"] as? String {
                Storage.setToken(token, for: tv.id)
            }
            timeoutTask?.cancel()
            poweredOff = false
            state = .connected
            Storage.remember(tv)
        case "ms.channel.unauthorized":
            fail("Access was denied on the TV. Allow \"\(Self.clientName)\" in TV Settings › General › External Device Manager › Device Connection Manager.")
        case "ms.channel.timeOut":
            fail("No response to the TV prompt. Try again and press Allow on the TV.")
        default:
            break
        }
    }

    // MARK: Commands

    func send(_ key: RemoteKey) {
        haptic()
        sendJSON([
            "method": "ms.remote.control",
            "params": [
                "Cmd": "Click",
                "DataOfCmd": key.rawValue,
                "Option": "false",
                "TypeOfRemote": "SendRemoteKey",
            ],
        ])
    }

    func launch(_ app: TVApp) {
        haptic()
        sendJSON([
            "method": "ms.channel.emit",
            "params": [
                "event": "ed.apps.launch",
                "to": "host",
                "data": [
                    "appId": app.id,
                    "action_type": "DEEP_LINK",
                ],
            ],
        ])
    }

    /// Power: toggles via the API when connected; otherwise sends Wake-on-LAN and reconnects.
    func power() {
        if isConnected {
            poweredOff = true
            send(.power)
            return
        }
        poweredOff = false
        haptic()
        if let mac = tv.mac {
            WakeOnLAN.wake(mac: mac, ip: tv.ip)
        }
        state = .connecting
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self else { return }
            if self.state == .connecting && self.socket == nil { self.state = .disconnected }
            self.connect()
        }
    }

    private func sendJSON(_ object: [String: Any]) {
        guard isConnected, let socket,
              let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else {
            if !isConnected { connect() }
            return
        }
        socket.send(.string(text)) { _ in }
    }

    private func haptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// The TV uses a self-signed certificate. Accept it only for private LAN addresses.
private final class LocalTrustDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let space = challenge.protectionSpace
        if space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = space.serverTrust,
           Self.isPrivateIPv4(space.host) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    private static func isPrivateIPv4(_ host: String) -> Bool {
        let p = host.split(separator: ".").compactMap { Int($0) }
        guard p.count == 4 else { return false }
        return p[0] == 10
            || (p[0] == 192 && p[1] == 168)
            || (p[0] == 172 && (16...31).contains(p[1]))
    }
}
