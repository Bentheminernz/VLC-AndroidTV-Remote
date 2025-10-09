//
//  LumaManager.swift
//  VLC AndroidTV
//
//  Created by Ben Lawrence on 13/09/2025.
//

import Foundation
import Observation

@MainActor
@Observable
final class LumaManager {
  static let shared = LumaManager()
  
  private(set) var ffmpegCommands: [String] = []
  private(set) var isMonitoring: Bool = false
  
  let ffmpeg = "/opt/homebrew/bin/ffmpeg"
  
  func convertLatestFFMpegToArm(bitrate: String = "8000k") async -> String? {
    guard var command = ffmpegCommands.last?.trimmingCharacters(in: .whitespacesAndNewlines), !command.isEmpty else {
      print("No FFmpeg command available to convert.")
      return nil
    }
    
    // Prepend ffmpeg executable if it isn't already there
    if !(command.hasPrefix(ffmpeg) || command.hasPrefix("ffmpeg ") || command.hasPrefix("/Applications/LumaMap.app/Contents/MacOS/ffmpeg")) {
      command = "\(ffmpeg) \(command)"
    }
    
    // If bitrate already specified, return as-is
    if command.contains(" -b:v ") || command.contains(" -b:v") {
      print("Bitrate already present in command.")
      return command
    }
    
    let bitrateFlag = " -b:v \(bitrate)"
    
    // Preferred insertion point: before -progress (global option usually at end)
    if let range = command.range(of: " -progress ") {
      command.insert(contentsOf: bitrateFlag, at: range.lowerBound)
    } else if let rangeY = command.range(of: " -y") { // fallback: before -y
      command.insert(contentsOf: bitrateFlag, at: rangeY.lowerBound)
    } else { // last fallback: append
      command.append(bitrateFlag)
    }
    
    print("Converted FFmpeg command with bitrate: \n\(command)")
    return command
  }
  
  func checkForFFmpegCommands() async {
    ffmpegCommands = await readFFmpegCommands()
  }
  
  private func readFFmpegCommands() async -> [String] {
    let logPath = "/Applications/LumaMap.app/Contents/MacOS/lumalog.log"
    
    guard FileManager.default.fileExists(atPath: logPath) else {
      print("LumaMap log file does not exist at path: \(logPath)")
      return []
    }
    
    do {
      let logContent = try String(contentsOfFile: logPath, encoding: .utf8)
      print("LumaMap log content read successfully (\(logContent.count) chars)")
      let lines = logContent.components(separatedBy: .newlines)
      
      var collected: [String] = []
      collected.reserveCapacity(4)
      
      for rawLine in lines {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { continue }
        guard line.contains("-i ") else { continue }
        guard line.contains("-filter_complex") || line.contains("drawbox") || line.contains("perspective=") else { continue }
        
        var candidate = line
        if candidate.hasPrefix("\"") && candidate.hasSuffix("\"") {
          candidate.removeFirst()
          candidate.removeLast()
        }
        
        if !(candidate.hasPrefix("-i ") || candidate.hasPrefix("ffmpeg ") || candidate.hasPrefix("/Applications/LumaMap.app/Contents/MacOS/ffmpeg")) {
          continue
        }
        
        if !collected.contains(candidate) {
          print("[LumaManager] Detected FFmpeg command (line heuristic): \n\(candidate)")
          collected.append(candidate)
        }
      }
      
      if let regex = try? NSRegularExpression(pattern: "\"[^\"\n]*-i [^\"\n]*-filter_complex[^\"\n]*\"", options: []) {
        let fullRange = NSRange(location: 0, length: (logContent as NSString).length)
        let matches = regex.matches(in: logContent, options: [], range: fullRange)
        for match in matches {
          let quoted = (logContent as NSString).substring(with: match.range)
          var inner = quoted
          if inner.hasPrefix("\"") { inner.removeFirst() }
          if inner.hasSuffix("\"") { inner.removeLast() }
          if !collected.contains(inner) {
            print("[LumaManager] Detected FFmpeg command (regex): \n\(inner)")
            collected.append(inner)
          }
        }
      }
      
      if collected.isEmpty {
        print("[LumaManager] No FFmpeg commands detected. Diagnostics:")

        let diagnostic = lines
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          .filter { $0.contains("-i ") }
          .prefix(10)
        for (idx, l) in diagnostic.enumerated() {
          print("  Candidate #\(idx): \(l)")
        }
      }
      
      return collected
    } catch {
      print("Error reading LumaMap log file: \(error)")
      return []
    }
  }
  
  private func extractFFmpegCommand(from line: String) -> String {
    // Legacy extractor kept for compatibility (now unused by main logic)
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
      let startIndex = trimmed.index(trimmed.startIndex, offsetBy: 1)
      let endIndex = trimmed.index(trimmed.endIndex, offsetBy: -1)
      return String(trimmed[startIndex..<endIndex])
    }
    return trimmed
  }
}
