//
//  ADBManager.swift
//  VLC AndroidTV
//
//  Created by Ben Lawrence on 04/09/2025.
//

import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class ADBManager {
  private let adbPath = "/opt/homebrew/bin/adb"
  
  var videoFiles: [String] = []
  var feedback: String = ""
  var isConnected: Bool = false
  var adbAddress: String = ""
  
  // MARK: - Core ADB Operations
  
  func connect() async {
    guard !adbAddress.isEmpty else {
      appendFeedback("ADB IP Address is empty.")
      return
    }
    
    let command = "\(adbPath) connect \(adbAddress)"
    let output = await executeProcessAndReturnResult(command)
    
    if output.contains("connected") {
      isConnected = true
      appendFeedback("Connected to \(adbAddress).")
    } else {
      isConnected = false
      appendFeedback("Failed to connect to \(adbAddress).")
    }
    
    appendFeedback("Running command: \(command)\n\(output)")
  }
  
  func disconnect() async {
    let command = "\(adbPath) disconnect \(adbAddress)"
    let output = await executeProcessAndReturnResult(command)
    
    if output.contains("disconnected") {
      isConnected = false
      appendFeedback("Disconnected from \(adbAddress).")
    } else {
      appendFeedback("Failed to disconnect from \(adbAddress).")
    }
    
    appendFeedback("Running command: \(command)\n\(output)")
  }
  
  // MARK: - Video File Management
  
  func fetchVideoFiles() async {
    let createDirCommand = """
        \(adbPath) shell mkdir -p /sdcard/Download/Videos
        """
    _ = await executeProcessAndReturnResult(createDirCommand)
    
    let listCommand = """
        \(adbPath) shell ls /sdcard/Download/Videos
        """
    let output = await executeProcessAndReturnResult(listCommand)
    
    let files = output.split(separator: "\n").map { String($0) }.filter { !$0.isEmpty }
    videoFiles = files
    appendFeedback("Fetched files:\n\(files.joined(separator: "\n"))")
  }
  
  func selectAndTransferVideo() async {
    let createDirCommand = """
        \(adbPath) shell mkdir -p /sdcard/Download/Videos
        """
    _ = await executeProcessAndReturnResult(createDirCommand)
    
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.movie]
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    
    if panel.runModal() == .OK, let selectedURL = panel.url {
      let localPath = selectedURL.path
      let fileName = selectedURL.lastPathComponent.replacingOccurrences(of: " ", with: "_")
      let command = "\(adbPath) push \"\(localPath)\" \"/sdcard/Download/Videos/\(fileName)\""
      let output = await executeProcessAndReturnResult(command)
      
      appendFeedback("Transferred file:\n\(fileName)\nOutput:\n\(output)")
      await fetchVideoFiles()
    }
  }
  
  func transferVideoToMac(filePath: String) async {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Select Folder"
    
    if panel.runModal() == .OK, let selectedURL = panel.url {
      let localDir = selectedURL.path
      let fileName = (filePath as NSString).lastPathComponent
      let command = "\(adbPath) pull \"/sdcard/Download/Videos/\(filePath)\" \"\(localDir)/\(fileName)\""
      let output = await executeProcessAndReturnResult(command)
      
      appendFeedback("Transferred file to Mac:\n\(fileName)\nOutput:\n\(output)")
    }
  }
  
  func deleteVideo(filePath: String) async {
    let command = "\(adbPath) shell rm \"/sdcard/Download/Videos/\(filePath)\""
    let output = await executeProcessAndReturnResult(command)
    appendFeedback("Running command: \(command)\n\(output)")
    await fetchVideoFiles()
  }
  
  // MARK: - Video Playback
  
  func playVideo(filePath: String) async {
    let command = "\(adbPath) connect \(adbAddress) && \(adbPath) shell am start -n org.videolan.vlc/.gui.video.VideoPlayerActivity -d \"/sdcard/Download/Videos/\(filePath)\" -t video/mp4"
    let output = await executeProcessAndReturnResult(command)
    appendFeedback("Running command: \(command)\n\(output)")
  }
  
  // MARK: - Media Controls
  
  func togglePlayPause() async {
    let command = "\(adbPath) shell input keyevent 85"
    let output = await executeProcessAndReturnResult(command)
    appendFeedback("Running command: \(command)\n\(output)")
  }
  
  func volumeUp() async {
    let command = "\(adbPath) shell input keyevent 24"
    let output = await executeProcessAndReturnResult(command)
    appendFeedback("Running command: \(command)\n\(output)")
  }
  
  func volumeDown() async {
    let command = "\(adbPath) shell input keyevent 25"
    let output = await executeProcessAndReturnResult(command)
    appendFeedback("Running command: \(command)\n\(output)")
  }
  
  func muteVolume() async {
    let command = "\(adbPath) shell input keyevent 164"
    let output = await executeProcessAndReturnResult(command)
    appendFeedback("Running command: \(command)\n\(output)")
  }
  
  func home() async {
    let command = "\(adbPath) shell input keyevent 3"
    let output = await executeProcessAndReturnResult(command)
    appendFeedback("Running command: \(command)\n\(output)")
  }
  
  // MARK: - Private Helpers
  
  private func executeProcessAndReturnResult(_ command: String) async -> String {
    return await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        let process = Process()
        let pipe = Pipe()
        let environment = [
          "TERM": "xterm",
          "HOME": NSHomeDirectory(),
          "PATH": "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        ]
        process.standardOutput = pipe
        process.standardError = pipe
        process.environment = environment
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]
        
        if #available(macOS 13.0, *) {
          do {
            try process.run()
          } catch {
            continuation.resume(returning: "Error running command: \(error)")
            return
          }
        } else {
          process.launch()
        }
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let result = String(data: data, encoding: .utf8) ?? "No output"
        continuation.resume(returning: result)
      }
    }
  }
  
  private func appendFeedback(_ message: String) {
    feedback += "\(message)\n"
  }
  
  func checkADBAccess() async -> Bool {
    let command = "which \(adbPath) && ls -la \(adbPath)"
    let output = await executeProcessAndReturnResult(command)
    return !output.contains("No such file") && !output.contains("operation not permitted")
  }
}
