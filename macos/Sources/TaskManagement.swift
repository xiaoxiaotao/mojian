import Foundation

struct TaskCompletionUndo {
    var taskID:String;var completedAt:Date
}
struct DueReminder:Equatable {
    var key:String;var title:String;var body:String
}
enum TaskReminderRules {
    static func candidate(_ task:DeskTask,at now:Date)->DueReminder? {
        guard !task.done,let due=task.due else{return nil}
        let delta=due.timeIntervalSince(now)
        let base="task-"+task.id+"-"+String(Int(due.timeIntervalSince1970))
        if delta>0 && delta<=600{return DueReminder(key:base+"-soon",title:"一件事快到时间了",body:task.title)}
        if delta<=0 && delta >= -86400{return DueReminder(key:base+"-due",title:delta >= -60 ? "一件事已到时间":"还有一件事待处理",body:task.title+" · "+dateText(due,"MM/dd HH:mm"))}
        return nil
    }
}

import UserNotifications
struct NotificationDelivery {
    var add:(UNNotificationRequest,@escaping(Error?)->Void)->Void = {UNUserNotificationCenter.current().add($0,withCompletionHandler:$1)}
    var remove:([String])->Void = {ids in
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers:ids)
    }
}
