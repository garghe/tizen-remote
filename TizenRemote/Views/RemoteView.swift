import SwiftUI

struct RemoteView: View {
    @StateObject private var remote: TVRemote
    @Environment(\.scenePhase) private var scenePhase

    init(tv: SamsungTV) {
        _remote = StateObject(wrappedValue: TVRemote(tv: tv))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                statusBanner

                // Top row: Power, Source, Mute
                HStack {
                    RoundButton(systemImage: "power", label: "Power", tint: .red) { remote.power() }
                    Spacer()
                    RoundButton(systemImage: "rectangle.on.rectangle", label: "Source") { remote.send(.source) }
                    Spacer()
                    RoundButton(systemImage: "speaker.slash.fill", label: "Mute") { remote.send(.mute) }
                }
                .padding(.horizontal, 12)

                // App shortcuts
                HStack(spacing: 12) {
                    ForEach(TVApp.shortcuts) { app in
                        Button { remote.launch(app) } label: {
                            Text(app.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(Color(hex: app.colorHex), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12)))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }

                DPad(remote: remote)

                // Back / Home + Volume
                HStack(alignment: .center) {
                    VStack(spacing: 20) {
                        RoundButton(systemImage: "arrow.uturn.backward", label: "Back") { remote.send(.back) }
                        RoundButton(systemImage: "house.fill", label: "Home") { remote.send(.home) }
                    }
                    Spacer()
                    VolumeRocker(remote: remote)
                }
                .padding(.horizontal, 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(white: 0.06).ignoresSafeArea())
        .navigationTitle(remote.tv.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { remote.connect() }
        .onDisappear { remote.disconnect() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { remote.connect() }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch remote.state {
        case .connected:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .font(.footnote).foregroundStyle(.green)
        case .connecting:
            Label("Connecting…", systemImage: "antenna.radiowaves.left.and.right")
                .font(.footnote).foregroundStyle(.secondary)
        case .waitingForApproval:
            Label("Press Allow on your TV", systemImage: "hand.tap.fill")
                .font(.footnote.bold()).foregroundStyle(.yellow)
        case .disconnected:
            Button("Connect") { remote.connect() }.font(.footnote)
        case .failed(let message):
            VStack(spacing: 6) {
                Text(message).font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center)
                Button("Retry") { remote.connect() }.font(.footnote.bold())
            }
        }
    }
}

// MARK: - Components

private struct DPad: View {
    @ObservedObject var remote: TVRemote

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.16))
                .overlay(Circle().stroke(.white.opacity(0.08)))
            VStack {
                arrow("chevron.up", .up)
                Spacer()
                arrow("chevron.down", .down)
            }
            .padding(10)
            HStack {
                arrow("chevron.left", .left)
                Spacer()
                arrow("chevron.right", .right)
            }
            .padding(10)

            Button { remote.send(.ok) } label: {
                Text("OK")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(Circle().fill(Color.accentColor))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("OK")
        }
        .frame(width: 260, height: 260)
    }

    private func arrow(_ symbol: String, _ key: RemoteKey) -> some View {
        RepeatButton(action: { remote.send(key) }) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(describing: key))
    }
}

private struct VolumeRocker: View {
    @ObservedObject var remote: TVRemote

    var body: some View {
        VStack(spacing: 0) {
            RepeatButton(action: { remote.send(.volumeUp) }) {
                Image(systemName: "plus").frame(width: 72, height: 72).contentShape(Rectangle())
            }
            .accessibilityLabel("Volume up")
            Text("VOL").font(.caption2.bold()).foregroundStyle(.secondary)
            RepeatButton(action: { remote.send(.volumeDown) }) {
                Image(systemName: "minus").frame(width: 72, height: 72).contentShape(Rectangle())
            }
            .accessibilityLabel("Volume down")
        }
        .font(.title2.weight(.semibold))
        .foregroundStyle(.white)
        .background(Capsule().fill(Color(white: 0.16)))
        .overlay(Capsule().stroke(.white.opacity(0.08)))
    }
}

private struct RoundButton: View {
    let systemImage: String
    let label: String
    var tint: Color = Color(white: 0.2)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(tint))
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

/// Fires once on tap, then repeats while held (for volume and arrows).
private struct RepeatButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var timer: Timer?
    @State private var pressed = false

    var body: some View {
        label()
            .opacity(pressed ? 0.5 : 1)
            .scaleEffect(pressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.1), value: pressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressed else { return }
                        pressed = true
                        action()
                        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { _ in
                            timer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { _ in action() }
                        }
                    }
                    .onEnded { _ in
                        pressed = false
                        timer?.invalidate()
                        timer = nil
                    }
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
