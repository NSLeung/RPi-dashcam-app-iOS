import SwiftUI
import Combine

class ViewModel: ObservableObject {
    var receiveService = WebRTCReceiveService()
    
    @Published var loggs = [String]()
    private var cancallables = Set<AnyCancellable>()
    
    var now: String {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        return dateFormatter.string(from: date)

    }
    
    init() {
        receiveService.$state.sink { state in
            if let state = state {
                self.loggs.append("\(self.now) Receiver: \(state.description)")
            }
        }
        .store(in: &cancallables)
    }
    
    func start() {
        receiveService.startStream()
    }
    
    func stop() {
        receiveService.webRTCClient.close()
    }
}

struct ContentView: View {
    
    @ObservedObject var viewModel = ViewModel()
    
    var body: some View {
        VStack {
            WebRTCReceiveView(client: viewModel.receiveService.webRTCClient)
                .overlay {
                    VStack {
                        Text("Front").font(.title).foregroundColor(.white)
                        Spacer()
                    }
                    
                }
            WebRTCReceiveView(client: viewModel.receiveService.webRTCClient)
                .overlay {
                    VStack {
                        Text("Rear").font(.title).foregroundColor(.white)
                        Spacer()
                        HStack {
                            debugView
                            Spacer()
                        }
                    }
                }
                .edgesIgnoringSafeArea(.all)
                .onAppear(perform: viewModel.start)
                .onDisappear(perform: viewModel.stop)
        }	
    }
    
    var debugView: some View {
        ScrollView {
            VStack(alignment: .leading) {
                ForEach(viewModel.loggs, id: \.self) { log in
                    Text(log)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .frame(height: 200)
    }
}

#Preview {
    ContentView()
}
