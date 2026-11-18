import SwiftUI

struct DiscoveryView: View {
    @StateObject private var discovery = TVDiscovery()
    @State private var selected: SamsungTV?
    @State private var showManualEntry = false
    @State private var manualIP = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(discovery.tvs) { tv in
                        Button { selected = tv } label: { row(for: tv) }
                            .swipeActions {
                                Button("Forget", role: .destructive) { discovery.forget(tv) }
                            }
                    }
                } header: {
                    HStack {
                        Text("TVs on your network")
                        Spacer()
                        if discovery.isScanning { ProgressView() }
                    }
                } footer: {
                    if let message = discovery.errorMessage, !discovery.isScanning {
                        Text(message)
                    }
                }
            }
            .navigationTitle("TV Remote")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showManualEntry = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add TV by IP address")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await discovery.scan() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(discovery.isScanning)
                    .accessibilityLabel("Scan again")
                }
            }
            .refreshable { await discovery.scan() }
            .task { await discovery.scan() }
            .navigationDestination(item: $selected) { tv in
                RemoteView(tv: tv)
            }
            .alert("Add TV", isPresented: $showManualEntry) {
                TextField("192.168.1.50", text: $manualIP)
                    .keyboardType(.decimalPad)
                Button("Add") {
                    let ip = manualIP
                    Task {
                        if let tv = await discovery.add(ip: ip) { selected = tv }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter the TV's IP address (TV Settings › General › Network › Network Status).")
            }
        }
    }

    private func row(for tv: SamsungTV) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "tv")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(tv.name).font(.headline).foregroundStyle(.primary)
                Text([tv.model, tv.ip].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if tv.id == Storage.lastTVId {
                Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
            }
            Image(systemName: "chevron.right").foregroundStyle(.tertiary).font(.caption)
        }
        .padding(.vertical, 4)
    }
}
