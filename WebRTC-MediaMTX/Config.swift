import Foundation

let defaultIceServers = ["stun:stun.l.google.com:19302"]

let streamURL = URL(string: baseURL)!
let streamBackchannelURL = URL(string: baseURL + "_backchannel")!
let baseURL = "http://localhost:8889/mystream"
