import SwiftUI
import WebRTC

struct WebRTCReceiveView: UIViewRepresentable {
    
    var client: WebRTCClient
    
    func makeUIView(context: UIViewRepresentableContext<WebRTCReceiveView>) -> RTCMTLVideoView {
        let view = RTCMTLVideoView()
        view.backgroundColor = .black
        view.videoContentMode = .scaleAspectFill
        client.renderRemoteVideo(to: view)
        
        return view
    }
    
    func updateUIView(_ view: RTCMTLVideoView, context: UIViewRepresentableContext<WebRTCReceiveView>) {
        
    }
}
