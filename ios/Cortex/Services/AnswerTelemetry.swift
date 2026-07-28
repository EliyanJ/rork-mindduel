import Foundation

/// Fire-and-forget collection of "who answered what, how fast, and what they
/// picked instead" — the raw material the admin calibration tool uses to learn
/// each question's real difficulty.
///
/// Design constraints that shape this whole type:
/// - It must never slow down or interrupt a duel. Nothing here is awaited by
///   gameplay code and every failure is swallowed.
/// - It must not fire one request per answer. Events are buffered and flushed
///   in batches, so a 15-question duel costs one request instead of fifteen.
/// - Anonymous/offline players simply produce no telemetry rather than an error:
///   the backend attributes events to the caller's identity, so without a token
///   there is nothing meaningful to record.
nonisolated final class AnswerTelemetry: @unchecked Sendable {
    /// One answered question, in the shape the backend ingest endpoint expects.
    struct Event: Sendable {
        let questionId: String
        let correct: Bool
        /// Milliseconds between the question appearing and the answer landing.
        let timeMs: Int
        /// What the player actually tapped. `nil` when the timer ran out.
        let selected: String?
        let timedOut: Bool
        let disciplineId: String?
        let level: String?

        var payload: [String: Any] {
            var dict: [String: Any] = [
                "questionId": questionId,
                "correct": correct,
                "timeMs": timeMs,
                "timedOut": timedOut
            ]
            if let selected, !selected.isEmpty { dict["selected"] = selected }
            if let disciplineId, !disciplineId.isEmpty { dict["disciplineId"] = disciplineId }
            if let level, !level.isEmpty { dict["level"] = level }
            return dict
        }
    }

    static let shared = AnswerTelemetry()

    /// Flush once a duel's worth of answers has piled up, so a normal match
    /// results in a single request.
    private static let batchSize = 15
    /// Hard cap: if the network is down for a long session we drop the oldest
    /// events rather than growing memory without bound.
    private static let maxBuffered = 200

    private let lock = NSLock()
    private var buffer: [Event] = []
    private var isFlushing = false

    /// Resolves the bearer token for the current player. Injected at launch
    /// because `AuthManager` is owned by the app entry point, not a singleton.
    /// Until it is set, `record` still buffers — nothing is lost if the first
    /// answers land before configuration.
    private var tokenProvider: (@Sendable () async -> String?)?

    private init() {}

    func configure(tokenProvider: @escaping @Sendable () async -> String?) {
        lock.lock()
        self.tokenProvider = tokenProvider
        lock.unlock()
    }

    /// Queues one answered question. Returns immediately; the actual upload
    /// happens on a detached task once a batch is full.
    func record(_ event: Event) {
        lock.lock()
        buffer.append(event)
        if buffer.count > Self.maxBuffered {
            buffer.removeFirst(buffer.count - Self.maxBuffered)
        }
        let shouldFlush = buffer.count >= Self.batchSize
        lock.unlock()
        if shouldFlush { flush() }
    }

    /// Uploads whatever is buffered. Call at the end of a duel/lesson so the
    /// last partial batch is not stranded until the next session.
    func flush() {
        lock.lock()
        guard !isFlushing, !buffer.isEmpty else {
            lock.unlock()
            return
        }
        let batch = buffer
        buffer = []
        isFlushing = true
        lock.unlock()

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let delivered = await self.upload(batch)
            self.lock.lock()
            self.isFlushing = false
            if !delivered {
                // Put the events back at the front so ordering is preserved and
                // a transient outage doesn't silently discard collected data.
                self.buffer.insert(contentsOf: batch, at: 0)
                if self.buffer.count > Self.maxBuffered {
                    self.buffer.removeFirst(self.buffer.count - Self.maxBuffered)
                }
            }
            self.lock.unlock()
        }
    }

    private func upload(_ batch: [Event]) async -> Bool {
        lock.lock()
        let provider = tokenProvider
        lock.unlock()
        guard let provider else {
            // Not configured yet — keep the batch for a later flush.
            return false
        }
        guard let token = await provider(), !token.isEmpty else {
            // Not signed in — the backend can't attribute these events, so
            // there is nothing to retry later either.
            return true
        }
        guard let url = URL(string: "\(MultiplayerService.baseURL)/api/hub/answers") else {
            return true
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(
                withJSONObject: ["events": batch.map(\.payload)]
            )
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            // 4xx means the payload or identity will never be accepted, so
            // retrying would loop forever — treat it as delivered and move on.
            if (400...499).contains(status) { return true }
            return (200...299).contains(status)
        } catch {
            return false
        }
    }
}
