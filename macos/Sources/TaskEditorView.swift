import SwiftUI

struct TaskEditorView:View {
    @EnvironmentObject var store:DeskStore
    @Environment(\.dismiss) private var dismiss
    let task:DeskTask
    @SwiftUI.State private var title:String
    @SwiftUI.State private var timed:Bool
    @SwiftUI.State private var due:Date
    @SwiftUI.State private var message=""
    @SwiftUI.State private var repeatRule:RepeatRule
    init(task:DeskTask){self.task=task;_repeatRule=State(initialValue:RepeatRule(rawValue:task.repeatRule ?? "none") ?? .none);_title=State(initialValue:task.title);_timed=State(initialValue:task.due != nil);_due=State(initialValue:task.due ?? Date().addingTimeInterval(3600))}
    var body:some View {
        VStack(alignment:.leading,spacing:22){Text("把这件事，安排妥当。").font(.system(size:23,weight:.semibold));TextField("待办内容",text:$title).textFieldStyle(.roundedBorder);HStack{Text("\(title.count) / 80 字").font(.system(size:11)).foregroundStyle(muted);Spacer();Toggle("设置截止时间",isOn:$timed)};if timed{DatePicker("截止时间",selection:$due,displayedComponents:[.date,.hourAndMinute])};Picker("重复方式",selection:$repeatRule){ForEach(RepeatRule.allCases,id:\.self){Text($0.title).tag($0)}};Text("保存后保留原有记录与置顶状态，并局部同步到屏幕。").font(.system(size:12)).foregroundStyle(muted);if !message.isEmpty{Text(message).foregroundStyle(.orange).font(.system(size:12))};HStack{Button("取消"){dismiss()}.keyboardShortcut(.cancelAction).buttonStyle(Quiet());Spacer();Button("保存修改"){if store.updateTask(task.id,title:title,due:timed ? due:nil,repeatRule:repeatRule){dismiss()}else{message=store.status}}.keyboardShortcut(.defaultAction).buttonStyle(Primary()).disabled(title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty||title.count>80)}}.padding(30).frame(width:470).background(canvasColor).foregroundStyle(ink)
    }
}
