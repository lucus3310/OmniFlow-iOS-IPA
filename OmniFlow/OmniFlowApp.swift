//
//  OmniFlowApp.swift
//  OmniFlow iOS Studio (Compiled for iPhone 16 / iOS 16.0 - 18.0+)
//

import SwiftUI

@main
struct OmniFlowApp: App {
    @StateObject private var fileManagerVM = FileManagerViewModel()
    @StateObject private var downloadVM = DownloadManagerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(fileManagerVM)
                .environmentObject(downloadVM)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    fileManagerVM.importIncomingFile(url: url)
                }
        }
    }
}
