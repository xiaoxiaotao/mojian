import SwiftUI
struct ExtensionsView:View {
    @EnvironmentObject var store:DeskStore
    var body:some View{ExtensionsPanel(extra:store.extensions).environmentObject(store)}
}
struct ExtensionsPanel:View {
    @EnvironmentObject var store:DeskStore
    @ObservedObject var extra:DeskExtensions
    @SwiftUI.State private var habit=""
    @SwiftUI.State private var name=""
    @SwiftUI.State private var url=""
    @SwiftUI.State private var key=""
    @SwiftUI.State private var sender=""
    @SwiftUI.State private var message=""
    var body:some View {
        VStack(alignment:.leading,spacing:22){
            SectionIntro(eyebrow:"A LITTLE EVERY DAY",title:"让桌面，多一点陪伴。",subtitle:"小习惯、场景收藏和可选的共享服务。屏幕仍然以待办为主。")
            habits
            templates
            hub
        }.onAppear{url=extra.data["hubURL"] as? String ?? ""}
    }
    var habits:some View {
        Card {
            VStack(alignment:.leading,spacing:12){
                Text("每天三个小习惯").font(.headline)
                HStack {
                    TextField("例如：喝水、阅读、伸展",text:$habit).textFieldStyle(.roundedBorder)
                    Button("添加"){extra.addHabit(habit);habit=""}.buttonStyle(Quiet())
                }
                ForEach(store.settings.info.habits ?? []){h in
                    HStack {
                        Button(h.days.contains(dateText(store.now,"yyyy-MM-dd")) ? "✓":"○"){extra.toggle(h.id)}.buttonStyle(Quiet())
                        Text(h.title)
                        Spacer()
                        Button("移除"){extra.removeHabit(h.id)}.buttonStyle(.plain)
                    }
                }
                Button("显示习惯卡"){store.configureInformation{$0.cards=[$0.cards.first ?? "week","habits"]}}.buttonStyle(Quiet())
                Text("手动打卡，可撤销；北京时间每日重置。共享服务连接后可同步打卡记录。").font(.caption).foregroundStyle(muted)
            }
        }
    }
    var templates:some View {
        Card {
            VStack(alignment:.leading,spacing:12){
                Text("场景收藏与模板").font(.headline)
                HStack {
                    TextField("收藏名称",text:$name).textFieldStyle(.roundedBorder)
                    Button("收藏当前组合"){extra.favorite(name);name=""}.buttonStyle(Quiet())
                }
                HStack {
                    Button("导入模板文件"){extra.importTemplate()}
                    Button("导出当前组合"){extra.exportTemplate()}
                }.buttonStyle(Quiet())
                ForEach(Array(extra.favorites.enumerated()),id:\.offset){index,value in
                    HStack {
                        Text(value["name"] as? String ?? "收藏模板")
                        Spacer()
                        Button("预览并应用"){extra.preview(value)}
                        Button("导出"){extra.exportTemplate(value)}
                        Button("移出收藏"){extra.removeFavorite(index)}
                    }
                }
                Text("模板只包含视觉配置，不含任务、日历、地址和密钥。应用前预览，并明确全刷一次。").font(.caption).foregroundStyle(muted)
            }
        }
    }
    var hub:some View {
        Card {
            VStack(alignment:.leading,spacing:12){
                Text("可选共享服务").font(.headline)
                Text("自托管服务用于跨端完成记录、习惯和日期、模板库、数据插件与留言。公网连接使用 HTTPS；不依赖模型 Key。").font(.caption).foregroundStyle(muted)
                TextField("共享服务地址",text:$url).textFieldStyle(.roundedBorder)
                SecureField("服务凭据（留空保留）",text:$key).textFieldStyle(.roundedBorder)
                Button("保存连接"){extra.configureHub(url,key);key=""}.buttonStyle(Quiet())
                Toggle("自动共享记录（应用运行时每分钟）",isOn:Binding(get:{extra.data["autoSync"] as? Bool ?? false},set:{extra.setAutomatic($0)}))
                Text("开启后交换完成ID、习惯和重要日期；不上传地址、密钥或系统日历。").font(.caption).foregroundStyle(muted)
                hubActions
                Text(extra.status).font(.caption).foregroundStyle(muted)
                sharedItems
                Divider()
                TextField("留言署名",text:$sender).textFieldStyle(.roundedBorder)
                TextField("留言内容（最多100字）",text:$message).textFieldStyle(.roundedBorder)
                Button("发送至此服务收件箱"){Task{await extra.send(sender,message)}}.buttonStyle(Quiet())
            }
        }
    }
    var hubActions:some View {
        HStack {
            Button("同步记录"){Task{await extra.exchange()}}
            Button("读取模板"){Task{await extra.load("templates")}}
            Button("发布当前模板"){Task{await extra.publish()}}
            Button("读取插件"){Task{await extra.load("plugins")}}
            Button("读取留言"){Task{await extra.load("messages")}}
        }.buttonStyle(Quiet()).disabled(extra.busy)
    }
    var sharedItems:some View {
        VStack(alignment:.leading,spacing:12){
            ForEach(Array(extra.templates.enumerated()),id:\.offset){_,value in
                HStack {
                    Text(value["name"] as? String ?? "模板")
                    Spacer()
                    Button("预览并应用"){extra.preview(value)}
                }
            }
            ForEach(Array(extra.plugins.enumerated()),id:\.offset){_,value in
                HStack {
                    Text(value["name"] as? String ?? "数据插件")
                    Spacer()
                    Button("使用插件卡"){extra.usePlugin(value)}
                }
            }
            ForEach(Array(extra.messages.filter{$0["status"] as? String=="pending"}.enumerated()),id:\.offset){_,item in
                VStack(alignment:.leading){
                    Text((item["sender"] as? String ?? "留言")+"："+(item["text"] as? String ?? ""))
                    HStack {
                        Button("显示到小纸条"){Task{await extra.review(item,accept:true)}}
                        Button("忽略"){Task{await extra.review(item,accept:false)}}
                    }
                }
            }
        }
    }
}
