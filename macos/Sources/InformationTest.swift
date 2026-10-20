import Foundation

@MainActor enum InformationTest {
    static func run(){
        precondition(ScreenFonts.font("待办清单",19,false).fontName.contains("SourceHanSans"),"Bundled Chinese font")
        precondition(ScreenFonts.font("09:30",52,true).fontName.contains("Inter"),"Bundled numeric font")
        precondition(ScreenFonts.font("下班之后",26,false).fontName.contains("LXGW"),"Bundled calendar font")
        func date(_ value:String)->Date {ISO8601DateFormatter().date(from:value)!}
        let now=date("2026-10-17T18:00:00+08:00")
        let item=ImportantDate(title:"Example deadline",date:date("2026-10-19T00:00:00+08:00"))
        precondition(InformationLogic.countdown(item,at:now).contains("2 天"))
        precondition(InformationLogic.countdown(item,at:item.date).contains("今天"))
        precondition(InformationLogic.countdown(item,at:date("2026-10-20T00:01:00+08:00")).contains("已过 1 天"))
        var tasks=[DeskTask(title:"Earlier",due:now),DeskTask(title:"Pinned",due:nil,pinned:true)]
        precondition(InformationLogic.ordered(tasks).first?.title=="Pinned")
        tasks += [DeskTask(title:"This Monday",due:nil,done:true,completedAt:date("2026-10-12T00:00:00+08:00")),DeskTask(title:"Sunday before",due:nil,done:true,completedAt:date("2026-10-11T23:59:59+08:00")),DeskTask(title:"Future",due:nil,done:true,completedAt:date("2026-10-18T18:00:00+08:00"))]
        precondition(InformationLogic.weekCount(tasks,at:now)==1)
        let weather=WeatherSnapshot(temperature:22,code:2,days:[],fetched:now,hours:[HourForecast(time:now,rainProbability:80,apparent:21,wind:9)])
        precondition(InformationLogic.outdoor(weather,at:now).contains("80%"))
        precondition(InformationLogic.outdoor(weather,at:now).contains("带伞"))
        precondition(InformationLogic.outdoor(weather,at:now.addingTimeInterval(3601)).contains("过期"))
        precondition(InformationLogic.outdoor(nil,at:now).contains("不可用"))
        // Existing persisted files omit all new fields. They must still load without losing tasks/settings.
        let legacyTask=Data("{\"id\":\"old\",\"title\":\"Original\",\"done\":false}".utf8)
        precondition((try! JSONDecoder().decode(DeskTask.self,from:legacyTask)).pinned==nil)
        let encoded=try! JSONEncoder().encode(Preferences())
        var object=try! JSONSerialization.jsonObject(with:encoded) as! [String:Any];object.removeValue(forKey:"information")
        let restored=try! JSONDecoder().decode(Preferences.self,from:JSONSerialization.data(withJSONObject:object))
        precondition(restored.info.weeklyGoal==20)
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("mojian-information-test-"+UUID().uuidString)
        let store=DeskStore(dataDirectory:directory,startServices:false)
        defer{try? FileManager.default.removeItem(at:directory)}
        store.tasks=(0..<4).map{DeskTask(title:"Fixture \($0)",due:nil)}
        for task in store.tasks{store.pinTask(task.id)}
        precondition(store.active.filter{$0.pinned == true}.count==3)
        store.configureInformation{$0.dates=[item];$0.cards=["countdown","week"]}
        let loaded=DeskStore(dataDirectory:directory,startServices:false)
        precondition(loaded.settings.info.dates.count==1 && loaded.active.filter{$0.pinned == true}.count==3)
        let out=URL(fileURLWithPath:ProcessInfo.processInfo.arguments.last ?? "/tmp/mojian-information-preview",isDirectory:true)
        let output=out.lastPathComponent=="--information-test" ? URL(fileURLWithPath:"/tmp/mojian-information-preview"):out
        try! FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        var settings=Preferences();settings.info.dates=[item]
        let event=NextCalendarEvent(title:"示例：产品评审",start:now.addingTimeInterval(1800),end:now.addingTimeInterval(5400),location:"示例会议室",allDay:false)
        for layout in DeskLayout.allCases {
            settings.layout=layout
            settings.info.cards=["nextEvent","outdoor"]
            let content=ScreenContent(tasks:store.tasks,settings:settings,weather:weather,quotes:[],now:now,nextEvent:event)
            let bytes=try! ScreenRenderer.blackFrame(content)
            precondition(bytes.count==48000 && bytes[8000..<10400].allSatisfy{$0==255})
            try! ScreenRenderer.savePNG(ScreenRenderer.render(content),to:output.appendingPathComponent(layout.rawValue+".png"))
        }
        precondition(InformationLogic.plantStage(0,20)==0 && InformationLogic.plantStage(4,20)==1 && InformationLogic.plantStage(30,20)==5)
        for key in ["plant","status"]{settings.layout = .overview;settings.info.cards=[key,"week"];let bytes=try! ScreenRenderer.blackFrame(ScreenContent(tasks:tasks,settings:settings,weather:weather,quotes:[],now:now));precondition(bytes[8000..<10400].allSatisfy{$0==255});try! ScreenRenderer.savePNG(ScreenRenderer.render(ScreenContent(tasks:tasks,settings:settings,weather:weather,quotes:[],now:now)),to:output.appendingPathComponent(key+".png"))}
        settings.info.artwork=true
        try! ScreenRenderer.savePNG(ScreenRenderer.render(ScreenContent(tasks:tasks,settings:settings,weather:weather,quotes:[],now:now,afterHours:true)),to:output.appendingPathComponent("life-artwork.png"))
        settings.layout = .agenda;settings.info.cards=["countdown","week"]
        try! ScreenRenderer.savePNG(ScreenRenderer.render(ScreenContent(tasks:tasks,settings:settings,weather:weather,quotes:[],now:now)),to:output.appendingPathComponent("countdown-week.png"))
        print("PASS: legacy persistence, pinned top-three, week boundary, countdown dates, weather freshness, settings restore, all layout BW reserve bands; illustrative previews exported")
    }
}
