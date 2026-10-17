import Foundation

struct AgentMemory:Codable,Identifiable {var id=UUID();var text:String;var created=Date()}
struct AgentRecord:Codable,Identifiable {var id=UUID();var date=Date();var text:String}
struct AgentState:Codable {
    var version=1
    var commuteEnabled=false
    var memories:[AgentMemory]=[]
    var records:[AgentRecord]=[]
    var delivered:[String]=[]
    var session:String?
    var history:[AssistantLine]=[]
}
struct AgentProposal:Identifiable {
    var id=UUID();var name:String;var arguments:[String:Any];var summary:String
}
enum AgentRules {
    static func nextArrival(_ date:Date,_ settings:Preferences)->Date? {
        guard settings.startMinute != settings.endMinute else{return nil}
        let c=WorkSchedule.calendar,start=c.startOfDay(for:date)
        for offset in 0...8 {
            guard let day=c.date(byAdding:.day,value:offset,to:start),CalendarData.workday(day,settings),let arrival=c.date(byAdding:.minute,value:settings.startMinute,to:day),arrival>date else{continue}
            return arrival
        };return nil
    }
    static func shouldCheck(_ date:Date,_ settings:Preferences,enabled:Bool)->Bool {
        guard enabled,let arrival=nextArrival(date,settings) else{return false}
        return arrival.timeIntervalSince(date)<=10800
    }
    static func actionable(_ date:Date,_ settings:Preferences,_ route:CommuteSnapshot)->Bool {
        guard date.timeIntervalSince(route.fetched)>=0,date.timeIntervalSince(route.fetched)<900,let arrival=nextArrival(date,settings) else{return false}
        return arrival.timeIntervalSince(date)<=Double(route.minutes+settings.commuteBuffer)*60
    }
    static func key(_ date:Date,_ settings:Preferences)->String {"commute-"+dateText(nextArrival(date,settings) ?? date,"yyyy-MM-dd")}

}

@MainActor final class HarnessBridge {
    var onTool:((String,[String:Any],Bool)async->[String:Any])?
    var onStatus:((String)->Void)?
    private var process:Process?,input:FileHandle?,output:FileHandle?
    private var activeID:String?,automatic=false
    private var generation=UUID()
    private var continuation:CheckedContinuation<(String,String,Int),Error>?
    private var reader:LineReceiver?
    private var watchdog:Task<Void,Never>?
    private let timeoutNanoseconds:UInt64
    private let command:(URL,[String])?
    init(timeoutNanoseconds:UInt64=120_000_000_000,command:(URL,[String])?=nil){self.timeoutNanoseconds=timeoutNanoseconds;self.command=command}
    func start()throws {
        if process?.isRunning == true{return}
        guard let resources=Bundle.main.resourceURL else{throw DeskError(message:"Agent资源不存在")}
        let engine=resources.appendingPathComponent("agent-engine")
        let node=engine.appendingPathComponent("runtime/bin/node")
        guard command != nil || (FileManager.default.isExecutableFile(atPath:node.path) && FileManager.default.fileExists(atPath:engine.appendingPathComponent("bridge.mjs").path)) else{throw DeskError(message:"Agent运行环境未安装，请使用完整应用包")}
        let p=Process(),stdin=Pipe(),stdout=Pipe()
        p.executableURL=command?.0 ?? node;p.arguments=command?.1 ?? [engine.appendingPathComponent("bridge.mjs").path]
        p.environment=["HOME":FileManager.default.homeDirectoryForCurrentUser.path,"PATH":node.deletingLastPathComponent().path+":/usr/bin:/bin","LANG":"zh_CN.UTF-8"]
        p.standardInput=stdin;p.standardOutput=stdout;p.standardError=FileHandle.nullDevice
        let launchID=UUID();generation=launchID
        let receiver=LineReceiver{[weak self] value in Task{@MainActor in guard self?.generation==launchID else{return};self?.receive(value)}}
        stdout.fileHandleForReading.readabilityHandler={handle in receiver.append(handle.availableData)}
        reader=receiver;input=stdin.fileHandleForWriting;output=stdout.fileHandleForReading
        p.terminationHandler={[weak self]_ in Task{@MainActor in if self?.generation==launchID{self?.failed("Agent进程已退出，可重试")}}}
        try p.run();process=p
    }
    func run(prompt:String,key:String,model:String,context:[String:Any],home:URL,session:String?,automatic:Bool)async throws->(String,String,Int) {
        guard continuation==nil else{throw DeskError(message:"Agent正在处理中")}
        try start();let id=UUID().uuidString;activeID=id;self.automatic=automatic
        return try await withCheckedThrowingContinuation{continuation in
            self.continuation=continuation
            watchdog=Task{[weak self] in
                guard let self else{return}
                do{try await Task.sleep(nanoseconds:timeoutNanoseconds)}catch{return}
                guard activeID==id else{return}
                shutdown("助理请求超时，已停止；可重新发送")
            }
            write(["type":"run","id":id,"prompt":prompt,"key":key,"model":model,"context":context,"home":home.path,"session":session as Any? ?? NSNull(),"automatic":automatic])
        }
    }
    private func write(_ value:[String:Any]) {
        do{var data=try JSONSerialization.data(withJSONObject:value);data.append(10);try input?.write(contentsOf:data)}catch{failed("Agent通信失败，请重试")}
    }
    private func receive(_ value:[String:Any]) {
        switch value["type"] as? String {
        case "ready":onStatus?("DeepSeek Harness · 已就绪")
        case "tool":
            guard let id=value["id"] as? String else{return}
            guard value["run"] as? String==activeID,let name=value["name"] as? String else{write(["type":"tool_result","id":id,"result":["error":"请求已过期"]]);return}
            onStatus?("正在"+(["get_context":"读取上下文","get_weather":"查询天气","get_commute":"查询高德通勤","list_tasks":"查看待办","get_memory":"读取偏好"][name] ?? "处理工具请求"))
            let args=value["args"] as? [String:Any] ?? [:],isAutomatic=automatic
            let runID=activeID
            Task{let result=await onTool?(name,args,isAutomatic) ?? ["error":"工具未接入"];guard activeID==runID else{return};write(["type":"tool_result","id":id,"result":result])}
        case "done":
            guard value["id"] as? String==activeID else{return}
            watchdog?.cancel();watchdog=nil
            let c=continuation;continuation=nil;activeID=nil
            c?.resume(returning:(value["text"] as? String ?? "",value["session"] as? String ?? "",value["tools"] as? Int ?? 0));onStatus?("DeepSeek Harness · 已完成")
        case "error":guard value["id"] as? String==activeID else{return};failed(value["message"] as? String ?? "Agent请求失败")
        default:break
        }
    }
    private func failed(_ message:String){watchdog?.cancel();watchdog=nil;let c=continuation;continuation=nil;activeID=nil;c?.resume(throwing:DeskError(message:message));onStatus?(message)}
    private func shutdown(_ message:String){
        generation=UUID()
        let oldProcess=process;process=nil
        try? input?.close();input=nil
        output?.readabilityHandler=nil;try? output?.close();output=nil;reader=nil
        oldProcess?.terminate()
        failed(message)
    }
    func close(){shutdown("已停止Agent；已确认的修改保留，待确认操作仍需确认")}

}
final class LineReceiver:@unchecked Sendable {
    private var buffer=Data();private let lock=NSLock();let callback:([String:Any])->Void
    init(_ callback:@escaping([String:Any])->Void){self.callback=callback}
    func append(_ data:Data){lock.lock();defer{lock.unlock()};buffer.append(data);if buffer.count>2_000_000{buffer.removeAll();return}
        while let i=buffer.firstIndex(of:10){let line=buffer.prefix(upTo:i);buffer.removeSubrange(...i);if let value=(try? JSONSerialization.jsonObject(with:line)) as? [String:Any]{callback(value)}}
    }
}
