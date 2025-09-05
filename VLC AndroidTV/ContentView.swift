import SwiftUI

struct ContentView: View {
  @State private var adbManager: ADBManager = ADBManager()
  @AppStorage("ipAddress") var storedIPAddress: String = ""
  
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("ADB VLC Controller")
        .font(.largeTitle)
        .padding(.bottom, 5)
      
      HStack {
        if adbManager.isConnected {
          Button(action: {
            Task { await adbManager.fetchVideoFiles() }
          }) {
            Text("Fetch Video Files")
              .padding()
              .cornerRadius(8)
          }
          
          Button(action: {
            Task { await adbManager.selectAndTransferVideo() }
          }) {
            Text("Select and Transfer Video")
              .padding()
              .cornerRadius(8)
          }
        }
        
        Spacer()
        
        TextField("ADB IP Address", text: $adbManager.adbAddress)
          .textFieldStyle(.roundedBorder)
          .frame(width: 200)
          .onChange(of: adbManager.adbAddress) { _, newValue in
            storedIPAddress = newValue
          }
        
        if !adbManager.adbAddress.isEmpty {
          Button(action: {
            Task { await adbManager.connect() }
          }) {
            Text("Connect")
              .padding()
              .cornerRadius(8)
          }
        }
        
        Button(action: {
          Task { await adbManager.disconnect() }
        }) {
          Text("Disconnect")
            .padding()
            .cornerRadius(8)
        }
      }
      
      if adbManager.isConnected {
        HStack {
          Button(action: {
            Task { await adbManager.togglePlayPause() }
          }) {
            Text("Toggle Play/Pause")
              .padding()
              .cornerRadius(8)
          }
          
          Button(action: {
            Task { await adbManager.volumeUp() }
          }) {
            Text("Volume Up")
              .padding()
              .cornerRadius(8)
          }
          
          Button(action: {
            Task { await adbManager.volumeDown() }
          }) {
            Text("Volume Down")
              .padding()
              .cornerRadius(8)
          }
          
          Button(action: {
            Task { await adbManager.muteVolume() }
          }) {
            Text("Toggle Mute")
              .padding()
              .cornerRadius(8)
          }
          
          Button(action: {
            Task { await adbManager.home() }
          }) {
            Text("Home")
              .padding()
              .cornerRadius(8)
          }
        }
      }
      
      if !adbManager.videoFiles.isEmpty {
        Text("Videos in /sdcard/Download/Videos:")
          .font(.headline)
        
        ScrollView {
          VStack(alignment: .leading, spacing: 10) {
            ForEach(adbManager.videoFiles, id: \.self) { video in
              HStack {
                Button(action: {
                  Task { await adbManager.playVideo(filePath: video) }
                }) {
                  HStack {
                    Image(systemName: "play")
                      .foregroundStyle(.green)
                    Text(video)
                      .frame(maxWidth: .infinity, alignment: .leading)
                  }
                  .padding()
                  .cornerRadius(8)
                }
                
                Button(action: {
                  Task { await adbManager.playVideoSimultaneously(filePath: video) }
                }) {
                  Image(systemName: "display.2")
                    .foregroundStyle(.orange)
                    .padding()
                    .cornerRadius(8)
                }
                
                Button(action: {
                  Task { await adbManager.transferVideoToMac(filePath: video) }
                }) {
                  Image(systemName: "arrow.down.doc")
                    .foregroundStyle(.blue)
                    .padding()
                    .cornerRadius(8)
                }
                
                Button(action: {
                  Task { await adbManager.deleteVideo(filePath: video) }
                }) {
                  Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .padding()
                    .cornerRadius(8)
                }
              }
            }
          }
        }
        .frame(maxHeight: 250)
      }
      
      HStack {
        Button(action: {
          adbManager.feedback = ""
        }) {
          Image(systemName: "trash")
            .foregroundStyle(.red)
            
        }
        
        Text("Output:")
          .font(.headline)
      }
      
      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading) {
            Text(adbManager.feedback)
              .padding()
              .background(Color.gray.opacity(0.2))
              .cornerRadius(8)
              .frame(maxWidth: .infinity, alignment: .leading)
              .textSelection(.enabled)
              .id("bottom")
          }
        }
        .frame(minHeight: 200)
        .onChange(of: adbManager.feedback) {
          withAnimation {
            proxy.scrollTo("bottom", anchor: .bottom)
          }
        }
      }
    }
    .padding()
    .onAppear {
      adbManager.adbAddress = storedIPAddress
      if !storedIPAddress.isEmpty {
        Task {
          let hasAccess = await adbManager.checkADBAccess()
          if hasAccess {
            await adbManager.connect()
          } else {
            adbManager.feedback += "ADB access denied. Check app permissions and sandbox settings.\n"
          }
        }
      }
    }
  }
}

#Preview {
    ContentView()
}
