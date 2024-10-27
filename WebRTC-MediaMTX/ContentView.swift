import SwiftUI
import Combine

class ViewModel: ObservableObject {
    var receiveService = WebRTCReceiveService()
    var publishService = WebRTCPublishService()
    
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
        
        publishService.$state.sink { state in
            if let state = state {
                self.loggs.append("\(self.now) Publisher: \(state.description)")
            }
        }
        .store(in: &cancallables)
    }
    
    func start() {
        receiveService.startStream()
        publishService.startStream()
    }
    
    func stop() {
        receiveService.webRTCClient.close()
        publishService.webRTCClient.close()
    }
}

struct ContentView: View {
    
    @ObservedObject var viewModel = ViewModel()
    
    var body: some View {
        WebRTCReceiveView(client: viewModel.receiveService.webRTCClient)
            .overlay {
                VStack {
                    Spacer()
                    HStack {
                        debugView
                        Spacer()
                        WebRTCPublishView(client: viewModel.publishService.webRTCClient)
                            .padding()
                            .padding(.bottom, 50)
                            .frame(width: 120, height: 200)
                            .cornerRadius(16)
                            .shadow(radius: 10)
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .onAppear(perform: viewModel.start)
            .onDisappear(perform: viewModel.stop)
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
