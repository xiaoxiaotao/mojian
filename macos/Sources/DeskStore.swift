import SwiftUI
import UserNotifications
import CryptoKit

struct WorkSchedule {
    static var calendar:Calendar {var c=Calendar(identifier:.gregorian);c.timeZone=TimeZone(identifier:"Asia/Shanghai")!;return c}
    static func working(_ date:Date,_ p:Preferences)->Bool {
        let c=calendar,minute=c.component(.hour,from:date)*60+c.component(.minute,from:date)
        if p.startMinute==p.endMinute{return false}
        if p.startMinute<p.endMinute{return CalendarData.workday(date,p)&&minute>=p.startMinute&&minute<p.endMinute}
        return (CalendarData.workday(date,p)&&minute>=p.startMinute)||(CalendarData.workday(c.date(byAdding:.day,value:-1,to:date)!,p)&&minute<p.endMinute)
    }
    static func nextBoundary(_ date:Date,_ p:Preferences)->Date? {
        let c=calendar,start=c.startOfDay(for:date);var candidates:[Date]=[]
        for offset in -1...8 {guard let day=c.date(byAdding:.day,value:offset,to:start),CalendarData.workday(day,p) else{continue}
            for minutes in [p.startMinute,p.endMinute+(p.endMinute<=p.startMinute ? 1440:0)] {if let d=c.date(byAdding:.minute,value:minutes,to:day),d>date{candidates.append(d)}}
        };return candidates.min()
    }
}
@MainActor final class DeskStore:ObservableObject {
    @Published var tasks:[DeskTask]=[]{didSet{save()}}
    @Published var completionUndo:TaskCompletionUndo?
    private var reminderHistory:[String:Date]=[:]
    private var notificationGeneration:[String:UUID]=[:]
    @Published var settings=Preferences(){didSet{if settings.homeAddress != oldValue.homeAddress || settings.workAddress != oldValue.workAddress || settings.city != oldValue.city {commute=nil;lastCommute = .distantPast};save()}}
    @Published var weather:WeatherSnapshot?
    @Published var quotes:[StockQuote]=[]
    @Published var commute:CommuteSnapshot?
    @Published var nextEvent:NextCalendarEvent?
    @Published var calendarStatus="未启用系统日历"
    @Published var calendarChoices:[(id:String,title:String)]=[]
    @Published var calendarBusy=false
    let calendarFeed=CalendarFeed()
    private var lastCalendar=Date.distantPast
    @Published var afterHours=false
    @Published var now=Date()
    @Published var status="准备好，开始从容的一天。"
    @Published var connected=false
    @Published var isSending=false
    @Published var isConnecting=false
    @Published var syncPending=false
    @Published var syncStatus="连接设备后同步"
    private var reconnectFailures=0,nextReconnect=Date.distantPast,mayReconnect=true
    private var lastContentKey:String?
    private var syncRetryAllowed=true
    let transport:DeviceTransport
    private let notificationDelivery:NotificationDelivery
    @Published var feedBusy=false
    @Published var aiBusy=false
    @Published var feedStatus="等待更新天气和行情"
    @Published var trafficStatus="配置路线后获取实时驾车耗时"
    @Published var brief=""
    @Published var messages:[AssistantLine]=[]
    @Published var focusEnd:Date?
    @Published var lastSync:Date?
    @Published var storageError=""
    @Published var deviceToken=""
    @Published var deepSeekKey=""
    @Published var amapKey=""
    @Published var agent=AgentState()
    @Published var proposals:[AgentProposal]=[]
    @Published var agentStatus="DeepSeek Harness · 待唤起"
    let harness=HarnessBridge()
    var observedAgentTasks=Set<String>(),agentChecking=false,lastAgentRunSucceeded=false
    var lastAgentCheck:Date = .distantPast
    let discovery=DeviceDiscovery()
    private var ready=false,timer:Timer?,overrideUntil:Date?,overrideActive=false
    private var lastMinute="",lastFeed:Date = .distantPast,lastCommute:Date = .distantPast
    private var lastFrame:Data?,appliedSignature="",deviceNeedsFull=true,notified=Set<String>()
    private var pendingSync=false,pendingFull=false,debounce:Task<Void,Never>?
    let directory:URL
    var active:[DeskTask]{InformationLogic.ordered(tasks)}
    var doneToday:Int{tasks.filter{$0.done&&$0.completedAt.map{WorkSchedule.calendar.isDate($0,inSameDayAs:now)} == true}.count}
    var signature:String{afterHours ? "mac.calendar.red-v2": "mac."+settings.layout.rawValue+".red-v2"+(settings.layout == .custom ? "."+String(Int(settings.customRatio*100))+"."+settings.customModules.joined(separator:"-"):"")}
    var content:ScreenContent{ScreenContent(tasks:tasks,settings:settings,weather:weather,quotes:quotes,now:now,afterHours:afterHours,brief:brief,commute:commute,focusEnd:focusEnd,nextEvent:nextEvent,calendarStatus:calendarStatus)}
    init(dataDirectory:URL?=nil,startServices:Bool=true,transport:DeviceTransport=DeviceTransport(),notificationDelivery:NotificationDelivery=NotificationDelivery()){
        self.transport=transport;self.notificationDelivery=notificationDelivery
        directory=dataDirectory ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("MoJian",isDirectory:true)
        do{try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true);if let data=try? Data(contentsOf:directory.appendingPathComponent("state.json")),let state=try? JSONDecoder().decode(SavedState.self,from:data){tasks=state.tasks;settings=state.settings;weather=state.weather;quotes=state.quotes;afterHours=state.afterHours}}catch{storageError="本地数据目录不可写，请检查系统权限"}
        if let data=try? Data(contentsOf:directory.appendingPathComponent("agent-state.json")),let saved=try? JSONDecoder().decode(AgentState.self,from:data){agent=saved;messages=saved.history}
        harness.onTool={[weak self] name,args,automatic in await self?.handleAgentTool(name,args,automatic:automatic) ?? ["error":"应用已关闭"]}
        harness.onStatus={[weak self] text in self?.agentStatus=text}
        if let data=try? Data(contentsOf:directory.appendingPathComponent("reminder-history.json")),let saved=try? JSONDecoder().decode([String:Date].self,from:data){reminderHistory=saved.filter{Date().timeIntervalSince($0.value)<30*86400}}
        ready=true
        guard startServices else{return}
        NotificationCenter.default.addObserver(forName:NSApplication.willTerminateNotification,object:nil,queue:.main){[weak self]_ in Task{@MainActor in self?.harness.close()}}
        // Read protected credentials off the main thread, without requesting authorization at launch.
        Task {
            let values=await Task.detached { [Vault.get("device"),Vault.get("deepseek"),Vault.get("amap")] }.value
            if deviceToken.isEmpty {deviceToken=values[0]};if deepSeekKey.isEmpty {deepSeekKey=values[1]};if amapKey.isEmpty {amapKey=values[2]}
            if !deviceToken.isEmpty && !connected {await connectDevice()}
        }
        importDevelopmentConfiguration()
        discovery.found={[weak self] url in guard let self else{return};self.settings.deviceURL=url;self.status="已发现工作台，正在验证连接…";Task{await self.connectDevice()}}
        timer=Timer.scheduledTimer(withTimeInterval:5,repeats:true){[weak self]_ in Task{@MainActor in await self?.tick()}}
        NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didWakeNotification,object:nil,queue:.main){[weak self]_ in Task{@MainActor in await self?.tick()}}
    }
    func importDevelopmentConfiguration(){
        let args=ProcessInfo.processInfo.arguments
        if let i=args.firstIndex(of:"--import-local-config"),args.count>i+1,let raw=try? String(contentsOfFile:args[i+1],encoding:.utf8){
            for line in raw.split(separator:"\n") {let pieces=line.split(separator:"=",maxSplits:1).map(String.init);guard pieces.count==2 else{continue};let value=pieces[1].trimmingCharacters(in:CharacterSet(charactersIn:"\"' "))
                if pieces[0]=="DEEPSEEK_API_KEY"{deepSeekKey=value;Vault.put("deepseek",value)}
                if pieces[0]=="TODO_TOKEN"{deviceToken=value;Vault.put("device",value)}
                if pieces[0]=="DEEPSEEK_MODEL"{settings.deepSeekModel=value}
            }
        }
        if let i=args.firstIndex(of:"--device-url"),args.count>i+1{settings.deviceURL=args[i+1]}
    }
    func importSessionConfiguration() {
        let panel=NSOpenPanel();panel.title="导入本地连接配置（仅本次会话）";panel.canChooseDirectories=false;panel.showsHiddenFiles=true
        guard panel.runModal() == .OK,let url=panel.url,let raw=try? String(contentsOf:url,encoding:.utf8) else{return}
        for line in raw.split(separator:"\n") {
            let pieces=line.split(separator:"=",maxSplits:1).map(String.init);guard pieces.count==2 else{continue}
            let value=pieces[1].trimmingCharacters(in:CharacterSet(charactersIn:"\"' "))
            switch pieces[0] {case "DEEPSEEK_API_KEY":deepSeekKey=value;case "TODO_TOKEN":deviceToken=value;case "DEEPSEEK_MODEL":settings.deepSeekModel=value;default:break}
        }
        status="本次会话已载入连接配置，未改动钥匙串"
        Task{await connectDevice()}
    }
    func save(){guard ready else{return};do{let state=SavedState(tasks:tasks,settings:settings,weather:weather,quotes:quotes,afterHours:afterHours);try JSONEncoder().encode(state).write(to:directory.appendingPathComponent("state.json"),options:.atomic)}catch{storageError="本地保存失败，请检查磁盘空间"}}
    @Published var credentialsSaving=false
    @discardableResult func storeKeys(device:String,deepseek:String,amap:String)async->Bool {
        guard !credentialsSaving else{return false}
        credentialsSaving=true
        status="正在保存到钥匙串；如系统询问，请完成授权"
        defer{credentialsSaving=false}
        let saved=await Task.detached {
            let deviceSaved=Vault.put("device",device)
            let deepseekSaved=Vault.put("deepseek",deepseek)
            let amapSaved=Vault.put("amap",amap)
            return deviceSaved && deepseekSaved && amapSaved
        }.value
        guard saved else{status="钥匙串保存失败，请检查系统授权后重试";return false}
        if !device.isEmpty{deviceToken=device};if !deepseek.isEmpty{deepSeekKey=deepseek};if !amap.isEmpty{amapKey=amap}
        status="凭据已保存在 macOS 钥匙串"
        return true
    }
    func loadSavedCredentials() {
        status="正在读取钥匙串；如系统询问，请在系统窗口允许墨间访问"
        Task {
            let values=await Task.detached { [Vault.get("device",interactive:true),Vault.get("deepseek",interactive:true),Vault.get("amap",interactive:true)] }.value
            if !values[0].isEmpty{deviceToken=values[0]};if !values[1].isEmpty{deepSeekKey=values[1]};if !values[2].isEmpty{amapKey=values[2]}
            status=values.allSatisfy{$0.isEmpty} ? "尚未读取到凭据，请完成系统授权或在设置中填写":"已读取保存的凭据"
            if !deviceToken.isEmpty{await connectDevice()}
        }
    }
    func start(){Task{if !settings.deviceURL.isEmpty && !deviceToken.isEmpty{await connectDevice();if !connected{try? await Task.sleep(nanoseconds:2_000_000_000);await connectDevice()}};await refreshFeeds();if settings.scheduleEnabled{await checkSchedule()}}}
    func connectDevice(importTasks:Bool=false)async {
        guard !isConnecting,!isSending else{return}
        guard !deviceToken.isEmpty else{status="请先在设备设置中填写访问口令";syncStatus=status;return}
        isConnecting=true;syncStatus="正在连接工作台…"
        defer{isConnecting=false}
        do {
            let state=try await transport.state(settings.deviceURL,deviceToken)
            connected=true;reconnectFailures=0;mayReconnect=true;syncRetryAllowed=true;syncPending=true
            deviceNeedsFull = !(state.baseline_ready ?? !state.needs_full) || !state.local_mode || state.external_layout != true
            appliedSignature=state.layout_id ?? ""
            lastFrame=nil;lastContentKey=nil
            // Import is explicit: an empty Mac list may mean the user completed everything.
            if importTasks {tasks=state.tasks.map{DeskTask(id:$0.id ?? UUID().uuidString,title:$0.title,due:$0.due.flatMap{parseISODate($0)},done:false,completedAt:nil)}}
            syncStatus=deviceNeedsFull || appliedSignature != signature ? "设备布局不同或已重启，请应用布局后同步":"已连接 · 可局部同步"
            status=syncStatus
        }catch {
            connected=false;mayReconnect=ConnectionRecovery.transient(error);reconnectFailures+=1
            nextReconnect=Date().addingTimeInterval(ConnectionRecovery.delay(reconnectFailures))
            syncStatus=mayReconnect ? "工作台暂时离线，将自动重连；内容已保存在 Mac":"连接失败："+error.localizedDescription
            status=syncStatus
        }
    }
    @discardableResult func addTask(_ title:String,due:Date?)->Bool{let title=title.trimmingCharacters(in:.whitespacesAndNewlines);guard !title.isEmpty,title.count<=80 else{status="待办请填写1至80个字";return false};guard active.count<8 else{status="最多保留8项未完成待办，请先完成一项";return false};tasks.append(DeskTask(title:title,due:due));changed();return true}
    func complete(_ id:String){
        guard let i=tasks.firstIndex(where:{$0.id==id}) else{return}
        if tasks[i].done {
            guard active.count<8 else{status="最多保留8项未完成待办，请先完成一项";return}
            if tasks[i].pinned == true && active.filter({$0.pinned == true}).count>=3{tasks[i].pinned=false}
            tasks[i].done=false;tasks[i].completedAt=nil
            if completionUndo?.taskID==id{completionUndo=nil}
        }else{
            let stamp=Date();tasks[i].done=true;tasks[i].completedAt=stamp
            completionUndo=TaskCompletionUndo(taskID:id,completedAt:stamp)
            removeTaskNotifications(id)
        }
        changed()
    }
    func undoCompletion(){
        guard let undo=completionUndo,let task=tasks.first(where:{$0.id==undo.taskID && $0.done && $0.completedAt==undo.completedAt}) else{completionUndo=nil;return}
        complete(task.id)
    }
    @discardableResult func updateTask(_ id:String,title:String,due:Date?)->Bool {
        let clean=title.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !clean.isEmpty,clean.count<=80 else{status="待办请填写1至80个字";return false}
        guard let i=tasks.firstIndex(where:{$0.id==id && !$0.done}) else{status="事项已完成或不存在，请关闭后重试";return false}
        let previous=tasks[i]
        guard previous.title != clean || previous.due != due else{return true}
        removeTaskNotifications(id)
        tasks[i].title=clean;tasks[i].due=due;changed();return true
    }
    func changed(){syncRetryAllowed=true;syncPending=true;syncStatus="已保存在 Mac，等待同步";debounce?.cancel();debounce=Task{try? await Task.sleep(nanoseconds:700_000_000);if !Task.isCancelled,settings.autoSync{debounce=nil;await send(full:false)}}}
    func applyLayout()async{await send(full:true)}
    func send(full:Bool)async {
        if isSending{pendingSync=true;pendingFull=pendingFull||full;syncPending=true;return}
        guard connected else{syncPending=true;syncStatus="已保存在 Mac，工作台连接后同步";status=syncStatus;return}
        if !full&&(deviceNeedsFull||appliedSignature != signature){syncPending=true;syncStatus="布局或模式已改变，请应用布局全刷一次";status=syncStatus;return}
        isSending=true
        do {
            let frame=try ScreenRenderer.blackFrame(content)
            let sendingSignature=signature,sendingTasks=tasks
            let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
            let durable=try encoder.encode(SavedState(tasks:tasks,settings:settings,weather:weather,quotes:quotes,afterHours:afterHours))
            let contentKey=SHA256.hash(data:durable).map{String(format:"%02x",$0)}.joined()
            if full || frame != lastFrame || contentKey != lastContentKey {
                syncStatus=full ? "正在应用布局，约20秒…":"正在局部同步…";status=syncStatus
                try await transport.send(settings.deviceURL,deviceToken,frame,sendingTasks,sendingSignature,contentKey,full)
                lastFrame=frame;lastContentKey=contentKey;appliedSignature=sendingSignature;deviceNeedsFull=false;lastSync=Date()
                if full{settings.autoSync=true}
            }
            syncRetryAllowed=true;syncPending=pendingSync;syncStatus="已同步到墨水屏 · "+dateText(lastSync ?? Date(),"HH:mm");status=syncStatus
        }catch {
            syncPending=true
            if ConnectionRecovery.transient(error){connected=false;mayReconnect=true;reconnectFailures+=1;nextReconnect=Date().addingTimeInterval(ConnectionRecovery.delay(reconnectFailures));syncStatus="同步中断，内容已保存在 Mac；重连后重试局刷"}
            else{syncRetryAllowed=false;syncStatus="同步失败："+error.localizedDescription}
            status=syncStatus
        }
        isSending=false
        if pendingSync {
            let queuedFull=pendingFull;pendingSync=false;pendingFull=false
            if connected && (settings.autoSync||queuedFull){await send(full:queuedFull)}
        }
    }
    func recoverConnection()async {
        guard !deviceToken.isEmpty,!settings.deviceURL.isEmpty,!isSending,!isConnecting else{return}
        if !connected && mayReconnect && Date()>=nextReconnect{await connectDevice()}
        // A different layout/phone ownership always requires explicit application, never a silent full refresh.
        if connected && syncPending && syncRetryAllowed && settings.autoSync && !deviceNeedsFull && appliedSignature==signature{await send(full:false)}
    }
    func switchMode()async {
        afterHours.toggle();overrideActive=true;overrideUntil=settings.scheduleEnabled ? WorkSchedule.nextBoundary(Date(),settings):nil;save()
        if connected{await send(full:true)}else{status="已切换预览；连接设备后应用"}
    }
    func checkSchedule()async {
        guard settings.scheduleEnabled else{return}
        if overrideActive {if let until=overrideUntil,Date()>=until{overrideActive=false;overrideUntil=nil}else{return}}
        let target = !WorkSchedule.working(Date(),settings)
        if target != afterHours{afterHours=target;save();if settings.autoSync&&connected{await send(full:true)}else{status="已按作息切换预览，应用后同步屏幕"}}
    }
    func enableNotifications()async{do{let allowed=try await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound]);settings.notifications=allowed;status=allowed ? "提醒已开启":"系统未允许通知，可在系统设置中调整"}catch{status="通知权限申请失败"}}
    private func saveReminderHistory(){
        let cutoff=Date().addingTimeInterval(-30*86400)
        reminderHistory=Dictionary(uniqueKeysWithValues:reminderHistory.filter{$0.value>=cutoff}.sorted{$0.value>$1.value}.prefix(512).map{($0.key,$0.value)})
        do{try JSONEncoder().encode(reminderHistory).write(to:directory.appendingPathComponent("reminder-history.json"),options:.atomic)}catch{status="提醒记录保存失败，下次启动可能重复提醒"}
    }
    private func removeTaskNotifications(_ id:String){
        // Invalidate pending completion callbacks, while preserving delivery history across undo/restart.
        let prefix="task-"+id+"-"
        let keys=Set(notified.filter{$0.hasPrefix(prefix)}).union(reminderHistory.keys.filter{$0.hasPrefix(prefix)})
        for key in keys{notificationGeneration[key]=UUID()}
        notificationDelivery.remove(Array(keys))
    }
    func notify(_ title:String,_ body:String,_ id:String){
        guard settings.notifications,!notified.contains(id),reminderHistory[id]==nil else{return}
        notified.insert(id);let generation=UUID();notificationGeneration[id]=generation
        let content=UNMutableNotificationContent();content.title=title;content.body=body;content.sound = .default
        let request=UNNotificationRequest(identifier:id,content:content,trigger:nil)
        notificationDelivery.add(request){[weak self] error in Task{@MainActor in
            guard let self else{return}
            guard self.notificationGeneration[id]==generation else{
                self.notificationDelivery.remove([id]);return
            }
            if error != nil{self.notified.remove(id);return}
            if id.hasPrefix("task-"){self.reminderHistory[id]=Date();self.saveReminderHistory()}
        }}
    }
    func tick()async {
        now=Date();if now.timeIntervalSince(lastCalendar)>60{refreshCalendar()};await recoverConnection();await checkSchedule()
        if let end=focusEnd,end<=now{focusEnd=nil;notify("这一段专注完成了","起来走走，给眼睛一点休息。","focus-"+String(Int(end.timeIntervalSince1970)))}
        let minute=dateText(now,"yyyy-MM-dd HH:mm")
        if minute != lastMinute{lastMinute=minute;if settings.autoSync&&connected{await send(full:false)}}
        if now.timeIntervalSince(lastFeed)>600{await refreshFeeds()}
        if !afterHours {
            for task in active {if let reminder=TaskReminderRules.candidate(task,at:now){notify(reminder.title,reminder.body,reminder.key)}}
            if let w=weather,w.code>=51,now.timeIntervalSince(w.fetched)<3600{notify("今天出门记得带伞","\(settings.city)\(w.text)，留意出行天气。","rain-"+dateText(now,"yyyy-MM-dd"))}
        }
        await agentPulse()
    }

    func refreshFeeds(forceWeather:Bool=false)async {
        guard !feedBusy else{return};feedBusy=true;lastFeed=Date();var errors:[String]=[]
        do{if forceWeather||weather==nil||weather?.hours==nil||Date().timeIntervalSince(weather!.fetched)>1800{weather=try await Remote.weather(settings)}}catch{errors.append(error.localizedDescription)}
        do{quotes=try await Remote.stocks(settings.stocks)}catch{errors.append(error.localizedDescription)}
        feedStatus=errors.isEmpty ? "天气与行情已更新 · "+dateText(Date(),"HH:mm"):errors.joined(separator:"；");feedBusy=false;save()
    }
    func refreshCommute()async {
        lastCommute=Date();do{commute=try await Remote.commute(settings,key:amapKey);trafficStatus="高德 · "+dateText(Date(),"HH:mm")+" · "+(commute?.trafficSummary ?? "路况详情未返回")}catch{commute=nil;trafficStatus=error.localizedDescription}
    }
    func pinTask(_ id:String){
        guard let i=tasks.firstIndex(where:{$0.id==id && !$0.done}) else{return}
        let pin = !(tasks[i].pinned ?? false)
        guard !pin || active.filter({$0.pinned ?? false}).count<3 else{status="最多置顶三件重要的事";return}
        tasks[i].pinned=pin;changed()
    }
    func configureInformation(_ update:(inout InformationSettings)->Void){var value=settings.info;update(&value);settings.info=value;refreshCalendar();changed()}
    func authorizeCalendar()async {
        guard !calendarBusy else{return};calendarBusy=true;defer{calendarBusy=false}
        do{if try await calendarFeed.request(){calendarChoices=calendarFeed.choices;configureInformation{$0.calendarEnabled=true};calendarStatus=calendarChoices.isEmpty ? "没有可读取的日历":"请选择允许显示的日历"}else{calendarStatus="未获授权，可在系统设置中允许日历访问"}}
        catch{calendarStatus="日历授权失败："+error.localizedDescription}
    }
    func refreshCalendar(){
        lastCalendar=Date();nextEvent=nil
        guard settings.info.calendarEnabled else{calendarStatus="未启用系统日历";return}
        guard calendarFeed.authorized else{calendarStatus="请授权读取系统日历";return}
        calendarChoices=calendarFeed.choices
        guard calendarChoices.contains(where:{settings.info.calendarIDs.contains($0.id)}) else{calendarStatus="请在信息卡片中选择可用日历";return}
        nextEvent=calendarFeed.next(ids:settings.info.calendarIDs,at:now)
        calendarStatus=nextEvent == nil ? "未来七天暂无日程":"日历已更新 · "+dateText(Date(),"HH:mm")
    }
    func startFocus(){if focusEnd != nil{focusEnd=nil}else{focusEnd=Date().addingTimeInterval(Double(settings.focusMinutes*60))};changed()}
    func ask(_ prompt:String,automatic:Bool=false)async {
        guard !prompt.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{return}
        guard !aiBusy else{return}
        guard !deepSeekKey.isEmpty else{
            status="请先在设备与设置中配置或读取 DeepSeek 密钥"
            if !automatic{messages.append(AssistantLine(user:true,text:prompt));messages.append(AssistantLine(user:false,text:status));saveAgent()}
            return
        }
        lastAgentRunSucceeded=false;aiBusy=true;observedAgentTasks=[]
        if !automatic{messages.append(AssistantLine(user:true,text:prompt));saveAgent()}
        do {
            let (answer,session,tools)=try await harness.run(prompt:prompt,key:deepSeekKey,model:settings.deepSeekModel,context:agentContext(),home:directory.appendingPathComponent("harness"),session:agent.session,automatic:automatic)
            guard !answer.isEmpty else{throw DeskError(message:"本次没有取得回复，请重试")}
            agent.session=session;messages.append(AssistantLine(user:false,text:answer));brief=answer;lastAgentRunSucceeded=true
            recordAgent((automatic ? "后台提醒":"对话")+"完成 · 调用\(tools)次工具");changed()
        }catch{messages.append(AssistantLine(user:false,text:"这次请求未完成："+error.localizedDescription));recordAgent("请求未完成；没有自动重放待确认操作")}
        saveAgent();aiBusy=false
    }
    func stopAgent(){guard aiBusy else{return};harness.close();agentStatus="已停止；已确认的操作保留"}
    func commuteContext()->String {
        let now=Date(),start=String(format:"%02d:%02d",settings.startMinute/60,settings.startMinute%60)
        var parts=["高德Key"+(amapKey.isEmpty ? "未配置":"已配置"),"查询状态："+trafficStatus,"设置的上班时间"+start,"额外预留\(settings.commuteBuffer)分钟",CalendarData.workday(now,settings) ? "今天是设置中的工作日":"今天是设置中的休息日；用户若今天仍上班，可按今天上班时间计算并说明此前提"]
        if let route=commute,now.timeIntervalSince(route.fetched)<900 {
            parts += ["来源：高德驾车路径规划，查询时间"+dateText(route.fetched,"MM-dd HH:mm"),route.text,route.trafficSummary ?? "未返回分段路况"]
            if let km=route.distanceKM {parts.append(String(format:"全程约%.1f公里",km))}
            let day=WorkSchedule.calendar.startOfDay(for:now)
            if let arrival=WorkSchedule.calendar.date(byAdding:.minute,value:settings.startMinute,to:day) {
                let departure=arrival.addingTimeInterval(-Double(route.minutes+settings.commuteBuffer)*60)
                parts.append("若今天按"+start+"到公司，按当前耗时计算建议"+dateText(departure,"HH:mm")+"前出发；"+(now>departure ? "该出发时间已过，须结合现在时间说明":"当前尚未到建议出发时间"))
            }
        }else{parts.append("没有可用的新鲜路线结果，不得编造耗时或路况")}
        return parts.joined(separator:"；")
    }
}
