import SwiftUI
import SwiftData

struct RecordView: View {
    @ObservedObject var store: DreamStore
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack {
            if store.isRecording {
                // Recording UI
                VStack(spacing: 20) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse, isActive: true)
                    
                    Text("Listening to your dream...")
                        .font(.headline)
                    
                    Text(store.currentTranscript)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial)
                        .cornerRadius(12)
                    
                    Button("Stop & Analyze") {
                        // Pass the SwiftData context here
                        store.stopRecording(save: true, context: modelContext)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
                
            } else if store.isProcessing {
                ProgressView("Analyzing Dream...")
            } else {
                // Start UI
                VStack(spacing: 20) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.indigo)
                    
                    Text("Ready to Record")
                        .font(.title2)
                        .bold()
                    
                    Button("Start Recording") {
                        store.startRecording()
                    }
                    .font(.title3)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    // Debug Button
                    Button("Simulate Mock Dream") {
                         store.startMockRecording()
                    }
                    .padding(.top)
                }
            }
        }
        .padding()
    }
}
