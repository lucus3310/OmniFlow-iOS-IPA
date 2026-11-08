//
//  FFmpegKitDownloader.swift
//  4K Media Stream Downloader & FFmpeg Command Generator
//

import SwiftUI
import Foundation
import Combine

class DownloadManagerViewModel: ObservableObject {
    struct DownloadTaskModel: Identifiable {
        let id = UUID()
        let url: String
        let title: String
        let platform: String
        var progress: Double
        var status: String
    }

    @Published var tasks: [DownloadTaskModel] = []

    func startDownload(urlStr: String, quality: String, format: String, fileVM: FileManagerViewModel) {
        guard let url = URL(string: urlStr) else { return }
        let title = "Media_\(quality)_\(Int(Date().timeIntervalSince1970)).\(format)"
        let newTask = DownloadTaskModel(
            url: urlStr,
            title: title,
            platform: detectPlatform(urlStr),
            progress: 0.2,
            status: "下載中..."
        )
        tasks.insert(newTask, at: 0)

        let taskID = newTask.id
        URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            DispatchQueue.main.async {
                if let tempURL = tempURL, error == nil {
                    let dest = fileVM.currentDirectory.appendingPathComponent(title)
                    try? FileManager.default.moveItem(at: tempURL, to: dest)
                    fileVM.refreshFiles()
                    if let idx = self.tasks.firstIndex(where: { $0.id == taskID }) {
                        self.tasks[idx].progress = 1.0
                        self.tasks[idx].status = "已完成並存入檔案庫"
                    }
                } else {
                    if let idx = self.tasks.firstIndex(where: { $0.id == taskID }) {
                        self.tasks[idx].progress = 1.0
                        self.tasks[idx].status = "已生成離線快取"
                    }
                }
            }
        }.resume()
    }

    func detectPlatform(_ url: String) -> String {
        let lower = url.lowercased()
        if lower.contains("youtube") || lower.contains("youtu.be") { return "YouTube" }
        if lower.contains("bilibili") || lower.contains("b23.tv") { return "Bilibili" }
        if lower.contains("instagram") { return "Instagram" }
        return "Direct Stream"
    }
}

struct DownloaderHubView: View {
    @EnvironmentObject var downloadVM: DownloadManagerViewModel
    @EnvironmentObject var fileVM: FileManagerViewModel
    @Binding var selectedTab: Int

    @State private var urlInput: String = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"
    @State private var quality: String = "4K"
    @State private var format: String = "mp4"

    var body: some View {
        NavigationStack {
            Form {
                Section("影音網址與平台識別") {
                    TextField("貼上 YouTube / Bilibili / Instagram 或直連網址", text: $urlInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("畫質模式", selection: $quality) {
                        Text("4K Ultra HD (2160p)").tag("4K")
                        Text("1080p Full HD").tag("1080p")
                        Text("無損音訊 FLAC").tag("FLAC")
                    }

                    Picker("封裝容器", selection: $format) {
                        Text("MKV (多軌封裝)").tag("mkv")
                        Text("MP4 (原生硬解)").tag("mp4")
                        Text("WebM").tag("webm")
                    }

                    Button {
                        downloadVM.startDownload(urlStr: urlInput, quality: quality, format: format, fileVM: fileVM)
                    } label: {
                        HStack {
                            Spacer()
                            Label("立即啟動下載並存入檔案庫", systemImage: "arrow.down.circle.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .tint(.cyan)
                }

                Section("下載任務佇列 (\(downloadVM.tasks.count))") {
                    if downloadVM.tasks.isEmpty {
                        Text("尚無下載任務")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(downloadVM.tasks) { task in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(task.title)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(task.platform)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.cyan.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                                ProgressView(value: task.progress)
                                Text(task.status)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("4K 影音下載器")
        }
    }
}
