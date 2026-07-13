import AVFoundation

final class SoundManager {

    static let shared = SoundManager()

    private let engine = AVAudioEngine()
    private let enginePlayer = AVAudioPlayerNode()
    private let engineSpeed = AVAudioUnitVarispeed()
    private let sfxPlayer = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

    private var engineBuffer: AVAudioPCMBuffer?
    private var engineRunning = false
    private(set) var enabled = true

    private init() {
        setup()
    }

    private func setup() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }

        engine.attach(enginePlayer)
        engine.attach(engineSpeed)
        engine.attach(sfxPlayer)

        engine.connect(enginePlayer, to: engineSpeed, format: format)
        engine.connect(engineSpeed, to: engine.mainMixerNode, format: format)
        engine.connect(sfxPlayer, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.6

        do {
            try engine.start()
        } catch {
            print("Audio engine failed: \(error)")
            enabled = false
        }
    }

    private func buffer(seconds: Double, _ f: (Double) -> Float) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(seconds * format.sampleRate)
        guard frames > 0,
              let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buf.floatChannelData else { return nil }
        buf.frameLength = frames
        for i in 0..<Int(frames) {
            data[0][i] = f(Double(i) / format.sampleRate)
        }
        return buf
    }

    private func play(_ buf: AVAudioPCMBuffer?, volume: Float = 1) {
        guard enabled, let buf = buf, engine.isRunning else { return }
        sfxPlayer.volume = volume
        sfxPlayer.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        if !sfxPlayer.isPlaying { sfxPlayer.play() }
    }

    private func env(_ t: Double, dur: Double, attack: Double = 0.01) -> Float {
        if t < attack {
            let a: Double = t / attack
            return Float(a)
        }
        let rel: Double = (dur - t) / (dur - attack)
        let clamped: Double = max(0.0, min(1.0, rel))
        return Float(clamped)
    }

    private func tone(_ freq: Double, _ t: Double) -> Double {
        let twoPi: Double = 2.0 * Double.pi
        let phase: Double = twoPi * freq * t
        return sin(phase)
    }

    func coin() {
        let d: Double = 0.18
        let buf = buffer(seconds: d) { (t: Double) -> Float in
            let freq: Double = 1200.0 + 600.0 * (t / d)
            let s: Double = self.tone(freq, t)
            let e: Float = self.env(t, dur: d)
            let amp: Float = 0.35
            return Float(s) * e * amp
        }
        play(buf)
    }

    func delivered() {
        let d: Double = 0.5
        let buf = buffer(seconds: d) { (t: Double) -> Float in
            let freq: Double = (t < 0.22) ? 523.25 : 783.99
            let local: Double = (t < 0.22) ? t : (t - 0.22)
            let fade: Double = max(0.0, 1.0 - local / 0.26)
            let s: Double = self.tone(freq, t)
            let amp: Float = 0.32
            return Float(s) * Float(fade) * amp
        }
        play(buf)
    }

    func honk() {
        let d: Double = 0.42
        let buf = buffer(seconds: d) { (t: Double) -> Float in
            let a: Double = self.tone(440.0, t)
            let b: Double = self.tone(554.37, t)
            let mixed: Double = (a + b) * 0.22
            let e: Float = self.env(t, dur: d, attack: 0.02)
            return Float(mixed) * e
        }
        play(buf, volume: 0.9)
    }

    func crash() {
        let d: Double = 0.4
        let buf = buffer(seconds: d) { (t: Double) -> Float in
            let noise: Float = Float.random(in: -1.0...1.0)
            let decayD: Double = max(0.0, 1.0 - t / d)
            let decay: Float = Float(decayD)
            return noise * decay * decay * 0.4
        }
        play(buf)
    }

    func doors() {
        let d: Double = 0.6
        let buf = buffer(seconds: d) { (t: Double) -> Float in
            let noise: Float = Float.random(in: -1.0...1.0)
            let shapeD: Double = sin(Double.pi * t / d)
            let shape: Float = Float(shapeD)
            return noise * shape * 0.12
        }
        play(buf)
    }

    func step() {
        let d: Double = 0.08
        let buf = buffer(seconds: d) { (t: Double) -> Float in
            let noise: Float = Float.random(in: -1.0...1.0)
            let decayD: Double = max(0.0, 1.0 - t / d)
            let decay: Float = Float(decayD)
            return noise * decay * 0.09
        }
        play(buf, volume: 0.5)
    }

    func cash() {
        let d: Double = 0.3
        let buf = buffer(seconds: d) { (t: Double) -> Float in
            let s: Double = self.tone(900.0, t)
            let e: Float = self.env(t, dur: d)
            let amp: Float = 0.25
            return Float(s) * e * amp
        }
        play(buf)
    }

    func startEngine() {
        guard enabled, !engineRunning, engine.isRunning else { return }

        engineBuffer = buffer(seconds: 1.0) { (t: Double) -> Float in
            let base: Double = 70.0
            var v: Double = 0.0
            for h in 1...4 {
                let hd: Double = Double(h)
                let s: Double = self.tone(base * hd, t)
                v += s / hd
            }
            let amp: Float = 0.10
            return Float(v) * amp
        }
        guard let buf = engineBuffer else { return }
        enginePlayer.scheduleBuffer(buf, at: nil, options: [.loops], completionHandler: nil)
        enginePlayer.volume = 0.0
        enginePlayer.play()
        engineRunning = true
    }

    func stopEngine() {
        guard engineRunning else { return }
        enginePlayer.stop()
        engineRunning = false
    }

    func updateEngine(speed01: Float) {
        guard engineRunning else { return }
        let s = max(0, min(1, speed01))
        engineSpeed.rate = 0.75 + s * 1.6
        enginePlayer.volume = 0.12 + s * 0.35
    }

    func setEnabled(_ on: Bool) {
        enabled = on
        engine.mainMixerNode.outputVolume = on ? 0.6 : 0
    }
}
