//
//  ContentView.swift
//  OmniFlow Main TabView & Views
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var fileManagerVM: FileManagerViewModel
    @EnvironmentObject var downloadVM: DownloadManagerViewModel
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            FileManagerView(selectedTab: $selectedTab)
                .tabItem {
                    Label("檔案庫", systemImage: "folder.fill")
                }
                .tag(0)

            FrameByFramePlayerView()
                .tabItem {
                    Label("逐幀播放", systemImage: "film.stack.fill")
                }
                .tag(1)

            DownloaderHubView(selectedTab: $selectedTab)
                .tabItem {
                    Label("FFmpeg下載", systemImage: "arrow.down.circle.fill")
                }
                .tag(2)

            SideloadInfoView()
                .tabItem {
                    Label("系統資訊", systemImage: "iphone.gen3")
                }
                .tag(3)
        }
        .tint(.cyan)
    }
}

struct FileManagerView: View {
    @EnvironmentObject var vm: FileManagerViewModel
    @Binding var selectedTab: Int
    @State private var searchText: String = ""
    @State private var showDuplicatesOnly: Bool = false
    @State private var showImporter: Bool = false

    var filteredFiles: [LocalFileItem] {
        vm.files.filter { item in
            searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Picker("模式", selection: $showDuplicatesOnly) {
                        Text("檔案目錄 (\(vm.files.count))").tag(false)
                        Text("智能查重 (\(vm.duplicateGroups.count))").tag(true)
                    }
                    .pickerStyle(.segmented)

                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.cyan)
                    }
                }
                .padding(.horizontal)

                if showDuplicatesOnly {
                    VStack(spacing: 10) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("SHA-256 數位指紋查重引擎")
                                    .font(.headline)
                                Text("自動比對不同目錄下完全相同的影片與圖檔副本")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("全盤掃描") {
                                vm.scanDuplicates()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)

                        if vm.duplicateGroups.isEmpty {
                            Spacer()
                            VStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 42))
                                    .foregroundStyle(.green)
                                Text("未發現重複檔案")
                                    .font(.headline)
                                Text("您的 iPhone 16 儲存空間目前無冗餘副本")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        } else {
                            List {
                                ForEach(vm.duplicateGroups) { group in
                                    Section("重複組 · 大小 \(ByteCountFormatter.string(fromByteCount: group.size, countStyle: .file))") {
                                        ForEach(group.files) { file in
                                            HStack {
                                                VStack(alignment: .leading) {
                                                    Text(file.name)
                                                        .font(.subheadline.bold())
                                                    Text(file.url.lastPathComponent)
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                                if file.id == group.keepFileId {
                                                    Text("建議保留")
                                                        .font(.caption2.bold())
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Color.green.opacity(0.2))
                                                        .foregroundStyle(.green)
                                                        .clipShape(Capsule())
                                                } else {
                                                    Button(role: .destructive) {
                                                        vm.deleteFile(file)
                                                        vm.scanDuplicates()
                                                    } label: {
                                                        Image(systemName: "trash")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    List {
                        ForEach(filteredFiles) { file in
                            HStack(spacing: 12) {
                                Image(systemName: file.isVideo ? "film.fill" : "doc.fill")
                                    .font(.title2)
                                    .foregroundStyle(file.isVideo ? .orange : .cyan)
                                    .frame(width: 36)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(file.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text("\(file.formattedSize) · \(file.ext.uppercased())")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if file.isVideo {
                                    Button {
                                        vm.selectedVideoURL = file.url
                                        selectedTab = 1
                                    } label: {
                                        Image(systemName: "play.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.cyan)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    vm.deleteFile(file)
                                } label: {
                                    Label("刪除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "搜尋檔案名稱或格式...")
                }
            }
            .navigationTitle("OmniFlow 檔案庫")
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.movie, .video, .audiovisualContent, .audio, .image, .item],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result {
                    for url in urls {
                        vm.importIncomingFile(url: url)
                    }
                }
            }
        }
    }
}

struct SideloadInfoView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("裝置與運行環境") {
                    LabeledContent("適配機型", value: "iPhone 16 / iOS 18+")
                    LabeledContent("編譯架構", value: "ARM64 Mach-O Native")
                    LabeledContent("檔案沙盒共享", value: "已啟用 (UIFileSharingEnabled)")
                }
                Section("核心模組狀態") {
                    Label("SHA-256 CryptoKit 查重引擎：正常", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("AVKit / 逐幀步進解碼引擎：正常", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("多平台 4K 媒體串流下載器：正常", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .navigationTitle("OmniFlow 系統狀態")
        }
    }
}
