import Foundation

// Injectable transport keeps reconnect and queue tests independent of real hardware.
struct DeviceTransport {
    var state:(String,String)async throws->DeviceState = {try await Remote.state($0,$1)}
    var send:(String,String,Data,[DeskTask],String,String,Bool,String?)async throws->Void = {
        try await Remote.send(origin:$0,token:$1,frame:$2,tasks:$3,layout:$4,contentKey:$5,full:$6,expected:$7)
    }
}
enum ConnectionRecovery {
    static func delay(_ failures:Int)->TimeInterval {min(60,5*pow(2,Double(min(max(failures-1,0),4))))}
    static func transient(_ error:Error)->Bool {
        let e=error as NSError
        return e.domain==NSURLErrorDomain && [NSURLErrorTimedOut,NSURLErrorCannotFindHost,NSURLErrorCannotConnectToHost,NSURLErrorNetworkConnectionLost,NSURLErrorNotConnectedToInternet].contains(e.code)
    }
}

// Discovery identifiers are hints; every response must still match the bound board.
enum DeviceIdentity {
    struct Mismatch:LocalizedError {var errorDescription:String?{"此地址不是已绑定的屏幕，请重新发现原设备；更换屏幕需先解除绑定。"}}
    static func valid(_ id:String)->Bool {id.range(of:"^mojian-[0-9a-f]{12}$",options:.regularExpression) != nil}
    static func origin(_ id:String)->String? {valid(id) ? "http://"+id+".local":nil}
    static func verify(_ expected:String?,_ actual:String?)throws {
        guard let expected,!expected.isEmpty else{return}
        guard valid(expected),actual==expected else{throw Mismatch()}
    }
}
