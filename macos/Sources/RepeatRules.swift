import Foundation
import CryptoKit

enum RepeatRule:String,Codable,CaseIterable {case none,daily,weekdays,weekly,monthly
    var title:String{switch self{case .none:"不重复";case .daily:"每天";case .weekdays:"周一至周五";case .weekly:"每周";case .monthly:"每月"}}
}
enum RepeatRules {
    static func configured(_ task:DeskTask,_ rule:RepeatRule)throws->DeskTask{var t=task;if rule == .none{t.repeatRule=nil;t.repeatSeries=nil;t.repeatDay=nil;return t};guard let due=t.due else{throw DeskError(message:"重复事项需要设置截止时间")};if t.repeatRule != rule.rawValue{t.repeatDay=WorkSchedule.calendar.component(.day,from:due)};t.repeatRule=rule.rawValue;t.repeatSeries=t.repeatSeries ?? t.id;t.repeatDay=t.repeatDay ?? WorkSchedule.calendar.component(.day,from:due);return t}
    static func next(_ task:DeskTask,at now:Date)throws->DeskTask?{guard let key=task.repeatRule,key != "none" else{return nil};guard let rule=RepeatRule(rawValue:key),let due=task.due else{throw DeskError(message:"重复规则或截止时间无效")};let cal=WorkSchedule.calendar,anchor=task.repeatDay ?? cal.component(.day,from:due);guard (1...31).contains(anchor) else{throw DeskError(message:"重复日期无效")};var next=due,steps=0
        repeat{steps+=1;guard steps<=100000 else{throw DeskError(message:"重复跨度过大，请修改截止时间")};switch rule{case .monthly:let month=cal.date(byAdding:.month,value:1,to:cal.date(from:cal.dateComponents([.year,.month],from:next))!)!;let day=min(anchor,cal.range(of:.day,in:.month,for:month)!.count);var c=cal.dateComponents([.year,.month],from:month);let time=cal.dateComponents([.hour,.minute,.second],from:due);c.day=day;c.hour=time.hour;c.minute=time.minute;c.second=time.second;next=cal.date(from:c)!
        case .weekly:next=cal.date(byAdding:.day,value:7,to:next)!
        default:next=cal.date(byAdding:.day,value:1,to:next)!;if rule == .weekdays{while [1,7].contains(cal.component(.weekday,from:next)){next=cal.date(byAdding:.day,value:1,to:next)!}}}
        }while next<=now
        var t=task;t.id=(t.repeatSeries ?? t.id)+":"+dateText(next,"yyyy-MM-dd");t.repeatSeries=t.repeatSeries ?? task.id;t.repeatDay=anchor;t.due=next;t.done=false;t.completedAt=nil;t.nextID=nil;t.nextKey=nil;t.skipped=nil;return t
    }
    static func fingerprint(_ t:DeskTask)->String{let values=[t.id,t.title,t.due.map{String(Int64($0.timeIntervalSince1970))} ?? "",t.repeatRule ?? "",t.repeatSeries ?? "",String(t.repeatDay ?? 0),t.pinned==true ? "1":"0"];let source=values.map{String($0.utf8.count)+":"+$0}.joined();return SHA256.hash(data:Data(source.utf8)).map{String(format:"%02x",$0)}.joined()}
}
