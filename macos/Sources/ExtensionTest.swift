import Foundation
@MainActor enum ExtensionTest {
    static func run()throws {
        let healthNow=Date(timeIntervalSince1970:1_800_000_000)
        precondition(DataHealth.freshness(nil,now:healthNow,ttl:900)=="尚无数据")
        precondition(DataHealth.freshness(healthNow.addingTimeInterval(-900),now:healthNow,ttl:900)=="缓存已过期")
        precondition(DataHealth.freshness(healthNow,now:healthNow,ttl:3600,failed:true)=="更新失败 · 使用上次缓存")
        precondition(DataHealth.freshness(healthNow.addingTimeInterval(301),now:healthNow,ttl:900).contains("时间异常"))
        precondition(DataHealth.connection("http://fixture",healthNow.addingTimeInterval(-21),now:healthNow)=="连接待确认")
        precondition(DataHealth.connection("http://fixture",nil,now:healthNow).contains("尚未确认"))
        do {
            let f=ISO8601DateFormatter();let n=f.date(from:"2026-01-31T15:59:00Z")!
            let samples=[DeskTask(id:"late",title:"逾期",due:n.addingTimeInterval(-1)),DeskTask(id:"today",title:"今天",due:n),DeskTask(id:"tomorrow",title:"明天",due:f.date(from:"2026-01-31T16:00:00Z")),DeskTask(id:"later",title:"以后",due:f.date(from:"2026-02-01T16:00:00Z")),DeskTask(id:"free",title:"未定"),DeskTask(id:"done",title:"完成",done:true,completedAt:n),DeskTask(id:"skip",title:"跳过",done:true,completedAt:n,skipped:true),DeskTask(id:"future",title:"未来记录",done:true,completedAt:n.addingTimeInterval(1))]
            let snapshot=DailyReview(tasks:samples,now:n)
            precondition(snapshot.overdue.map{$0.id}==["late"] && snapshot.today.map{$0.id}==["today"])
            precondition(snapshot.tomorrow.map{$0.id}==["tomorrow"] && snapshot.later.map{$0.id}==["later"])
            precondition(snapshot.unscheduled.map{$0.id}==["free"] && snapshot.completed.map{$0.id}==["done"])
            precondition(!snapshot.text(at:n).contains("跳过") && !snapshot.text(at:n).contains("未来记录"))
            precondition(DailyReview(tasks:samples+[samples[0]],now:n).overdue.count==1)
        }
        let capturePlan=try BulkCapture.plan(" - 买牛奶\n\n• 交周报\n买牛奶",existing:["交周报"]);precondition(capturePlan==["买牛奶"])
        do{_=try BulkCapture.plan(String(repeating:"字",count:81),existing:[]);preconditionFailure("Long capture accepted")}catch{}
        do{_=try BulkCapture.plan("新事项",existing:Array(repeating:"existing",count:8));preconditionFailure("Overflow capture accepted")}catch{}
        let plainPlan=try BulkCapture.plan("明天交报告",existing:[]);precondition(plainPlan==["明天交报告"],"No inferred date")
        let deadlineNow=ISO8601DateFormatter().date(from:"2026-12-31T15:59:00Z")!
        precondition(DeadlineChoices.hourAfter(deadlineNow).timeIntervalSince(deadlineNow)==3600)
        precondition(ISO8601DateFormatter().string(from:DeadlineChoices.tomorrowMorning(deadlineNow))=="2027-01-01T01:00:00Z")
        do {
            let n=Date(timeIntervalSince1970:1800000000)
            let samples=[DeskTask(id:"a",title:"Report旧",done:true,completedAt:n),DeskTask(id:"a",title:"Report新",done:true,completedAt:n.addingTimeInterval(1),skipped:true),DeskTask(id:"b",title:"买牛奶",done:true,completedAt:n),DeskTask(id:"c",title:"已恢复"),DeskTask(id:"c",title:"旧完成",done:true,completedAt:n)]
            let before=samples
            precondition(HistorySearch.records(samples,query:" report ",kind:"all").map{$0.title}==["Report新"])
            precondition(HistorySearch.records(samples,query:"",kind:"completed").map{$0.id}==["b"])
            precondition(HistorySearch.records(samples,query:"",kind:"skipped").map{$0.id}==["a"])
            precondition(HistorySearch.records(samples,query:"不存在",kind:"all").isEmpty && samples==before)
        }
        let base=[DeskTask(id:"base",title:"原任务")]
        let local=base+[DeskTask(id:"mac",title:"Mac新增")]
        let remote=base+[DeskTask(id:"phone",title:"手机新增")]
        let merged=try TaskReconcile.merge(base:base,local:local,remote:remote)
        precondition(Set(merged.map{$0.id})==Set(["base","mac","phone"]))
        let deleted=try TaskReconcile.merge(base:base,local:[],remote:base)
        precondition(deleted.isEmpty,"Deletion never resurrects")
        var edited=base;edited[0].title="本地改名";var other=base;other[0].title="远端改名"
        do{_=try TaskReconcile.merge(base:base,local:edited,remote:other);preconditionFailure("Expected conflicting edit") }catch{}
        var prefs=Preferences();prefs.layout = .overview;prefs.homeAddress="PRIVATE";prefs.deviceURL="http://private.invalid";prefs.info.habits=[DeskHabit(title:"阅读")]
        prefs.note="我的原有小纸条";prefs.info.weeklyGoal=35;prefs.info.deskStatus="开会中";prefs.info.statusNote="请留言"
        precondition(DeskPreset.all.count==6 && Set(DeskPreset.all.map{$0.id}).count==6)
        for preset in DeskPreset.all {
            let (applied,calendar)=try DeskExtensions.apply(preset.template,to:prefs)
            precondition(applied.note==prefs.note && applied.info.weeklyGoal==35 && applied.info.deskStatus=="开会中" && applied.info.statusNote=="请留言")
            precondition(applied.deviceURL==prefs.deviceURL && applied.homeAddress==prefs.homeAddress && applied.info.habits==prefs.info.habits)
            precondition(calendar==(preset.id=="after-work"))
            let settings=preset.template["settings"] as! [String:Any]
            precondition(Set(settings.keys)==Set(["layout","ratio","cardsVersion","card1","card2"]))
        }
        let template=try DeskExtensions.template(prefs,false,"fixture")
        let bytes=try JSONSerialization.data(withJSONObject:template)
        precondition(!String(decoding:bytes,as:UTF8.self).contains("PRIVATE") && !String(decoding:bytes,as:UTF8.self).contains("private.invalid"))
        let(restored,calendar)=try DeskExtensions.apply(template,to:prefs)
        precondition(restored.layout == .overview && !calendar && restored.homeAddress=="PRIVATE")
        do{_=try DeskExtensions.apply(["schema":"bad"],to:prefs);preconditionFailure("Invalid schema accepted")}catch{}
        do{_=try DeskExtensions.hubURL("http://public.example");preconditionFailure("HTTP remote accepted")}catch{}
        _=try DeskExtensions.hubURL("http://192.168.31.2:8788")
        precondition(!DeskExtensions.privateHost("192.168.attacker.example"))
        let plugin=try DataPlugin.parse(["schema":"mojian-card-v1","name":"fixture","kind":"daily","items":["先做好一件事"]])
        precondition(plugin.display(at:Date())=="先做好一件事")
        do{_=try DataPlugin.parse(["schema":"mojian-card-v1","name":"bad","kind":"script"]);preconditionFailure("Script accepted")}catch{}
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("mojian-extension-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:dir)}
        let store=DeskStore(dataDirectory:dir,startServices:false)
        let beforeCapture=store.tasks;precondition(!store.capture("有效行\n"+String(repeating:"长",count:81)) && store.tasks==beforeCapture,"Batch must fail atomically");precondition(store.capture("新事项甲\n新事项乙") && store.active.count==2);precondition(store.active.allSatisfy{$0.due==nil})
        store.extensions.addHabit("阅读");let id=store.settings.info.habits!.first!.id
        store.extensions.toggle(id);precondition(store.settings.info.habits!.first!.days.count==1)
        store.extensions.toggle(id);precondition(store.settings.info.habits!.first!.days.isEmpty)
        let time=Date().addingTimeInterval(-60);store.tasks=[DeskTask(id:"shared-task",title:"完成",done:true,completedAt:time)]
        let capture=try store.extensions.capture();let done=capture["completions"] as! [String:[String:Any]]
        precondition(done["shared-task"]?["deleted"] as? Bool==false)
        var shared=capture;shared["completions"]=["shared-task":["stamp":Int(Date().timeIntervalSince1970*1000),"completedAt":Int(time.timeIntervalSince1970*1000),"deleted":true]]
        store.extensions.data["shared"]=shared
        let replay=try store.extensions.capture()["completions"] as! [String:[String:Any]]
        precondition(replay["shared-task"]?["deleted"] as? Bool==true,"Stale local completion cannot resurrect remote undo")
        print("PASS: cross-client three-way merge/deletion/conflict, template privacy, transport policy, data plugins, habits and shared undo replay")
    }
}
