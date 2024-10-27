import SwiftUI
import WebRTC

class WebRTCReceiveService: ObservableObject {
    let webRTCClient:  WebRTCClient
    
    @Published var state: RTCIceConnectionState?
    
    init() {
        webRTCClient = WebRTCClient(iceServers: defaultIceServers)
        webRTCClient.delegate = self
    }
    
    func startStream() {
        webRTCClient.offer { sdp in
            print("1 created local offer")
            Task {
                await self.sendLocalOffer(sdp)
            }
        }
    }
    
    private func sendLocalOffer(_ sdp: RTCSessionDescription) async {
        print("2 Sending local sdp")
        var request = URLRequest(url: streamURL.appendingPathComponent("whep"))
        request.httpMethod = "POST"
        request.addValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.httpBody = sdp.sdp.data(using: .utf8)
        print(sdp)
        if let (data, response) = try? await URLSession.shared.data(for: request) {
            if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) {
                print("2 response: \(httpResponse.statusCode)")
                print("3 Trying to encode remoteSdp")
                if let remoteSdp = String(data: data, encoding: .utf8) {
                    let remoteDesc = RTCSessionDescription(type: .answer, sdp: remoteSdp)
                    self.webRTCClient.set(remoteSdp: remoteDesc) { (error) in
                        print("Did set remote sdp. Error: ", error)
                    }
                } else {
                    print("Couldn't decode remoteSdp")
                }
            } else {
                print("Couldn't send Local Offer: \(String(data: data, encoding: .utf8)! )")
            }
        }
    }
}

extension WebRTCReceiveService: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        DispatchQueue.main.async {
            self.state = state
        }
        if state == .connected {
            webRTCClient.speakerOn()
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        print("client received data: \(data)")
    }
}
