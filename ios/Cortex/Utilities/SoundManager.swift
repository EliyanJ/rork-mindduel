import AVFoundation

/// Central audio hub for every live quiz screen (bot duel, ranked duel,
/// party, flash): correct/wrong stingers, a soft looping ambience track,
/// and a tension tick that ramps up in rate/volume as a question's timer
/// runs down. All playback is best-effort — a missing bundled file simply
/// means silence, never a crash.
@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private var effectPlayers: [String: AVAudioPlayer] = [:]
    private var ambiencePlayer: AVAudioPlayer?
    private var leaderboardPlayer: AVAudioPlayer?
    private var tickPlayer: AVAudioPlayer?
    private var lastTickAt: Date = .distantPast

    var isMuted: Bool = false

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - One-shot stingers

    func playCorrect() { play(resource: "correct_answer_chime", volume: 0.9) }
    func playWrong() { play(resource: "quiz_wrong_buzz", volume: 0.85) }

    private func play(resource: String, volume: Float) {
        guard !isMuted else { return }
        guard let url = Bundle.main.url(forResource: resource, withExtension: "mp3") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()
            player.play()
            effectPlayers[resource] = player
        } catch {
            // Missing/undecodable asset — fail silently.
        }
    }

    // MARK: - Background ambience

    /// Starts (or resumes) the looping lo-fi bed. Safe to call repeatedly —
    /// it no-ops if already playing.
    func startAmbience() {
        guard !isMuted else { return }
        if let ambiencePlayer, ambiencePlayer.isPlaying { return }
        guard let url = Bundle.main.url(forResource: "lofi_quiz_chill", withExtension: "mp3") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.22
            player.prepareToPlay()
            player.play()
            ambiencePlayer = player
        } catch {
            // No ambience — game still works fine without it.
        }
    }

    func stopAmbience() {
        ambiencePlayer?.stop()
        ambiencePlayer = nil
    }

    func setAmbienceVolume(_ volume: Float) {
        ambiencePlayer?.volume = volume
    }

    // MARK: - Leaderboard interstitial music

    /// Ducks the lo-fi bed and plays a punchier, drum-forward loop for the
    /// between-rounds leaderboard page, so that moment feels distinct.
    func startLeaderboardMusic() {
        guard !isMuted else { return }
        setAmbienceVolume(0.05)
        guard leaderboardPlayer == nil || leaderboardPlayer?.isPlaying == false else { return }
        guard let url = Bundle.main.url(forResource: "leaderboard_drumroll", withExtension: "mp3") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.5
            player.prepareToPlay()
            player.play()
            leaderboardPlayer = player
        } catch {
            // No leaderboard sting bundled — the lo-fi bed alone is fine.
        }
    }

    func stopLeaderboardMusic() {
        leaderboardPlayer?.stop()
        leaderboardPlayer = nil
        setAmbienceVolume(0.22)
    }

    // MARK: - Tension tick tied to the round timer

    /// Call every timer tick with the remaining/total fraction (1 = just
    /// started, 0 = out of time). Plays a click that gets faster and a
    /// little louder as the fraction shrinks, without overlapping itself.
    func pulseTension(fraction: Double) {
        guard !isMuted else { return }
        let clamped = max(0, min(1, fraction))
        // Interval shrinks from ~0.9s (plenty of time) down to ~0.22s (urgent).
        let interval = 0.22 + clamped * 0.68
        guard Date().timeIntervalSince(lastTickAt) >= interval else { return }
        lastTickAt = Date()
        guard let url = Bundle.main.url(forResource: "clock_tick", withExtension: "mp3") else { return }
        do {
            // A fresh player per tick (instead of rewinding one shared
            // instance) so fast, overlapping ticks near the end of the timer
            // are all actually audible instead of clipping each other.
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = Float(0.45 + (1 - clamped) * 0.45)
            player.prepareToPlay()
            player.play()
            tickPlayer = player
        } catch {
            // Missing/undecodable tick asset — fail silently.
        }
    }

    func resetTension() {
        lastTickAt = .distantPast
        tickPlayer?.stop()
    }
}
