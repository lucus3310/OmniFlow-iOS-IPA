//
//  FileManagerCore.swift
//  Fast File Scanning, SHA-256 Hashing with CryptoKit & Duplicate Management
//

import Foundation
import CryptoKit
import Combine

struct LocalFileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let fileSize: Int64
    let modificationDate: Date
    let isDirectory: Bool
    var sha256Hash: String?

    var ext: String {
        url.pathExtension.lowercased()
    }

    var isVideo: Bool {
        ["mp4", "mov", "m4v", "mkv", "webm", "avi", "ts"].contains(ext)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

struct DuplicateGroupModel: Identifiable {
    let id = UUID()
    let hash: String
    let size: Int64
    var files: [LocalFileItem]
    var keepFileId: UUID
}

class FileManagerViewModel: ObservableObject {
    @Published var currentDirectory: URL
    @Published var files: [LocalFileItem] = []
    @Published var duplicateGroups: [DuplicateGroupModel] = []
    @Published var isScanningDuplicates: Bool = false
    @Published var scanProgress: Double = 0.0
    @Published var selectedVideoURL: URL?

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.currentDirectory = docs
        seedSampleFilesIfNeeded()
        refreshFiles()
    }

    private func seedSampleFilesIfNeeded() {
        let readmeURL = currentDirectory.appendingPathComponent("OmniFlow_Welcome.txt")
        if !FileManager.default.fileExists(atPath: readmeURL.path) {
            let text = "Welcome to OmniFlow iOS 18 Native App on iPhone 16! You can import videos via the + button or Files app."
            try? text.write(to: readmeURL, atomically: true, encoding: .utf8)
        }
    }

    func refreshFiles() {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: currentDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]
            )
            self.files = urls.map { url in
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
                return LocalFileItem(
                    url: url,
                    name: url.lastPathComponent,
                    fileSize: Int64(values?.fileSize ?? 0),
                    modificationDate: values?.contentModificationDate ?? Date(),
                    isDirectory: values?.isDirectory ?? false
                )
            }.sorted { $0.modificationDate > $1.modificationDate }
        } catch {
            print("Error reading directory: \(error)")
        }
    }

    func scanDuplicates() {
        isScanningDuplicates = true
        duplicateGroups.removeAll()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let allFiles = self.files.filter { !$0.isDirectory && $0.fileSize > 0 }

            var sizeBuckets: [Int64: [LocalFileItem]] = [:]
            for file in allFiles {
                sizeBuckets[file.fileSize, default: []].append(file)
            }

            let candidates = sizeBuckets.filter { $0.value.count > 1 }
            var hashBuckets: [String: [LocalFileItem]] = [:]

            for (_, fileList) in candidates {
                for var file in fileList {
                    if let hash = self.computeSHA256(for: file.url) {
                        file.sha256Hash = hash
                        hashBuckets[hash, default: []].append(file)
                    }
                }
            }

            var groups: [DuplicateGroupModel] = []
            for (hash, dupFiles) in hashBuckets where dupFiles.count > 1 {
                let sorted = dupFiles.sorted { $0.modificationDate > $1.modificationDate }
                groups.append(DuplicateGroupModel(
                    hash: hash,
                    size: dupFiles[0].fileSize,
                    files: sorted,
                    keepFileId: sorted[0].id
                ))
            }

            DispatchQueue.main.async {
                self.duplicateGroups = groups
                self.isScanningDuplicates = false
            }
        }
    }

    private func computeSHA256(for url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = handle.readData(ofLength: 512 * 1024)
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    func deleteFile(_ file: LocalFileItem) {
        try? FileManager.default.removeItem(at: file.url)
        refreshFiles()
    }

    func importIncomingFile(url: URL) {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        let dest = currentDirectory.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try? FileManager.default.copyItem(at: url, to: dest)
        refreshFiles()
    }
}
