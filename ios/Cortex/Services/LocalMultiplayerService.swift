import Foundation
import MultipeerConnectivity
import Observation

/// Peer-to-peer local-network duel: no server, no account needed. Every
/// device on the same Wi-Fi/Bluetooth mesh advertises and browses at once,
/// auto-connects to whoever it finds, and the lobby grid fills as peers
/// join — exactly like the built-in party lobbies, just over Multipeer
/// instead of a websocket.
@Observable
final class LocalMultiplayerService: NSObject {
    enum Wire {
        /// Broadcast once by whoever taps "Préparer": every device (including
        /// the sender) then plays the exact same seeded question set.
        struct Start: Codable { let seed: String; let questionCount: Int; let roundDuration: Double }
        /// Sent by each device once it finishes its own run.
        struct Finished: Codable { let score: Int }
        /// Broadcast by the aggregator once everyone has reported in.
        struct Final: Codable { let scores: [String: Int] }
    }

    private enum MessageType: String, Codable { case start, finished, final }
    private struct Envelope<T: Codable>: Codable { let type: MessageType; let payload: T }

    private(set) var myName: String
    private(set) var myEmoji: String
    private(set) var connectedPeers: [MCPeerID] = []
    private(set) var startPayload: Wire.Start?
    private(set) var finalScores: [String: Int]?
    /// Scores gathered so far by whichever device ends up aggregating.
    private(set) var incomingScores: [String: Int] = [:]

    private let serviceType = "minduel-duel"
    private let peerID: MCPeerID
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    /// Deterministic across every connected device without extra
    /// coordination: whoever's name sorts first is responsible for
    /// aggregating final scores and broadcasting the result.
    private var isAggregator: Bool {
        let all = ([myName] + connectedPeers.map(\.displayName)).sorted()
        return all.first == myName
    }

    init(displayName: String, emoji: String) {
        // Suffix keeps two people with the same first name distinguishable on
        // the same network without ever showing the raw suffix in the UI.
        let unique = "\(displayName)#\(Int.random(in: 100...999))"
        self.myName = displayName
        self.myEmoji = emoji
        self.peerID = MCPeerID(displayName: unique)
        super.init()
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: ["name": displayName, "emoji": emoji], serviceType: serviceType)
        advertiser.delegate = self
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
    }

    func startDiscovery() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func stopDiscovery() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
    }

    func disconnect() {
        stopDiscovery()
        session.disconnect()
    }

    /// Only meaningful for whoever taps "Préparer" — every connected peer
    /// receives the same seed and starts its own local run at once.
    func broadcastStart(seed: String, questionCount: Int, roundDuration: Double) {
        let payload = Wire.Start(seed: seed, questionCount: questionCount, roundDuration: roundDuration)
        startPayload = payload
        send(Envelope(type: .start, payload: payload))
        Task { @MainActor [weak self] in self?.registerScore(name: self?.myName ?? "", score: nil) }
    }

    /// Called by every device once its own local run is over.
    func reportFinished(score: Int) {
        send(Envelope(type: .finished, payload: Wire.Finished(score: score)))
        registerScore(name: myName, score: score)
    }

    private func registerScore(name: String, score: Int?) {
        guard let score else { return }
        incomingScores[name] = score
        finalizeIfReady()
    }

    private func finalizeIfReady() {
        guard isAggregator else { return }
        let everyone = Set([myName] + connectedPeers.map(\.displayName))
        guard Set(incomingScores.keys).isSuperset(of: everyone) else { return }
        let payload = Wire.Final(scores: incomingScores)
        finalScores = payload.scores
        send(Envelope(type: .final, payload: payload))
    }

    private func send<T: Codable>(_ envelope: Envelope<T>) {
        guard !session.connectedPeers.isEmpty, let data = try? JSONEncoder().encode(envelope) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    private func handle(_ data: Data) {
        guard let type = try? JSONDecoder().decode(TypeProbe.self, from: data).type else { return }
        switch type {
        case .start:
            guard let envelope = try? JSONDecoder().decode(Envelope<Wire.Start>.self, from: data) else { return }
            Task { @MainActor [weak self] in self?.startPayload = envelope.payload }
        case .finished:
            // We only care about *our own* peer's finished score, learned via
            // the sender's identity from the session delegate callback below.
            break
        case .final:
            guard let envelope = try? JSONDecoder().decode(Envelope<Wire.Final>.self, from: data) else { return }
            Task { @MainActor [weak self] in self?.finalScores = envelope.payload.scores }
        }
    }

    private struct TypeProbe: Codable { let type: MessageType }

    private func handleFinished(_ data: Data, from peer: MCPeerID) {
        guard let envelope = try? JSONDecoder().decode(Envelope<Wire.Finished>.self, from: data) else { return }
        Task { @MainActor [weak self] in self?.registerScore(name: peer.displayName, score: envelope.payload.score) }
    }
}

extension LocalMultiplayerService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.connectedPeers = session.connectedPeers
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let probe = try? JSONDecoder().decode(TypeProbe.self, from: data), probe.type == .finished {
            handleFinished(data, from: peerID)
        } else {
            handle(data)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension LocalMultiplayerService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

extension LocalMultiplayerService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
