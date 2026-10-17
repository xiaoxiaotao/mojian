import SwiftUI

struct AgentPanel:View {
    @EnvironmentObject var store:DeskStore
    var body:some View {
        Card{VStack(alignment:.leading,spacing:14){
            Label("主动助理",systemImage:"sparkles").font(.system(size:15,weight:.semibold))
            Text(store.agentStatus).font(.system(size:11)).foregroundStyle(muted)
            Toggle("上班前主动提醒",isOn:Binding(get:{store.agent.commuteEnabled},set:{store.setCommuteAgent($0)})).font(.system(size:12))
            Text("上班前3小时内每5分钟检查；进入建议出发时间才生成提醒，每天一次。Mac需保持运行。").font(.system(size:11)).foregroundStyle(muted)
            Text(store.settings.notifications ? "Mac通知已开启":"提醒会保留在对话中；系统通知可在作息页开启。").font(.system(size:10)).foregroundStyle(muted)
            Button("检查现在的出行建议"){Task{await store.ask("请调用工具查询当前天气、通勤和作息，给我出行建议，不修改任务或偏好。")}}.buttonStyle(Quiet()).disabled(store.aiBusy)
            if store.aiBusy{Button("停止本次请求"){store.harness.close()}.buttonStyle(.plain).foregroundStyle(muted)}
            DisclosureGroup("记住的偏好 · \(store.agent.memories.count)条"){
                if store.agent.memories.isEmpty{Text("可以说：记住我喜欢简短的提醒。").font(.system(size:11)).foregroundStyle(muted)}
                ForEach(store.agent.memories){memory in Text(memory.text).font(.system(size:11)).padding(.vertical,4)}
            }.font(.system(size:11))
            DisclosureGroup("最近执行记录"){
                ForEach(store.agent.records.suffix(6).reversed()){item in Text(dateText(item.date,"HH:mm")+" · "+item.text).font(.system(size:10)).foregroundStyle(muted).padding(.vertical,3)}
            }.font(.system(size:11))
        }}
    }
}
struct AgentProposalsView:View {
    @EnvironmentObject var store:DeskStore
    var body:some View {
        if !store.proposals.isEmpty {
            VStack(alignment:.leading,spacing:10){
                Label("待确认操作",systemImage:"hand.raised").font(.system(size:13,weight:.semibold))
                ForEach(store.proposals){proposal in
                    VStack(alignment:.leading,spacing:8){Text(proposal.summary).font(.system(size:12));HStack{Button("确认执行"){store.approveProposal(proposal.id)}.buttonStyle(Quiet()).disabled(store.aiBusy);Button("取消"){store.dismissProposal(proposal.id)}.buttonStyle(.plain).foregroundStyle(muted)}}.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(sage.opacity(0.06),in:RoundedRectangle(cornerRadius:10))
                }
            }
        }
    }
}
