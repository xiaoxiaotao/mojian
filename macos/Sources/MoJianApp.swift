import SwiftUI
import AppKit

@main struct MoJianApp:App {
    @StateObject private var store=DeskStore()
    init(){
        let args=ProcessInfo.processInfo.arguments
        if args.contains("--reliability-test"){Task{@MainActor in await ReliabilityTest.run();exit(0)};dispatchMain()}
        if args.contains("--task-management-test"){Task{@MainActor in await TaskManagementTest.run();exit(0)};dispatchMain()}
        if args.contains("--information-test"){InformationTest.run();exit(0)}
        if args.contains("--self-test"){SelfTest.run();exit(0)}
        if let i=args.firstIndex(of:"--render-current"),args.count>i+1 {
            let out=URL(fileURLWithPath:args[i+1]);try! FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
            let path=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("MoJian/state.json")
            let state=try! JSONDecoder().decode(SavedState.self,from:Data(contentsOf:path))
            let image=ScreenRenderer.render(ScreenContent(tasks:state.tasks,settings:state.settings,weather:state.weather,quotes:state.quotes,afterHours:state.afterHours))
            try! ScreenRenderer.blackFrame(ScreenContent(tasks:state.tasks,settings:state.settings,weather:state.weather,quotes:state.quotes,afterHours:state.afterHours)).write(to:out.appendingPathComponent("frame.bin"));try! ScreenRenderer.savePNG(image,to:out.appendingPathComponent("preview.png"));exit(0)
        }
        if let i=args.firstIndex(of:"--render-previews"),args.count>i+1 {
            let directory=URL(fileURLWithPath:args[i+1]);try? FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            let now=Date(),tasks=[DeskTask(title:"整理下周的产品计划",due:now.addingTimeInterval(3600)),DeskTask(title:"给客户确认设计方案",due:now.addingTimeInterval(7200)),DeskTask(title:"读完一本喜欢的书",due:nil)]
            var settings=Preferences()
            settings.info.cards=["countdown","week"]
            settings.info.dates=[ImportantDate(title:"示例：产品发布",date:now.addingTimeInterval(12*86400))]
            let weather=WeatherSnapshot(temperature:22,code:2,days:[DayForecast(date:"2026-10-17",low:18,high:25,code:2),DayForecast(date:"2026-10-18",low:19,high:24,code:61),DayForecast(date:"2026-10-19",low:18,high:23,code:0)],fetched:now)
            for layout in DeskLayout.allCases {settings.layout=layout;let content=ScreenContent(tasks:tasks,settings:settings,weather:weather,quotes:[],now:now);try? ScreenRenderer.savePNG(ScreenRenderer.render(content),to:directory.appendingPathComponent(layout.rawValue+".png"))}
            let content=ScreenContent(tasks:tasks,settings:settings,weather:weather,quotes:[],now:now,afterHours:true)
            try? ScreenRenderer.savePNG(ScreenRenderer.render(content),to:directory.appendingPathComponent("calendar.png"));print("Exported illustrative layout previews, not live data");exit(0)
        }
    }
    var body:some Scene {
        WindowGroup("墨间",id:"main"){RootView().environmentObject(store).preferredColorScheme(.light)}.defaultSize(width:1280,height:900).windowStyle(.hiddenTitleBar).commands { CommandGroup(after:.newItem) { Button("导入本地连接配置…"){store.importSessionConfiguration()} } }
        MenuBarExtra("墨间",systemImage:store.afterHours ? "moon":"rectangle.inset.filled.and.person.filled"){MenuContents().environmentObject(store)}
    }
}

struct MenuContents:View {
    @EnvironmentObject var store:DeskStore
    @Environment(\.openWindow) var openWindow
    var body:some View {
        Text(store.afterHours ? "下班模式 · 万年历":"工作模式 · "+store.settings.layout.title)
        Button(store.afterHours ? "开始工作":"下班了"){Task{await store.switchMode()}}.disabled(store.isSending)
        Button("同步变化内容"){Task{await store.send(full:false)}}.disabled(!store.connected||store.isSending)
        Divider();Button("显示墨间"){openWindow(id:"main");NSApp.activate(ignoringOtherApps:true)}
        Button("退出墨间"){NSApp.terminate(nil)}
    }
}
enum SelfTest {
    @MainActor static func run(){
        precondition(ScreenRenderer.stockMovement(4.77)=="▲ +4.77%")
        precondition(ScreenRenderer.stockMovement(-9.99)=="▼ -9.99%")
        precondition(ScreenRenderer.stockMovement(0)=="— 0.00%")
        let iso=ISO8601DateFormatter();func date(_ value:String)->Date{iso.date(from:value)!}
        var p=Preferences()
        precondition(!WorkSchedule.working(date("2026-10-19T08:59:00+08:00"),p))
        precondition(WorkSchedule.working(date("2026-10-19T09:00:00+08:00"),p))
        precondition(!WorkSchedule.working(date("2026-10-19T18:00:00+08:00"),p))
        precondition(!WorkSchedule.working(date("2026-10-18T12:00:00+08:00"),p))
        precondition(WorkSchedule.nextBoundary(date("2026-10-19T09:00:00+08:00"),p)==date("2026-10-19T18:00:00+08:00"))
        p.startMinute=22*60;p.endMinute=6*60
        precondition(WorkSchedule.working(date("2026-10-20T02:00:00+08:00"),p))
        precondition(!WorkSchedule.working(date("2026-10-19T02:00:00+08:00"),p))
        precondition(!WorkSchedule.working(date("2026-10-01T10:00:00+08:00"),Preferences()))
        precondition(WorkSchedule.working(date("2026-10-10T10:00:00+08:00"),Preferences()))
        precondition(parseISODate("2026-10-17T03:30:00.000Z") != nil)
        precondition(CalendarData.nextTerm(date("2026-10-17T08:00:00+08:00"))=="霜降 · 10月23日")
        let white=NSImage(size:NSSize(width:800,height:480),flipped:true){rect in NSColor.white.setFill();rect.fill();return true}
        let bytes=try! ScreenRenderer.bitmap(white);precondition(bytes.count==48000&&bytes.allSatisfy{$0==255})
        let half=NSImage(size:NSSize(width:800,height:480),flipped:true){rect in NSColor.white.setFill();rect.fill();NSColor.black.setFill();NSRect(x:0,y:0,width:800,height:240).fill();return true}
        let split=try! ScreenRenderer.bitmap(half);precondition(split.prefix(24000).allSatisfy{$0==0}&&split.suffix(24000).allSatisfy{$0==255})
        let route:[String:Any]=["status":"1","route":["paths":[["distance":"5000","cost":["duration":"661"],"steps":[["road_name":"测试道路","tmcs":[["tmc_status":"缓行","tmc_distance":"500"],["tmc_status":"畅通","tmc_distance":"4500"]]]]]]]]
        let parsed=try! Remote.parseCommute(route)
        precondition(parsed.minutes==12 && parsed.distanceKM==5)
        precondition(parsed.trafficSummary!.contains("缓行约0.5公里") && parsed.trafficSummary!.contains("测试道路"))
        let noTraffic=try! Remote.parseCommute(["status":"1","route":["paths":[["cost":["duration":120]]]]])
        precondition(noTraffic.minutes==2 && noTraffic.trafficSummary!.contains("不能仅凭耗时判断"))
        do{_ = try Remote.parseCommute(["status":"0","infocode":"10009"]);preconditionFailure("Invalid key platform accepted")}catch{precondition(error.localizedDescription.contains("10009"))}
        do{_ = try Remote.parseCommute(["status":"1","route":["paths":[["cost":["duration":"-1"]]]]]);preconditionFailure("Negative duration accepted")}catch{}
        let monday=date("2026-10-19T08:40:00+08:00"),routeNow=CommuteSnapshot(minutes:12,fetched:date("2026-10-19T08:39:00+08:00"))
        precondition(!AgentRules.shouldCheck(monday,Preferences(),enabled:false))
        precondition(AgentRules.shouldCheck(monday,Preferences(),enabled:true))
        precondition(AgentRules.actionable(monday,Preferences(),routeNow))
        precondition(!AgentRules.actionable(monday,Preferences(),CommuteSnapshot(minutes:12,fetched:date("2026-10-19T08:00:00+08:00"))))
        precondition(!AgentRules.shouldCheck(date("2026-10-18T08:40:00+08:00"),Preferences(),enabled:true))
        var night=Preferences();night.startMinute=60;night.endMinute=9*60
        precondition(AgentRules.shouldCheck(date("2026-10-18T23:00:00+08:00"),night,enabled:true))
        precondition(AgentRules.key(date("2026-10-18T23:00:00+08:00"),night)=="commute-2026-10-19")
        let testDirectory=FileManager.default.temporaryDirectory.appendingPathComponent("mojian-self-test-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:testDirectory)}
        let store=DeskStore(dataDirectory:testDirectory,startServices:false)
        _=store.propose("add_task",["title":"隔离测试任务"],"添加隔离测试任务")
        precondition(store.tasks.isEmpty && store.proposals.count==1)
        store.dismissProposal(store.proposals[0].id);precondition(store.tasks.isEmpty)
        _=store.propose("remember_preference",["text":"测试偏好"],"测试记忆")
        store.approveProposal(store.proposals[0].id)
        store.setCommuteAgent(true)
        let restored=DeskStore(dataDirectory:testDirectory,startServices:false)
        precondition(restored.agent.commuteEnabled && restored.agent.memories.first?.text=="测试偏好")
        precondition(restored.tasks.isEmpty)
        print("PASS: schedule boundaries, weekends, overnight shifts, next boundary, bitmap packing and orientation; Amap TMC parsing, missing traffic, invalid duration and API errors")
    }
}
