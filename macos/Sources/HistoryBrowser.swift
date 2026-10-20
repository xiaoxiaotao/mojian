import SwiftUI
struct HistorySearch {
 static func records(_ tasks:[DeskTask],query:String,kind:String)->[DeskTask] {
  let active=Set(tasks.filter{!$0.done}.map{$0.id}),needle=query.trimmingCharacters(in:.whitespacesAndNewlines)
  var seen=Set<String>()
  return tasks.filter{$0.done && !active.contains($0.id)}.sorted{($0.completedAt ?? .distantPast)>($1.completedAt ?? .distantPast)}.filter {task in
   guard seen.insert(task.id).inserted else{return false}
   return (kind=="all" || (task.skipped == true ? "skipped":"completed")==kind) && (needle.isEmpty || task.title.localizedCaseInsensitiveContains(needle))
  }
 }
}
struct HistoryBrowser:View {
 @EnvironmentObject var store:DeskStore
 @Environment(\.dismiss) private var dismiss
 @SwiftUI.State private var query=""
 @SwiftUI.State private var kind="all"
 @SwiftUI.State private var selected:DeskTask?
 @SwiftUI.State private var confirm=false
 @SwiftUI.State private var message=""
 var records:[DeskTask]{HistorySearch.records(store.tasks,query:query,kind:kind)}
 var body:some View {
  VStack(alignment:.leading,spacing:16){
   HStack{Text("找回以前的事项。").font(.title2.bold());Spacer();Button("关闭"){dismiss()}}
   TextField("搜索保留的事项文字",text:$query).textFieldStyle(.roundedBorder)
   Picker("记录类型",selection:$kind){Text("全部").tag("all");Text("已完成").tag("completed");Text("已跳过").tag("skipped")}.pickerStyle(.segmented)
   Text("找到 \(records.count) 项 · 仅本机保留记录").font(.caption).foregroundStyle(muted)
   ScrollView{LazyVStack(alignment:.leading,spacing:12){
    if records.isEmpty{Text("没有匹配记录，可清空关键词或切换类型。").foregroundStyle(muted).padding(.vertical,30)}
    ForEach(records){task in
     Card(padding:16){HStack(alignment:.top){VStack(alignment:.leading,spacing:7){Text(task.title).textSelection(.enabled);Text((task.skipped == true ? "已跳过":"已完成")+(task.completedAt.map{" · "+dateText($0,"MM/dd HH:mm")} ?? " · 时间未记录")).font(.caption).foregroundStyle(muted)};Spacer();Button("恢复"){selected=task;confirm=true}.buttonStyle(Quiet())}}
    }
   }}
   if !message.isEmpty{Text(message).font(.callout).foregroundStyle(muted)}
   Text("恢复前再次确认；保留原截止时间，可能仍逾期。重复事项须校验下一次未被修改；满8项时拒绝恢复。搜索不读取设备、不改统计或屏幕。").font(.caption).foregroundStyle(muted)
  }.padding(26).frame(width:650,height:650)
  .alert("恢复这条事项？",isPresented:$confirm){Button("取消",role:.cancel){};Button("恢复"){guard let selected,let latest=store.tasks.first(where:{$0.id==selected.id}),latest==selected else{message="记录已改变，请重新选择。";return};store.complete(selected.id);message=store.tasks.first(where:{$0.id==selected.id})?.done==false ? "已恢复到清单，沿用原同步设置。":store.status}}message:{Text("恢复到未完成清单，保留原截止时间。重复事项会按原规则核对下一次；不会为此切换布局或全刷。")}
 }
}
