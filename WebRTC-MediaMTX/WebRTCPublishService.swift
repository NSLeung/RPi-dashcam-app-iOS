import SwiftUI
import WebRTC

class WebRTCPublishService: ObservableObject {
    let webRTCClient: WebRTCClient
    
    private var queuedCandidates = [RTCIceCandidate]()
    private var sessionURL: URL?
    private var eTag: String?
    private var localOfferData: OfferData?
    
    @Published var state: RTCIceConnectionState?
    
    struct OfferData {
        let iceUfrag: String
        let icePwd: String
        let medias: [String]
    }
    
    init() {
        webRTCClient = WebRTCClient(iceServers: defaultIceServers)
        webRTCClient.delegate = self
    }
    
    func startStream() {
        webRTCClient.offer { sdp in
            print("1 created local offer")
            self.localOfferData = self.parseOffer(offer: sdp.sdp)
            Task {
                await self.sendLocalOffer(sdp)
            }
        }
    }
    
    private func sendLocalCandidates(_ candidates: [RTCIceCandidate]) async {
        guard let sessionURL = sessionURL else {
            print("No Session URL, aborting")
            return
        }
        var request = URLRequest(url: sessionURL)
        request.httpMethod = "PATCH"
        request.addValue("application/trickle-ice-sdpfrag", forHTTPHeaderField: "Content-Type")
        request.addValue("*", forHTTPHeaderField: "If-Match")
        let sdpFragment = generateSdpFragment(offerData: localOfferData!, candidates: candidates)
        request.httpBody = sdpFragment.data(using: .utf8)
        
        print("Sending local Candidates:\n\(sdpFragment)")
        
        if let (data, response) = try? await URLSession.shared.data(for: request) {
            print("Did send candidates with response: \((response as! HTTPURLResponse).statusCode)")
            print(String(data: data, encoding: .utf8) ?? response)
        }
    }
    
    private func sendLocalOffer(_ sdp: RTCSessionDescription) async {
        print("2 Sending local sdp")
        var request = URLRequest(url: streamBackchannelURL.appendingPathComponent("whip"))
        request.httpMethod = "POST"
        request.addValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.httpBody = sdp.sdp.data(using: .utf8)
        
        if let (data, response) = try? await URLSession.shared.data(for: request) {
            if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) {
                print("2 response: \(httpResponse.statusCode)")
                if let sessionURLRaw = httpResponse.allHeaderFields["Location"] as? String {
                    sessionURL = streamBackchannelURL.appendingPathComponent(sessionURLRaw)
                    print("sessionURL: \(sessionURL?.absoluteString ?? "Error")")
                } else {
                    print("Location Header not found")
                    return
                }
                
                print("3 Trying to encode remoteSdp")
                if let remoteSdp = String(data: data, encoding: .utf8) {
                    let remoteDesc = RTCSessionDescription(type: .answer, sdp: remoteSdp)
                    self.webRTCClient.set(remoteSdp: remoteDesc) { error in
                        print("Did set remote sdp with error: ", error.debugDescription)
                        Task {
                            if !self.queuedCandidates.isEmpty {
                                await self.sendLocalCandidates(self.queuedCandidates)
                                self.queuedCandidates = []
                            }
                        }
                    }
                } else {
                    print("Couldn't decode remoteSdp")
                }
            } else {
                print("Couldn't send Local Offer: \(String(data: data, encoding: .utf8)! )")
            }
        }
    }
    
    private func parseOffer(offer: String) -> OfferData {
        var iceUfrag = ""
        var icePwd = ""
        var medias = [String]()
        
        for line in offer.components(separatedBy: "\r\n") {
            if line.hasPrefix("m=") {
                medias.append(String(line.dropFirst(2)))
            } else if iceUfrag.isEmpty, line.hasPrefix("a=ice-ufrag:") {
                iceUfrag = String(line.dropFirst("a=ice-ufrag:".count))
            } else if icePwd.isEmpty, line.hasPrefix("a=ice-pwd:") {
                icePwd = String(line.dropFirst("a=ice-pwd:".count))
            }
        }

        return OfferData(iceUfrag: iceUfrag, icePwd: icePwd, medias: medias)
    }
    
    private func generateSdpFragment(offerData: OfferData, candidates: [RTCIceCandidate]) -> String {
        var candidatesByMedia = [Int32: [RTCIceCandidate]]()

        for candidate in candidates {
            if candidatesByMedia[candidate.sdpMLineIndex] == nil {
                candidatesByMedia[candidate.sdpMLineIndex] = []
            }
            candidatesByMedia[candidate.sdpMLineIndex]?.append(candidate)
        }

        var frag = "a=ice-ufrag:" + (offerData.iceUfrag) + "\r\n"
        + "a=ice-pwd:" + (offerData.icePwd) + "\r\n"

        var mid: Int32 = 0
        
        for media in offerData.medias {
            if let mediaCandidates = candidatesByMedia[mid] {
                frag += "m=" + media + "\r\n"
                + "a=mid:" + String(mid) + "\r\n"
                
                for candidate in mediaCandidates {
                    frag += "a=" + candidate.sdp + "\r\n"
                }
            }
            mid += 1
        }

        return frag
    }
}

extension WebRTCPublishService: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        if let _ = sessionURL {
            Task {
                await sendLocalCandidates([candidate])
            }
        } else {
            queuedCandidates.append(candidate)
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        DispatchQueue.main.async {
            self.state = state
        }
        if state == .connected {
            webRTCClient.unmuteAudio()
            webRTCClient.showVideo()
        }
        print(state.description)
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        print("client received data: \(data)")
    }
}
