import Foundation

// Injectable transport keeps reconnect and queue tests independent of real hardware.
struct DeviceTransport {
    var state:(String,String)async throws->DeviceState = {try await Remote.state($0,$1)}
    var send:(String,String,Data,[DeskTask],String,String,Bool)async throws->Void = {
        try await Remote.send(origin:$0,token:$1,frame:$2,tasks:$3,layout:$4,contentKey:$5,full:$6)
    }
}
enum ConnectionRecovery {
    static func delay(_ failures:Int)->TimeInterval {min(60,5*pow(2,Double(min(max(failures-1,0),4))))}
    static func transient(_ error:Error)->Bool {
        let e=error as NSError
        return e.domain==NSURLErrorDomain && [NSURLErrorTimedOut,NSURLErrorCannotFindHost,NSURLErrorCannotConnectToHost,NSURLErrorNetworkConnectionLost,NSURLErrorNotConnectedToInternet].contains(e.code)
    }
}
