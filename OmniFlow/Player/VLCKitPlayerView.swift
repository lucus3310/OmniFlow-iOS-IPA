//
//  VLCKitPlayerView.swift
//  Precision Frame-by-Frame Video Player with SMPTE Timecode & A-B Loop
//

import SwiftUI
import AVKit
import AVFoundation
import CoreMedia

struct FrameByFramePlayerView: View {
    @EnvironmentObject var fileManagerVM: FileManagerViewModel
    @State private var player = AVPlayer(url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!)
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0.0
    @State private var fps: Double = 60.0
    @State private var playbackRate: Float = 1.0
    @State private var loopA: Double? = nil
    @State private var loopB: Double? = nil

    var currentFrame: Int {
        Int(currentTime * fps)
    }

    var smpteTimecode: String {
        let totalSecs = Int(max(0, currentTime))
        let frames = Int(currentTime * fps) % Int(max(1, fps))
        let secs = totalSecs % 60
        let mins = (totalSecs / 60) % 60
        let hrs = totalSecs / 3600
        return String(format: "%02d:%02d:%02d:%02d", hrs, mins, secs, frames)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                ZStack(alignment: .topLeading) {
                    VideoPlayer(player: player)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("SMPTE \(smpteTimecode)")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(.cyan)
                        Text("Frame #\(currentFrame) · \(Int(fps)) FPS")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(10)
                }
                .padding(.horizontal)

                // Precision Frame Stepper Controls
                HStack(spacing: 12) {
                    Button("-10F") { stepFrames(-10) }
                        .buttonStyle(.bordered)
                    Button("-1F") { stepFrames(-1) }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)

                    Button {
                        if isPlaying {
                            player.pause()
                        } else {
                            player.play()
                            player.rate = playbackRate
                        }
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("+1F") { stepFrames(1) }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                    Button("+10F") { stepFrames(10) }
                        .buttonStyle(.bordered)
                }

                // FPS & Speed Picker
                HStack {
                    Picker("FPS", selection: $fps) {
                        Text("24 FPS").tag(24.0)
                        Text("30 FPS").tag(30.0)
                        Text("60 FPS").tag(60.0)
                        Text("120 FPS").tag(120.0)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                // A-B Loop Controls
                HStack(spacing: 12) {
                    Button(loopA == nil ? "設 A 點" : String(format: "A: %.2fs", loopA!)) {
                        loopA = player.currentTime().seconds
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)

                    Button(loopB == nil ? "設 B 點" : String(format: "B: %.2fs", loopB!)) {
                        loopB = player.currentTime().seconds
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    if loopA != nil || loopB != nil {
                        Button("清除循環") {
                            loopA = nil
                            loopB = nil
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Spacer()
            }
            .navigationTitle("逐幀播放器")
            .onAppear {
                if let url = fileManagerVM.selectedVideoURL {
                    player = AVPlayer(url: url)
                }
            }
        }
    }

    private func stepFrames(_ count: Int) {
        player.pause()
        isPlaying = false
        if let item = player.currentItem, item.canStepForward && count > 0 {
            item.step(byCount: count)
        } else if let item = player.currentItem, item.canStepBackward && count < 0 {
            item.step(byCount: count)
        }
        let target = max(0, player.currentTime().seconds + (Double(count) / fps))
        let time = CMTime(seconds: target, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = target
    }
}
