import SwiftUI
struct DailyReview {
 let completed:[DeskTask];let overdue:[DeskTask];let today:[DeskTask];let tomorrow:[DeskTask];let unscheduled:[DeskTask];let later:[DeskTask]
 init(tasks:[DeskTask],now:Date){
  let cal=WorkSchedule.calendar,start=cal.startOfDay(for:now),next=cal.date(byAdding:.day,value:1,to:start)!,end=cal.date(byAdding:.day,value:2,to:start)!
  var seen=Set<String>();let unique=tasks.filter{seen.insert($0.id).inserted}
  let active=unique.filter{!$0.done}.sorted{($0.due ?? .distantFuture,$0.id)<($1.due ?? .distantFuture,$1.id)}
  completed=unique.filter{$0.done && $0.skipped != true && $0.completedAt.map{$0>=start && $0<=now} == true}.sorted{($0.completedAt ?? .distantPast)>($1.completedAt ?? .distantPast)}
  overdue=active.filter{$0.due.map{$0<now} == true}
  today=active.filter{$0.due.map{$0>=now && $0<next} == true}
  tomorrow=active.filter{$0.due.map{$0>=next && $0<end} == true}
  unscheduled=active.filter{$0.due==nil};later=active.filter{$0.due.map{$0>=end} == true}
 }
 func text(at now:Date)->String {
  var lines=["每日收尾 · "+dateText(now,"yyyy-MM-dd HH:mm"),"按北京时间、本机保留记录整理；未更改任何事项。"]
  for (name,tasks) in [("今日完成记录",completed),("已逾期",overdue),("今天稍后",today),("明日到期",tomorrow),("未设截止",unscheduled),("更晚安排",later)]{lines.append("\n\(name) · \(tasks.count) 项");for t in tasks{lines.append("• "+t.title+(t.due.map{" · "+dateText($0,"MM/dd HH:mm")} ?? ""))}}
  return lines.joined(separator:"\n")
 }
}
struct DailyReviewView:View {
 @EnvironmentObject var store:DeskStore
 @Environment(\.dismiss) private var dismiss
 @SwiftUI.State private var copied=false
 var review:DailyReview{DailyReview(tasks:store.tasks,now:store.now)}
 var body:some View {
  VStack(alignment:.leading,spacing:18){
   HStack{Text("收好今天，给明天留一点从容。").font(.title2.bold());Spacer();Button("关闭"){dismiss()}}
   Text(dateText(store.now,"MM月dd日 EEEE HH:mm")+" · 北京时间 · 本机保留记录").font(.caption).foregroundStyle(muted)
   if store.syncPending{Text("有内容待同步，以下为本机记录，可能与屏幕不同。").font(.callout).foregroundStyle(.orange)}
   ScrollView{VStack(alignment:.leading,spacing:14){
    group("今日完成记录",review.completed,"今天还没有保留的完成记录。")
    group("已逾期",review.overdue,"没有逾期事项。")
    group("今天稍后",review.today,"今天没有其他截止事项。")
    group("明日到期",review.tomorrow,"明天没有已设截止事项。")
    group("未设截止",review.unscheduled,"每件事都有安排。")
    group("更晚安排",review.later,"暂无更晚的截止事项。")
   }}
   Text("只读整理，不会自动改期、完成、通知或切换屏幕。历史裁剪、删除或其他端未同步的记录可能不在此处。").font(.caption).foregroundStyle(muted)
   Button(copied ? "已复制到剪贴板":"复制本机收尾摘要"){NSPasteboard.general.clearContents();NSPasteboard.general.setString(review.text(at:store.now),forType:.string);copied=true}.buttonStyle(Quiet())
  }.padding(26).frame(minWidth:650,minHeight:650).frame(maxWidth:760,maxHeight:850)
 }
 func group(_ title:String,_ tasks:[DeskTask],_ empty:String)->some View {
  Card(padding:16) {
   VStack(alignment:.leading,spacing:9) {
    Text("\(title) · \(tasks.count) 项").font(.headline)
    if tasks.isEmpty {Text(empty).font(.callout).foregroundStyle(muted)}
    ForEach(tasks) { task in
     HStack(alignment:.top) {
      Text(task.title).textSelection(.enabled)
      Spacer()
      if let due=task.due {Text(dateText(due,"MM/dd HH:mm")).font(.caption).foregroundStyle(muted)}
     }
    }
   }
  }
 }
}
