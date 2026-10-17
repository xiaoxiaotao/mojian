import Foundation
import UserNotifications

@MainActor enum TaskManagementTest {
    static func run()async {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("mojian-task-test-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:directory)}
        var deliveries:[String]=[],removed:[String]=[]
        var callbacks:[(Error?)->Void]=[]
        let delivery=NotificationDelivery(add:{r,done in deliveries.append(r.identifier);callbacks.append(done)},remove:{removed.append(contentsOf:$0)})
        let store=DeskStore(dataDirectory:directory,startServices:false,notificationDelivery:delivery)
        let now=Date(),id=UUID().uuidString
        store.tasks=[DeskTask(id:id,title:"Original",due:now.addingTimeInterval(300),pinned:true)]
        precondition(store.updateTask(id,title:"  Edited  ",due:nil))
        precondition(store.tasks[0].title=="Edited" && store.tasks[0].id==id && store.tasks[0].due==nil && store.tasks[0].pinned==true)
        precondition(!store.updateTask(id,title:"  ",due:now))
        precondition(!store.updateTask(id,title:String(repeating:"字",count:81),due:now))
        store.complete(id);precondition(store.active.isEmpty && store.completionUndo?.taskID==id && store.doneToday==1)
        precondition(!store.updateTask(id,title:"Cannot edit completed",due:nil))
        store.undoCompletion();precondition(store.active.count==1 && store.doneToday==0 && store.completionUndo==nil)
        // Restoring a completed task must not overflow the screen's eight-task limit.
        store.complete(id)
        store.tasks += (0..<8).map{DeskTask(title:"Fixture \($0)",due:nil)}
        store.undoCompletion();precondition(store.active.count==8 && store.tasks.first?.done==true)
        let fresh=DeskStore(dataDirectory:directory,startServices:false,notificationDelivery:delivery)
        precondition(fresh.tasks.count==9 && fresh.tasks.first?.title=="Edited")
        let task=DeskTask(id:UUID().uuidString,title:"Reminder fixture",due:now.addingTimeInterval(300))
        let soon=TaskReminderRules.candidate(task,at:now)!
        precondition(soon.key.hasSuffix("soon"))
        let overdue=TaskReminderRules.candidate(task,at:now.addingTimeInterval(3600))!
        precondition(overdue.key.hasSuffix("due") && overdue.key != soon.key)
        precondition(TaskReminderRules.candidate(task,at:now.addingTimeInterval(90000))==nil)
        var done=task;done.done=true;precondition(TaskReminderRules.candidate(done,at:now)==nil)
        var moved=task;moved.due=now.addingTimeInterval(600)
        precondition(TaskReminderRules.candidate(moved,at:now)!.key != soon.key)
        store.settings.notifications=true
        store.notify(soon.title,soon.body,soon.key);store.notify(soon.title,soon.body,soon.key)
        precondition(deliveries.count==1,"In-flight requests must dedupe")
        callbacks.removeFirst()(nil)
        try? await Task.sleep(nanoseconds:10_000_000)
        let reopened=DeskStore(dataDirectory:directory,startServices:false,notificationDelivery:delivery)
        reopened.settings.notifications=true;reopened.notify(soon.title,soon.body,soon.key)
        precondition(deliveries.count==1,"Delivered reminders must dedupe after restart")
        reopened.notify(overdue.title,overdue.body,overdue.key)
        precondition(deliveries.count==2,"Due catch-up is independent from pre-due reminder")
        callbacks.removeFirst()(DeskError(message:"Fixture failure"))
        try? await Task.sleep(nanoseconds:10_000_000)
        reopened.notify(overdue.title,overdue.body,overdue.key)
        precondition(deliveries.count==3,"Failed enqueue must remain retryable")
        callbacks.removeFirst()(nil)
        try? await Task.sleep(nanoseconds:10_000_000)
        print("PASS: edit validation and persistence, completion undo, eight-task restore cap, pre-due/overdue catch-up, deadline-specific keys, restart dedupe, enqueue failure retry; no system notifications sent")
    }
}
