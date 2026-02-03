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
  
  func convertLatestFFMpegToArm(bitrate: String = "10000k") async -> String? {
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
    
    // Find the output file (last argument that looks like a path)
    let components = command.split(separator: " ", omittingEmptySubsequences: true)
    var outputFileIndex: Int?
    
    for (index, component) in components.enumerated().reversed() {
      let str = String(component)
      if str.hasPrefix("/") || str.hasSuffix(".mp4") || str.hasSuffix(".mov") {
        // Make sure it's not an input file (comes after -i)
        if index > 0 && components[index - 1] != "-i" {
          outputFileIndex = index
          break
        }
      }
    }
    
    // Insert bitrate BEFORE output file
    if let outputIndex = outputFileIndex {
      let beforeOutput = components[..<outputIndex].joined(separator: " ")
      let afterOutput = components[outputIndex...].joined(separator: " ")
      command = "\(beforeOutput) -b:v \(bitrate) \(afterOutput)"
    } else {
      // Fallback: try to insert before -progress or -y
      if let range = command.range(of: " -progress ") {
        command.insert(contentsOf: " -b:v \(bitrate)", at: range.lowerBound)
      } else if let rangeY = command.range(of: " -y") {
        command.insert(contentsOf: " -b:v \(bitrate)", at: rangeY.lowerBound)
      } else {
        // Last resort: append before the last word (likely the output file)
        if let lastSpace = command.lastIndex(of: " ") {
          command.insert(contentsOf: " -b:v \(bitrate)", at: lastSpace)
        } else {
          command.append(" -b:v \(bitrate)")
        }
      }
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
      
      // Pre-compile regex once for better performance
      let pattern = "\"[^\"\n]*-i [^\"\n]*-filter_complex[^\"\n]*\"|(?:^|\\s)(?:ffmpeg|-i ).*?-filter_complex.*?(?=\\n|$)"
      guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
        return []
      }
      
      var collected = Set<String>() // Use Set for O(1) duplicate checking
      let fullRange = NSRange(location: 0, length: (logContent as NSString).length)
      let matches = regex.matches(in: logContent, options: [], range: fullRange)
      
      for match in matches {
        var candidate = (logContent as NSString).substring(with: match.range)
          .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove quotes if present
        if candidate.hasPrefix("\"") && candidate.hasSuffix("\"") {
          candidate = String(candidate.dropFirst().dropLast())
        }
        
        // Validate it looks like an FFmpeg command
        guard candidate.contains("-i ") &&
              (candidate.contains("-filter_complex") || candidate.contains("drawbox") || candidate.contains("perspective=")) else {
          continue
        }
        
        collected.insert(candidate)
        print("[LumaManager] Detected FFmpeg command: \n\(candidate)")
      }
      
      if collected.isEmpty {
        print("[LumaManager] No FFmpeg commands detected.")
      }
      
      return Array(collected)
    } catch {
      print("Error reading LumaMap log file: \(error)")
      return []
    }
  }
}
