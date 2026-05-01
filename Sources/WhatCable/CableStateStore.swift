import Combine
import Foundation

@MainActor
final class CableStateStore: ObservableObject {
    static let shared = CableStateStore()

    @Published private(set) var ports: [USBCPort] = []
    @Published private(set) var devices: [USBDevice] = []
    @Published private(set) var sources: [PowerSource] = []
    @Published private(set) var identities: [PDIdentity] = []

    private let portWatcher = USBCPortWatcher()
    private let deviceWatcher = USBWatcher()
    private let powerWatcher = PowerSourceWatcher()
    private let pdWatcher = PDIdentityWatcher()
    private var cancellables = Set<AnyCancellable>()
    private var isRunning = false

    private init() {
        portWatcher.$ports
            .sink { [weak self] in self?.ports = $0 }
            .store(in: &cancellables)
        deviceWatcher.$devices
            .sink { [weak self] in self?.devices = $0 }
            .store(in: &cancellables)
        powerWatcher.$sources
            .sink { [weak self] in self?.sources = $0 }
            .store(in: &cancellables)
        pdWatcher.$identities
            .sink { [weak self] in self?.identities = $0 }
            .store(in: &cancellables)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        portWatcher.start()
        deviceWatcher.start()
        powerWatcher.start()
        pdWatcher.start()
    }

    func refresh() {
        start()
        portWatcher.refresh()
        deviceWatcher.refresh()
        powerWatcher.refresh()
        pdWatcher.refresh()
    }

    func sources(for port: USBCPort) -> [PowerSource] {
        guard let key = port.portKey else { return [] }
        return sources.filter { $0.portKey == key }
    }

    func identities(for port: USBCPort) -> [PDIdentity] {
        guard let key = port.portKey else { return [] }
        return identities.filter { $0.portKey == key }
    }
}
