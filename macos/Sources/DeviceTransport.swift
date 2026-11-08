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
        return e.domain==NSURLErrorDomain && [NSURLErrorTimedOut,NSURLErrorCannotFindHost,NSURLErrorDNSLookupFailed,NSURLErrorCannotConnectToHost,NSURLErrorNetworkConnectionLost,NSURLErrorNotConnectedToInternet].contains(e.code)
    }
}

// Discovery identifiers are hints; every response must still match the bound board.
enum DeviceIdentity {
    struct ConnectionChanged:LocalizedError {var errorDescription:String?{"连接目标已变化，旧请求回执已忽略。"}}
    struct Mismatch:LocalizedError {var errorDescription:String?{"此地址不是已绑定的屏幕，请重新发现原设备；更换屏幕需先解除绑定。"}}
    static func valid(_ id:String)->Bool {id.range(of:"^mojian-[0-9a-f]{12}$",options:.regularExpression) != nil}
    static func origin(_ id:String)->String? {valid(id) ? "http://"+id+".local":nil}
    static func verify(_ expected:String?,_ actual:String?)throws {
        guard let expected,!expected.isEmpty else{return}
        guard valid(expected),actual==expected else{throw Mismatch()}
    }
}

// Acceptance (HTTP 202) is not a display acknowledgement. Only completed may release the send queue.
enum DeviceCommitReceipt {
    static func wait(transaction:String,timeout:TimeInterval=180,pollNanoseconds:UInt64=500_000_000,poll:()async throws->Data)async throws {
        let started=ProcessInfo.processInfo.systemUptime
        while true {
            guard ProcessInfo.processInfo.systemUptime-started<timeout else{throw URLError(.timedOut)}
            let bytes:Data
            do{bytes=try await poll()}
            catch {
                guard ConnectionRecovery.transient(error) else{throw error}
                guard ProcessInfo.processInfo.systemUptime-started<timeout else{throw URLError(.timedOut)}
                // Retry this receipt only; never re-submit a possibly applied frame.
                try await Task.sleep(nanoseconds:pollNanoseconds)
                continue
            }
            guard ProcessInfo.processInfo.systemUptime-started<timeout else{throw URLError(.timedOut)}
            guard let value=try JSONSerialization.jsonObject(with:bytes) as? [String:Any],value["transaction_id"] as? String==transaction,let status=value["status"] as? String else{throw DeskError(message:"设备刷新回执不完整，未确认同步成功")}
            switch status {
            case "completed":return
            case "failed":throw DeskError(message:(value["error"] as? String) ?? "设备刷新失败，未确认同步成功")
            case "pending":break
            default:throw DeskError(message:"设备刷新状态未知，未确认同步成功")
            }
            guard ProcessInfo.processInfo.systemUptime-started<timeout else{throw URLError(.timedOut)}
            try await Task.sleep(nanoseconds:pollNanoseconds)
        }
    }
}
