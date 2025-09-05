//
//  VLC_AndroidTVApp.swift
//  VLC AndroidTV
//
//  Created by Ben Lawrence on 21/11/2024.
//

import SwiftUI

@main
struct VLC_AndroidTVApp: App {
  @State private var adbManager = ADBManager.shared
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .frame(minWidth: 1200, minHeight: 800)
    }
    .commands {
      CommandMenu("VLC Remote") {
        Button("Fetch Video Files") {
          Task { await adbManager.fetchVideoFiles() }
        }
        .keyboardShortcut("r", modifiers: [.command])
        // TODO: - Disabled isnt working for some reason
//        .disabled(!adbManager.isConnected)
        
        Button("Select and Transfer Video") {
          Task { await adbManager.selectAndTransferVideo() }
        }
        .keyboardShortcut("t", modifiers: [.command])
//        .disabled(!adbManager.isConnected)
        
        Divider()
        
        Button("Connect to ADB") {
          Task { await adbManager.connect() }
        }
//        .disabled(adbManager.adbAddress.isEmpty || adbManager.isConnected)
        
        Button("Disconnect from ADB") {
          Task { await adbManager.disconnect() }
        }
//        .disabled(!adbManager.isConnected)
      }
    }
  }
}
