import SwiftUI

struct ContentView: View {
    @State private var filePath: String = ""
    @State private var feedback: String = ""
    @State private var videoFiles: [String] = []
    @AppStorage("ipAddress") var adbAddress: String = ""
    @State private var isConnected = false
    private let adbPath = "/opt/homebrew/bin/adb"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("ADB VLC Controller")
                .font(.largeTitle)
                .padding(.bottom, 5)

            HStack {
                if isConnected {
                    Button(action: fetchVideoFiles) {
                        Text("Fetch Video Files")
                            .padding()
                            .cornerRadius(8)
                    }
                    
                    Button(action: selectAndTransferVideo) {
                        Text("Select and Transfer Video")
                            .padding()
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                TextField("ADB IP Address", text: $adbAddress)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                
                if !adbAddress.isEmpty {
                    Button(action: {
                        connect()
                    }) {
                        Text("Connect")
                            .padding()
                            .cornerRadius(8)
                    }
                }
                
                Button(action: disconnect) {
                    Text("Disconnect")
                        .padding()
                        .cornerRadius(8)
                }
            }
            
            if isConnected {
                HStack {
                    Button(action: togglePlayPause) {
                        Text("Toggle Play/Pause")
                            .padding()
                            .cornerRadius(8)
                    }
                    
                    Button(action: volumeUp) {
                        Text("Volume Up")
                            .padding()
                            .cornerRadius(8)
                    }
                    
                    Button(action: volumeDown) {
                        Text("Volume Down")
                            .padding()
                            .cornerRadius(8)
                    }
                    
                    Button(action: muteVolume) {
                        Text("Toggle Mute")
                            .padding()
                            .cornerRadius(8)
                    }
                    
                    Button(action: home) {
                        Text("Home")
                            .padding()
                            .cornerRadius(8)
                    }
                }
            }

            if !videoFiles.isEmpty {
                Text("Videos in /sdcard/Download/Videos:")
                    .font(.headline)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(videoFiles, id: \.self) { video in
                            HStack {
                                Button(action: {
                                    playVideo(filePath: video)
                                }) {
                                    Image(systemName: "play")
                                        .padding(.horizontal, 3)
                                        .foregroundStyle(.green)
                                        .cornerRadius(8)
                                    
                                    Text(video)
                                        .padding(.vertical)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    deleteVideo(filePath: video)
                                }) {
                                    Image(systemName: "trash")
                                        .padding()
                                        .foregroundStyle(.red)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
            }

            Text("Output:")
                .font(.headline)

            ScrollView {
                Text(feedback)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled) // Enable text selection
            }
            .frame(minHeight: 200)
        }
        .padding()
        .onAppear {
            if !adbAddress.isEmpty {
                connect()
            }
        }
    }

    private func executeProcessAndReturnResult(_ command: String) -> String {
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
                return "Error running command: \(error)"
            }
        } else {
            process.launch()
        }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? "No output"
    }

    private func fetchVideoFiles() {
        let createDirCommand = """
        \(adbPath) shell mkdir -p /sdcard/Download/Videos
        """
        _ = executeProcessAndReturnResult(createDirCommand)
        
        let listCommand = """
        \(adbPath) shell ls /sdcard/Download/Videos
        """
        let output = executeProcessAndReturnResult(listCommand)
        
        DispatchQueue.main.async {
            let files = output.split(separator: "\n").map { String($0) }.filter { !$0.isEmpty }
            videoFiles = files
            feedback += "Fetched files:\n\(files.joined(separator: "\n"))\n"
        }
    }

    private func playVideo(filePath: String) {
        let command = "\(adbPath) connect \(adbAddress) && \(adbPath) shell am start -n org.videolan.vlc/.gui.video.VideoPlayerActivity -d \"/sdcard/Download/Videos/\(filePath)\" -t video/mp4"
        let output = executeProcessAndReturnResult(command)
        DispatchQueue.main.async {
            feedback += "Running command: \(command)\n\(output)\n"
        }
    }

    private func togglePlayPause() {
        let command = "\(adbPath) shell input keyevent 85"
        let output = executeProcessAndReturnResult(command)
        DispatchQueue.main.async {
            feedback += "Running command: \(command)\n\(output)\n"
        }
    }

    private func volumeUp() {
        let command = "\(adbPath) shell input keyevent 24"
        let output = executeProcessAndReturnResult(command)
        DispatchQueue.main.async {
            feedback += "Running command: \(command)\n\(output)\n"
        }
    }

    private func volumeDown() {
        let command = "\(adbPath) shell input keyevent 25"
        let output = executeProcessAndReturnResult(command)
        DispatchQueue.main.async {
            feedback += "Running command: \(command)\n\(output)\n"
        }
    }
    
    private func muteVolume() {
        let command = "\(adbPath) shell input keyevent 164"
        let output = executeProcessAndReturnResult(command)
        DispatchQueue.main.async {
            feedback += "Running command: \(command)\n\(output)\n"
        }
    }
    
    private func home() {
        let command = "\(adbPath) shell input keyevent 3"
        let output = executeProcessAndReturnResult(command)
        DispatchQueue.main.async {
            feedback += "Running command: \(command)\n\(output)\n"
        }
    }

    private func selectAndTransferVideo() {
        let createDirCommand = """
        \(adbPath) shell mkdir -p /sdcard/Download/Videos
        """
        _ = executeProcessAndReturnResult(createDirCommand)
        
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let selectedURL = panel.url {
            let localPath = selectedURL.path
            let fileName = selectedURL.lastPathComponent.replacingOccurrences(of: " ", with: "_")
            let command = "\(adbPath) push \"\(localPath)\" \"/sdcard/Download/Videos/\(fileName)\""
            let output = executeProcessAndReturnResult(command)
            DispatchQueue.main.async {
                feedback += "Transferred file:\n\(fileName)\nOutput:\n\(output)\n"
                fetchVideoFiles()
            }
        }
    }
    
    private func deleteVideo(filePath: String) {
        let command = "\(adbPath) shell rm \"/sdcard/Download/Videos/\(filePath)\""
        let output = executeProcessAndReturnResult(command)
        DispatchQueue.main.async {
            feedback += "Running command: \(command)\n\(output)\n"
            fetchVideoFiles()
        }
    }
    
    private func connect() {
        guard !adbAddress.isEmpty else {
            feedback += "ADB IP Address is empty.\n"
            return
        }

        let command = "\(adbPath) connect \(adbAddress)"
        let output = executeProcessAndReturnResult(command)
        DispatchQueue.main.async {
            if output.contains("connected") {
                isConnected = true
                feedback += "Connected to \(adbAddress).\n"
            } else {
                isConnected = false
                feedback += "Failed to connect to \(adbAddress).\n"
            }
            
            feedback += "Running command: \(command)\n\(output)\n"
        }
    }
    
    private func disconnect() {
        let command = "\(adbPath) disconnect \(adbAddress)"
        let output = executeProcessAndReturnResult(command)
        DispatchQueue.main.async {
            if output.contains("disconnected") {
                isConnected = false
                feedback += "Disconnected from \(adbAddress).\n"
            } else {
                feedback += "Failed to disconnect from \(adbAddress).\n"
            }
                
            feedback += "Running command: \(command)\n\(output)\n"
        }
    }
}

#Preview {
    ContentView()
}
