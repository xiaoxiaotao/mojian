import SwiftUI
struct BulkCapture {
 static func plan(_ raw:String,existing:[String])throws->[String] {
  guard raw.utf16.count<=4096 else{throw DeskError(message:"一次最多粘贴4096个字符，请分批整理。")}
  var seen=Set(existing.map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}),result:[String]=[]
  for line in raw.components(separatedBy:.newlines){var title=line.trimmingCharacters(in:.whitespacesAndNewlines);if title.hasPrefix("- ") || title.hasPrefix("• "){title=String(title.dropFirst(2)).trimmingCharacters(in:.whitespaces)};if title.isEmpty{continue};guard title.utf16.count<=80 else{throw DeskError(message:"每条最多80个字符，请先编辑过长的行。")};if seen.insert(title).inserted{result.append(title)}}
  guard !result.isEmpty else{throw DeskError(message:"没有新事项：请填写文字，或检查是否已在清单中。")}
  guard existing.count+result.count<=8 else{throw DeskError(message:"未完成最多8项，当前还能添加\(max(0,8-existing.count))项；本次未写入。")}
  return result
 }
}
extension DeskStore {
 @discardableResult func capture(_ raw:String)->Bool {
  do{let titles=try BulkCapture.plan(raw,existing:active.map{$0.title});let updated=tasks+titles.map{DeskTask(title:$0)};tasks=updated;changed();return true}catch{status=error.localizedDescription;return false}
 }
}
struct BulkCaptureView:View {
 @EnvironmentObject var store:DeskStore
 @Environment(\.dismiss) private var dismiss
 @SwiftUI.State private var raw=""
 @SwiftUI.State private var error=""
 var body:some View {
  VStack(alignment:.leading,spacing:16){
   Text("把零散的事，一次收进来。").font(.title2.bold())
   Text("每行一件事，空行和重复内容会忽略；不会自动识别时间或调用模型。最多8项未完成，每条80个字符。").font(.callout).foregroundStyle(muted)
   TextEditor(text:$raw).font(.body).frame(minHeight:160).padding(8).overlay(RoundedRectangle(cornerRadius:8).stroke(muted.opacity(0.2)))
   Button("从剪贴板粘贴"){if let text=NSPasteboard.general.string(forType:.string){if text.utf16.count<=4096{raw=text;error=""}else{error="剪贴板文字超过4096个字符，请分批粘贴。"}}}.buttonStyle(Quiet())
   ScrollView{VStack(alignment:.leading,spacing:8){if let titles=try? BulkCapture.plan(raw,existing:store.active.map{$0.title}){Text("将新增 \(titles.count) 项").font(.headline);ForEach(Array(titles.enumerated()),id:\.offset){_,title in Text("• "+title)}}else{Text(hint).foregroundStyle(muted)}}}.frame(maxHeight:180)
   if !error.isEmpty{Text(error).foregroundStyle(.orange)}
   Text("确认前不写入，取消即放弃本次输入。确认后保存在Mac，并按现有同步设置局部同步；日期可在事项中另行设置。").font(.caption).foregroundStyle(muted)
   HStack{Button("取消"){dismiss()}.buttonStyle(Quiet());Spacer();Button("确认加入待办"){if store.capture(raw){dismiss()}else{error=store.status}}.buttonStyle(Primary()).disabled((try? BulkCapture.plan(raw,existing:store.active.map{$0.title}))==nil)}
  }.padding(26).frame(width:620)
 }
 var hint:String {do{_=try BulkCapture.plan(raw,existing:store.active.map{$0.title});return ""}catch{return error.localizedDescription}}
}
