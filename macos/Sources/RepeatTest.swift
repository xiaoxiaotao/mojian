import Foundation
@MainActor enum RepeatTest {
    static func run()throws {
        let f=ISO8601DateFormatter(),now=f.date(from:"2026-01-31T01:00:00Z")!
        let monthly=try RepeatRules.configured(DeskTask(id:"fixture-series",title:"交月报",due:now),.monthly)
        precondition(RepeatRules.fingerprint(monthly)=="a386114657f1982729854c5111e400a9d82eba537fde2b5272ba54755616d765","Cross-client fingerprint contract")
        let feb=try RepeatRules.next(monthly,at:now)!
        precondition(f.string(from:feb.due!)=="2026-02-28T01:00:00Z")
        let march=try RepeatRules.next(feb,at:feb.due!)!
        precondition(f.string(from:march.due!)=="2026-03-31T01:00:00Z","Month31 anchor retained")
        let leap=try RepeatRules.configured(DeskTask(title:"leap",due:f.date(from:"2028-01-31T01:00:00Z")!),.monthly)
        let leapNext=try RepeatRules.next(leap,at:leap.due!)!;precondition(f.string(from:leapNext.due!)=="2028-02-29T01:00:00Z")
        let weekdays=try RepeatRules.configured(DeskTask(title:"weekday",due:f.date(from:"2026-10-16T01:00:00Z")!),.weekdays)
        let workNext=try RepeatRules.next(weekdays,at:weekdays.due!)!;precondition(f.string(from:workNext.due!)=="2026-10-19T01:00:00Z")
        let daily=try RepeatRules.configured(DeskTask(id:"fixture-series",title:"daily",due:now),.daily)
        let next=try RepeatRules.next(daily,at:f.date(from:"2026-10-18T08:00:00Z")!)!
        precondition(f.string(from:next.due!)=="2026-10-19T01:00:00Z" && next.id=="fixture-series:2026-10-19")
        do{_=try RepeatRules.configured(DeskTask(title:"none"),.daily);preconditionFailure("Missing due accepted")}catch{}
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("mojian-repeat-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:directory)}
        let store=DeskStore(dataDirectory:directory,startServices:false)
        store.tasks=[feb];precondition(store.updateTask(feb.id,title:feb.title,due:feb.due!.addingTimeInterval(3600),repeatRule:.monthly));precondition(store.active[0].repeatDay==31,"Changing time preserves month-end anchor");store.tasks=[daily];store.complete(daily.id)
        precondition(store.active.count==1 && store.tasks.filter{$0.done}.count==1)
        let reloaded=DeskStore(dataDirectory:directory,startServices:false)
        precondition(reloaded.active.first?.repeatRule=="daily","Rules survive persistence")
        store.undoCompletion();precondition(store.active.count==1 && store.active.first?.id==daily.id)
        store.complete(daily.id,skip:true);precondition(store.active.count==1 && InformationLogic.weekCount(store.tasks,at:Date())==0,"Skipped occurrence not completion")
        let generated=store.active[0].id;store.tasks[store.tasks.firstIndex(where:{$0.id==generated})!].title="Changed elsewhere"
        store.undoCompletion();precondition(store.active.first?.id==generated && store.status.contains("无法"),"Undo never erases changed future occurrence")
        let city=Data(base64Encoded:AutonomyConfig.cityBitmap("苏州"))!;precondition(city.count==320);let preview=FileManager.default.temporaryDirectory.appendingPathComponent("mojian-test-previews");try? FileManager.default.createDirectory(at:preview,withIntermediateDirectories:true);try? city.write(to:preview.appendingPathComponent("city-bitmap.bin"))
        print("PASS: repeat month/leap/weekdays, catch-up, deterministic IDs, atomic complete/undo, skip statistics, persistence and autonomy city asset")
    }
}
