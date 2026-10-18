import Foundation
@MainActor enum ExtensionTest {
    static func run()throws {
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
