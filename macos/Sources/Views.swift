import SwiftUI

let ink=Color(red:0.16,green:0.22,blue:0.19)
let sage=Color(red:0.27,green:0.39,blue:0.32)
let canvasColor=Color(red:0.965,green:0.961,blue:0.942)
let muted=Color(red:0.48,green:0.51,blue:0.47)
struct Card<Content:View>:View {
    var padding:CGFloat=22;@ViewBuilder var content:Content
    var body:some View {content.padding(padding).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(ink.opacity(0.055),lineWidth:1))}
}
struct Primary:ButtonStyle {func makeBody(configuration:Configuration)->some View {configuration.label.font(.system(size:13,weight:.semibold)).foregroundStyle(.white).padding(.horizontal,16).padding(.vertical,11).background(sage.opacity(configuration.isPressed ? 0.8:1),in:RoundedRectangle(cornerRadius:9))}}
struct Quiet:ButtonStyle {func makeBody(configuration:Configuration)->some View {configuration.label.font(.system(size:13,weight:.medium)).foregroundStyle(ink).padding(.horizontal,13).padding(.vertical,10).background(ink.opacity(configuration.isPressed ? 0.1:0.055),in:RoundedRectangle(cornerRadius:9))}}
struct Pill:View {var label:String;var symbol:String;var body:some View{Label(label,systemImage:symbol).font(.system(size:11,weight:.medium)).padding(.horizontal,11).padding(.vertical,7).foregroundStyle(sage).background(sage.opacity(0.09),in:Capsule())}}
struct ScreenPreview:View {var content:ScreenContent;var body:some View{Image(nsImage:ScreenRenderer.render(content)).resizable().aspectRatio(800/480,contentMode:.fit).padding(8).background(Color(red:0.89,green:0.88,blue:0.84),in:RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).stroke(ink.opacity(0.1)))}}
struct RootView:View {
    @EnvironmentObject var store:DeskStore
    @SwiftUI.State<Int> var page=0
    let pages=[("工作台","square.grid.2x2"),("布局空间","rectangle.3.group"),("作息与日历","sun.and.horizon"),("智能助理","sparkles"),("设备与设置","slider.horizontal.3"),("信息卡片","rectangle.grid.1x2")]
    var body:some View {
        HStack(spacing:0){
            VStack(alignment:.leading,spacing:0){
                HStack(spacing:10){Image(systemName:"rectangle.inset.filled.and.person.filled").font(.system(size:22)).foregroundStyle(.white).frame(width:42,height:42).background(sage,in:RoundedRectangle(cornerRadius:12));VStack(alignment:.leading,spacing:3){Text("墨间").font(.system(size:23,weight:.semibold));Text("A LITTLE SPACE FOR YOU").font(.system(size:7,weight:.medium)).tracking(1.3).foregroundStyle(muted)}}.padding(.horizontal,22).padding(.top,32)
                Text("让桌面，留一点从容。").font(.system(size:11)).foregroundStyle(muted).padding(.leading,24).padding(.top,16).padding(.bottom,38)
                ForEach(Array(pages.enumerated()),id:\.offset){i,p in Button{page=i}label:{HStack(spacing:12){Image(systemName:p.1).frame(width:20);Text(p.0);Spacer();if page==i{Circle().fill(sage).frame(width:5,height:5)}}.font(.system(size:13,weight:page==i ? .semibold:.regular)).padding(.horizontal,15).padding(.vertical,13).foregroundStyle(page==i ? sage:muted).background(page==i ? sage.opacity(0.1):.clear,in:RoundedRectangle(cornerRadius:9))}.buttonStyle(.plain).padding(.horizontal,12).padding(.bottom,5)}
                Spacer()
                VStack(alignment:.leading,spacing:10){HStack{Circle().fill(store.connected ? sage:Color.gray).frame(width:6,height:6);Text(store.connected ? "工作台已连接":"等待连接工作台").font(.system(size:11,weight:.medium))};Text(store.connected ? store.settings.deviceURL:"通过蓝牙，找到你的墨水屏").font(.system(size:10)).foregroundStyle(muted).lineLimit(1);Button{page=4}label:{Text("管理设备 →").font(.system(size:11))}.buttonStyle(.plain).foregroundStyle(sage)}.padding(15).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.7),in:RoundedRectangle(cornerRadius:12)).padding(16)
                Text("墨间 · 桌面信息工作台").font(.system(size:9)).foregroundStyle(muted.opacity(0.8)).padding(.horizontal,23).padding(.bottom,20)
            }.frame(width:220).background(Color(red:0.93,green:0.94,blue:0.91))
            VStack(spacing:0){
                HStack{Text(pages[page].0).font(.system(size:13,weight:.medium));Spacer();Pill(label:store.afterHours ? "下班模式":"工作模式",symbol:store.afterHours ? "moon":"sun.max");Button{Task{await store.switchMode()}}label:{Label(store.afterHours ? "开始工作":"下班了",systemImage:store.afterHours ? "sun.max":"moon")}.buttonStyle(Quiet()).disabled(store.isSending)}.padding(.horizontal,32).padding(.vertical,18).background(.white.opacity(0.55))
                ScrollView {VStack(alignment:.leading,spacing:24){switch page {case 0:DashboardView();case 1:LayoutView();case 2:ScheduleView();case 3:AssistantView();case 4:SettingsView();default:InformationView()}}.padding(32).frame(maxWidth:1180,alignment:.leading).frame(maxWidth:.infinity)}
                HStack(spacing:8){if store.isSending{ProgressView().controlSize(.mini)}else{Image(systemName:store.connected ? "checkmark.circle":"info.circle")};Text(store.storageError.isEmpty ? store.status:store.storageError).lineLimit(2);Spacer();if let sync=store.lastSync{Text("上次同步 "+dateText(sync,"HH:mm")).foregroundStyle(muted)}}.font(.system(size:11)).foregroundStyle(muted).padding(.horizontal,32).padding(.vertical,12).background(.white.opacity(0.6))
            }.frame(maxWidth:.infinity,maxHeight:.infinity).background(canvasColor)
        }.foregroundStyle(ink).frame(minWidth:1120,minHeight:760)
        .tint(sage).task{store.start()}
    }
}
struct SectionIntro:View {var eyebrow:String;var title:String;var subtitle:String
    var body:some View{VStack(alignment:.leading,spacing:10){Text(eyebrow).font(.system(size:10,weight:.semibold)).tracking(2).foregroundStyle(sage);Text(title).font(.system(size:29,weight:.semibold));Text(subtitle).font(.system(size:13)).foregroundStyle(muted)}}
}
struct DashboardView:View {
    @EnvironmentObject var store:DeskStore
    @SwiftUI.State<String> var title=""
    @SwiftUI.State<Bool> var hasDue=false
    @SwiftUI.State private var editingTask:DeskTask?
    @SwiftUI.State<Date> var due=Date().addingTimeInterval(3600)
    var body:some View {
        HStack(alignment:.bottom){SectionIntro(eyebrow:dateText(store.now,"MM月dd日 · EEEE"),title:store.afterHours ? "下班了，把时间还给自己。":"把今天，安排得刚刚好。",subtitle:store.afterHours ? "工作收起，生活展开。墨水屏现在显示万年历。":"重要的事留在眼前，其余的，慢慢来。");Spacer();Button{Task{await store.applyLayout()}}label:{Label("应用布局（全刷）",systemImage:"arrow.up.right.square")}.buttonStyle(Primary()).disabled(!store.connected||store.isSending)}
        HStack(spacing:16){metric("未完成",String(store.active.count),"checklist");metric("今天完成",String(store.doneToday),"checkmark.circle");metric(store.settings.city,store.weather.map{"\(Int($0.temperature.rounded()))° · \($0.text)"} ?? "等待天气","cloud.sun")}
        HStack(alignment:.top,spacing:22){
            Card{VStack(alignment:.leading,spacing:18){HStack{Text("今天要做的事").font(.system(size:18,weight:.semibold));Spacer();Text("完成即从屏幕移除").font(.system(size:10)).foregroundStyle(muted)}
                HStack{TextField("接下来，要完成什么？",text:$title).textFieldStyle(.plain).onSubmit(add);Button(action:add){Image(systemName:"plus")}.buttonStyle(Quiet())}.padding(11).background(canvasColor,in:RoundedRectangle(cornerRadius:9))
                HStack{Toggle("截止时间",isOn:$hasDue).toggleStyle(.checkbox).font(.system(size:11));if hasDue{DatePicker("",selection:$due,displayedComponents:[.date,.hourAndMinute]).labelsHidden().controlSize(.small)};Spacer()}
                if store.active.isEmpty{VStack(spacing:14){Image(systemName:"leaf").font(.system(size:32)).foregroundStyle(sage);Text("清单很轻，今天也可以很轻。").font(.system(size:13)).foregroundStyle(muted)}.frame(maxWidth:.infinity).padding(.vertical,54)}
                ForEach(store.active){task in HStack(alignment:.top,spacing:12){Button{store.complete(task.id)}label:{Image(systemName:"circle").font(.system(size:20)).foregroundStyle(sage.opacity(0.65))}.buttonStyle(.plain);VStack(alignment:.leading,spacing:7){Text(task.title).font(.system(size:14,weight:task.pinned == true ? .semibold:.medium));Text(dueText(task)).font(.system(size:10)).foregroundStyle(task.overdue ? Color(red:0.66,green:0.35,blue:0.26):muted)};Spacer();Button{editingTask=task}label:{Image(systemName:"pencil")}.buttonStyle(.plain).help("修改内容与截止时间");Button{store.pinTask(task.id)}label:{Image(systemName:task.pinned == true ? "pin.fill":"pin").foregroundStyle(task.pinned == true ? sage:muted)}.buttonStyle(.plain).help(task.pinned == true ? "取消置顶":"置顶到今日重要事项，最多三项");if task.overdue{Text("逾期").font(.system(size:9)).padding(5).background(Color.orange.opacity(0.09),in:Capsule())}}.padding(.vertical,7);Divider().opacity(0.45)}
                if let undo=store.completionUndo,let completed=store.tasks.first(where:{$0.id==undo.taskID && $0.done}){HStack{Label("已完成："+completed.title,systemImage:"checkmark.circle").lineLimit(1);Spacer();Button("撤销完成"){store.undoCompletion()}.buttonStyle(.plain).foregroundStyle(sage)}.font(.system(size:12)).padding(12).background(sage.opacity(0.07),in:RoundedRectangle(cornerRadius:9))}
                if store.tasks.contains(where:{$0.done}){DisclosureGroup("已完成记录"){ForEach(store.tasks.filter{$0.done}){task in HStack{Text(task.title).foregroundStyle(muted);Spacer();Button("恢复"){store.complete(task.id)}.buttonStyle(.plain).foregroundStyle(sage)}.font(.system(size:11)).padding(.vertical,5)}}.font(.system(size:11)).foregroundStyle(muted)}
            }}
            VStack(spacing:18){Card(padding:18){VStack(alignment:.leading,spacing:16){HStack{Text("桌面此刻").font(.system(size:14,weight:.semibold));Spacer();Text(store.afterHours ? "万年历":store.settings.layout.title).font(.system(size:10)).foregroundStyle(muted)};ScreenPreview(content:store.content);Text(store.syncStatus).font(.system(size:11,weight:.medium)).foregroundStyle(store.syncPending ? .orange:sage);if store.syncPending && !store.isSending{Button("重试同步"){Task{if !store.connected{await store.connectDevice()};await store.send(full:false)}}.buttonStyle(Quiet())};HStack{Image(systemName:"display");Text("800 × 480 · 黑白局部更新")}.font(.system(size:10)).foregroundStyle(muted);Text("应用布局或切换模式需全刷一次；日常内容变化只局刷。").font(.system(size:10)).foregroundStyle(muted)}}
                Card{VStack(alignment:.leading,spacing:13){Label("桌面小纸条",systemImage:"note.text").font(.system(size:13,weight:.medium));TextField("留一句话给自己",text:$store.settings.note,axis:.vertical).font(.system(size:16)).textFieldStyle(.plain).lineLimit(3...4);Button("同步小纸条"){store.changed()}.buttonStyle(.plain).font(.system(size:11,weight:.medium)).foregroundStyle(sage)}}
                HStack{Image(systemName:"sparkles").foregroundStyle(sage);Text(store.brief.isEmpty ? "去智能助理，生成一份今日简报。":store.brief).font(.system(size:11)).foregroundStyle(muted).lineLimit(3)}.padding(.horizontal,8)
            }.frame(width:350)
        }
        .sheet(item:$editingTask){task in TaskEditorView(task:task).environmentObject(store)}
    }
    func add(){guard !title.trimmingCharacters(in:.whitespaces).isEmpty else{return};if store.addTask(title,due:hasDue ? due:nil){title=""}}
    func metric(_ title:String,_ value:String,_ icon:String)->some View{Card(padding:18){HStack{VStack(alignment:.leading,spacing:9){Text(title).font(.system(size:11)).foregroundStyle(muted);Text(value).font(.system(size:25,weight:.medium))};Spacer();Image(systemName:icon).font(.system(size:22,weight:.light)).foregroundStyle(sage.opacity(0.65))}}}
}
struct LayoutView:View {
    @EnvironmentObject var store:DeskStore
    var body:some View {
        SectionIntro(eyebrow:"MAKE IT YOURS",title:"同一张桌面，七种心情。",subtitle:"六套预设与一套自定义。待办是主角，行情只占一小条。")
        LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:18),count:3),spacing:20){ForEach(DeskLayout.allCases){layout in
            Button{store.settings.layout=layout}label:{VStack(alignment:.leading,spacing:14){ScreenPreview(content:preview(layout));HStack{Image(systemName:layout.symbol).foregroundStyle(sage);Text(layout.title).font(.system(size:14,weight:.semibold));Spacer();if store.settings.layout==layout{Image(systemName:"checkmark.circle.fill").foregroundStyle(sage)}};Text(layout.subtitle).font(.system(size:10)).foregroundStyle(muted).lineLimit(1)}.padding(14).background(.white,in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(store.settings.layout==layout ? sage:ink.opacity(0.07),lineWidth:store.settings.layout==layout ? 2:1))}.buttonStyle(.plain)
        }}
        if store.settings.layout == .custom {Card{VStack(alignment:.leading,spacing:18){Text("让布局，顺着你的习惯。").font(.system(size:18,weight:.semibold));HStack{Text("待办占比").font(.system(size:12));Slider(value:$store.settings.customRatio,in:0.60...0.78);Text("\(Int(store.settings.customRatio*100))%").monospacedDigit().font(.system(size:12))};HStack{ForEach([("weather","三日天气"),("stocks","小行情"),("note","小纸条")],id:\.0){module in Toggle(module.1,isOn:Binding(get:{store.settings.customModules.contains(module.0)},set:{enabled in if enabled{store.settings.customModules.append(module.0)}else{store.settings.customModules.removeAll{$0==module.0}}})).toggleStyle(.checkbox)}};ForEach(Array(store.settings.customModules.enumerated()),id:\.element){index,module in HStack{Text(["weather":"三日天气","stocks":"小行情","note":"小纸条"][module] ?? module);Spacer();Button{if index>0{store.settings.customModules.swapAt(index,index-1)}}label:{Image(systemName:"arrow.up")}.disabled(index==0);Button{if index+1<store.settings.customModules.count{store.settings.customModules.swapAt(index,index+1)}}label:{Image(systemName:"arrow.down")}.disabled(index+1==store.settings.customModules.count)}.font(.system(size:12))}}}}
        HStack{Text("切换排版会进行一次全刷，约20秒。").font(.system(size:11)).foregroundStyle(muted);Spacer();Button{Task{await store.applyLayout()}}label:{Label("应用「\(store.settings.layout.title)」",systemImage:"arrow.up.right.square")}.buttonStyle(Primary()).disabled(store.isSending || !store.connected)}
    }
    func preview(_ layout:DeskLayout)->ScreenContent{var c=store.content;c.afterHours=false;c.settings.layout=layout;return c}
}
struct ScheduleView:View {
    @EnvironmentObject var store:DeskStore
    var body:some View {
        SectionIntro(eyebrow:"A RHYTHM OF YOUR OWN",title:"工作有节奏，下班有生活。",subtitle:"到点切换万年历，也可以按下“下班了”，提前收起工作。")
        HStack(alignment:.top,spacing:22){Card{VStack(alignment:.leading,spacing:22){Text("工作与下班时间").font(.system(size:18,weight:.semibold));Toggle("按作息自动切换",isOn:$store.settings.scheduleEnabled).onChange(of:store.settings.scheduleEnabled){_,enabled in if enabled{Task{await store.checkSchedule()}}};Text("开启后，到点切换会进行一次全刷；Mac应用需保持运行。").font(.system(size:11)).foregroundStyle(muted)
            HStack{DatePicker("上班",selection:timeBinding(\.startMinute),displayedComponents:.hourAndMinute);DatePicker("下班",selection:timeBinding(\.endMinute),displayedComponents:.hourAndMinute)}
            Toggle("按中国法定节假日调整（2026）",isOn:$store.settings.respectHolidays).font(.system(size:12));Text("工作日").font(.system(size:12,weight:.medium));HStack(spacing:7){ForEach(Array([(2,"一"),(3,"二"),(4,"三"),(5,"四"),(6,"五"),(7,"六"),(1,"日")].enumerated()),id:\.offset){_,day in Button{if store.settings.weekdays.contains(day.0){store.settings.weekdays.removeAll{$0==day.0}}else{store.settings.weekdays.append(day.0)}}label:{Text(day.1).font(.system(size:12)).frame(width:31,height:32).background(store.settings.weekdays.contains(day.0) ? sage:ink.opacity(0.05),in:RoundedRectangle(cornerRadius:7)).foregroundStyle(store.settings.weekdays.contains(day.0) ? .white:ink)}.buttonStyle(.plain)}}
            Divider();Text("临时加班或提前下班？").font(.system(size:14,weight:.medium));Text("手动切换保持到下一个计划时间；未开启作息时，保持到你再次切换。").font(.system(size:12)).foregroundStyle(muted);Button{Task{await store.switchMode()}}label:{Label(store.afterHours ? "开始工作":"现在下班",systemImage:store.afterHours ? "sun.max":"moon")}.buttonStyle(Primary()).disabled(store.isSending)
        }}
        VStack(spacing:18){Card{VStack(alignment:.leading,spacing:16){Text("下班后的屏幕").font(.system(size:16,weight:.semibold));ScreenPreview(content:calendarPreview);Text("公历 · 农历 · 节气 · 月历 · 天气").font(.system(size:11)).foregroundStyle(muted);Text("工作待办会收起，日历按天更新。").font(.system(size:12)).foregroundStyle(muted)}};Card{VStack(alignment:.leading,spacing:12){Label("提醒方式",systemImage:"bell.badge").font(.system(size:14,weight:.medium));Toggle("启用 Mac 通知",isOn:Binding(get:{store.settings.notifications},set:{enabled in if enabled{Task{await store.enableNotifications()}}else{store.settings.notifications=false}}));Text("天气、通勤与待办在 Mac 提醒；下班后收起工作提醒。").font(.system(size:11)).foregroundStyle(muted)}}}.frame(width:390)}
    }
    var calendarPreview:ScreenContent{var c=store.content;c.afterHours=true;return c}
    func timeBinding(_ key:WritableKeyPath<Preferences,Int>)->Binding<Date>{Binding(get:{WorkSchedule.calendar.date(byAdding:.minute,value:store.settings[keyPath:key],to:WorkSchedule.calendar.startOfDay(for:Date()))!},set:{date in store.settings[keyPath:key]=WorkSchedule.calendar.component(.hour,from:date)*60+WorkSchedule.calendar.component(.minute,from:date)})}
}
struct AssistantView:View {
    @EnvironmentObject var store:DeskStore
    @SwiftUI.State<String> var prompt=""
    var body:some View {
        SectionIntro(eyebrow:"A THOUGHTFUL LITTLE ASSISTANT",title:"说一句，帮你安排好。",subtitle:"会查数据，会记住偏好，也会在合适的时候提醒。")
        HStack(alignment:.top,spacing:22){Card{VStack(alignment:.leading,spacing:18){HStack{Label("墨间助理",systemImage:"sparkles").font(.system(size:17,weight:.semibold));Spacer();Pill(label:store.deepSeekKey.isEmpty ? "待配置":"DeepSeek",symbol:"circle.dotted")};AgentProposalsView();if store.messages.isEmpty{Text("可以试着说：\n“明天下午三点前提醒我提交方案”\n“看看今天的天气，给我一份简报”").font(.system(size:14)).foregroundStyle(muted).lineSpacing(10).padding(.vertical,28)};ForEach(store.messages){line in HStack{if line.user{Spacer(minLength:40)};Text(line.text).font(.system(size:13)).lineSpacing(5).textSelection(.enabled).padding(15).background(line.user ? sage.opacity(0.1):canvasColor,in:RoundedRectangle(cornerRadius:12));if !line.user{Spacer(minLength:40)}}};if store.aiBusy{HStack{ProgressView(store.agentStatus).controlSize(.small);Spacer();Button("停止"){store.stopAgent()}.buttonStyle(Quiet())}};Divider();TextField("说说你想做什么…",text:$prompt,axis:.vertical).lineLimit(3...6).textFieldStyle(.plain).font(.system(size:14));HStack{Text("模型请求会使用你配置的 API。").font(.system(size:10)).foregroundStyle(muted);Spacer();Button{let text=prompt;prompt="";Task{await store.ask(text)}}label:{Label("发送",systemImage:"arrow.up")}.buttonStyle(Primary()).disabled(store.aiBusy||prompt.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}}}
            VStack(spacing:18){AgentPanel();Card{VStack(alignment:.leading,spacing:14){Label("天气与出门",systemImage:"cloud.sun").font(.system(size:14,weight:.semibold));Text(store.weather.map{"\(store.settings.city)  \(Int($0.temperature.rounded()))° · \($0.text)"} ?? "天气待更新").font(.system(size:20));Text(store.feedStatus).font(.system(size:11)).foregroundStyle(muted);Button("生成今日简报"){Task{await store.ask("请结合当前真实天气、通勤和待办，给出不超过100字的今日简报。先查询待办，不添加或完成任务。")}}.buttonStyle(Quiet()).disabled(store.aiBusy)}};Card{VStack(alignment:.leading,spacing:14){Label("路上时间",systemImage:"car").font(.system(size:14,weight:.semibold));Text(store.commute?.text ?? "尚未接入路线").font(.system(size:20));Text(store.trafficStatus).font(.system(size:11)).foregroundStyle(muted);Text("上班 "+String(format:"%02d:%02d",store.settings.startMinute/60,store.settings.startMinute%60)+" · 预留\(store.settings.commuteBuffer)分钟").font(.system(size:11)).foregroundStyle(muted);Button("更新通勤耗时"){Task{await store.refreshCommute()}}.buttonStyle(Quiet())}};Card{VStack(alignment:.leading,spacing:14){Label("专注一小会儿",systemImage:"timer").font(.system(size:14,weight:.semibold));Text(store.focusEnd.map{"进行至 "+dateText($0,"HH:mm")} ?? "给自己 \(store.settings.focusMinutes) 分钟").font(.system(size:20));Stepper("\(store.settings.focusMinutes) 分钟",value:$store.settings.focusMinutes,in:5...90,step:5);Button(store.focusEnd==nil ? "开始专注":"结束专注"){store.startFocus()}.buttonStyle(Quiet())}}}.frame(width:300)
        }
    }
}
struct SettingsView:View {
    @EnvironmentObject var store:DeskStore
    @SwiftUI.State<String> var token=""
@SwiftUI.State<String> var deepseek=""
@SwiftUI.State<String> var amap=""
@SwiftUI.State<String> var citySearch=""
@SwiftUI.State<String> var stockText=""
    @SwiftUI.State<[CityChoice]> var cities=[]
    struct CityChoice:Identifiable{let id=UUID();let label:String;let lat:Double;let lon:Double}
    var body:some View {
        SectionIntro(eyebrow:"EVERYTHING IN ITS PLACE",title:"连接一次，往后都顺手。",subtitle:"设备、数据与助理，都在这里设置。密钥只保存在 Mac 钥匙串。")
        Button("读取已保存的密钥"){store.loadSavedCredentials()}.buttonStyle(Quiet())
        HStack(alignment:.top,spacing:22){VStack(spacing:22){Card{VStack(alignment:.leading,spacing:18){Label("我的工作台",systemImage:"display").font(.system(size:18,weight:.semibold));DiscoveryRow();TextField("工作台地址，例如 http://192.168.1.20",text:$store.settings.deviceURL).textFieldStyle(.roundedBorder);SecureField("访问口令",text:$token).textFieldStyle(.roundedBorder);HStack{Button(store.isConnecting ? "正在连接…":"连接工作台"){store.deviceToken=token;store.deepSeekKey=deepseek;store.amapKey=amap;Task{await store.connectDevice()}}.buttonStyle(Primary()).disabled(store.isConnecting||store.isSending);Button("读取设备清单"){Task{await store.connectDevice(importTasks:true)}}.buttonStyle(Quiet()).disabled(!store.connected)};Text("读取设备清单会导入设备当前待办。首次应用新布局需全刷一次。").font(.system(size:11)).foregroundStyle(muted);Toggle("内容变化时自动同步到屏幕",isOn:$store.settings.autoSync);Text("同一布局只局刷；蓝牙发现地址后，数据通过同一局域网传输。").font(.system(size:11)).foregroundStyle(muted)}}
            Card{VStack(alignment:.leading,spacing:16){Label("天气与小行情",systemImage:"cloud.sun").font(.system(size:18,weight:.semibold));HStack{TextField("搜索城市",text:$citySearch).textFieldStyle(.roundedBorder);Button("查找"){Task{do{cities=try await Remote.resolveCity(citySearch).map{CityChoice(label:$0.0,lat:$0.1,lon:$0.2)}}catch{store.status=error.localizedDescription}}}};ForEach(cities){city in Button(city.label){store.settings.city=city.label.components(separatedBy:" · ").first ?? city.label;store.settings.latitude=city.lat;store.settings.longitude=city.lon;store.weather=nil;cities=[];Task{await store.refreshFeeds()}}.buttonStyle(.plain).foregroundStyle(sage)};Text("当前城市："+store.settings.city).font(.system(size:11)).foregroundStyle(muted);TextField("股票代码，以逗号分隔，最多五支",text:$stockText).textFieldStyle(.roundedBorder);Text("示例：sh600519, sz000001, hk00700, usAAPL").font(.system(size:10)).foregroundStyle(muted);Button("保存并更新数据"){store.settings.stocks=stockText.split(separator:",").map{$0.trimmingCharacters(in:.whitespacesAndNewlines)};Task{await store.refreshFeeds()}}.buttonStyle(Quiet());Text(store.feedStatus).font(.system(size:11)).foregroundStyle(muted)}}
        }
        VStack(spacing:22){Card{VStack(alignment:.leading,spacing:16){Label("DeepSeek",systemImage:"sparkles").font(.system(size:18,weight:.semibold));SecureField("API Key",text:$deepseek).textFieldStyle(.roundedBorder);TextField("模型名称",text:$store.settings.deepSeekModel).textFieldStyle(.roundedBorder);Text("根据你授权的请求生成简报、管理待办。天气和路线不会由模型编造。").font(.system(size:11)).foregroundStyle(muted);Button(store.credentialsSaving ? "正在保存…":"保存密钥"){Task{await saveKeys()}}.buttonStyle(Quiet()).disabled(store.credentialsSaving)}}
            Card{VStack(alignment:.leading,spacing:16){Label("通勤路线",systemImage:"car").font(.system(size:18,weight:.semibold));TextField("家 / 出发地地址",text:$store.settings.homeAddress).textFieldStyle(.roundedBorder);TextField("公司 / 目的地地址",text:$store.settings.workAddress).textFieldStyle(.roundedBorder);SecureField("高德 Web 服务 Key",text:$amap).textFieldStyle(.roundedBorder);Stepper("额外预留 \(store.settings.commuteBuffer) 分钟",value:$store.settings.commuteBuffer,in:0...60,step:5);Text("当前支持驾车。需要开通地址解析与驾车路径规划的数据接口。").font(.system(size:11)).foregroundStyle(muted);Button(store.credentialsSaving ? "正在保存…":"保存并检查路线"){Task{if await saveKeys(){await store.refreshCommute()}}}.buttonStyle(Quiet()).disabled(store.credentialsSaving);Text(store.trafficStatus).font(.system(size:11)).foregroundStyle(muted)}}
        }.frame(width:340)}.onAppear{token=store.deviceToken;deepseek=store.deepSeekKey;amap=store.amapKey;stockText=store.settings.stocks.joined(separator:", ");citySearch=store.settings.city}.onChange(of:store.deviceToken){_,v in if token.isEmpty{token=v}}.onChange(of:store.deepSeekKey){_,v in if deepseek.isEmpty{deepseek=v}}.onChange(of:store.amapKey){_,v in if amap.isEmpty{amap=v}}
    }
    @discardableResult func saveKeys()async->Bool{await store.storeKeys(device:token,deepseek:deepseek,amap:amap)}
    var initialization:some View{EmptyView()}
}
struct DiscoveryRow:View {
    @EnvironmentObject var store:DeskStore
    var body:some View{DiscoveryContents(discovery:store.discovery)}
}
struct DiscoveryContents:View {
    @ObservedObject var discovery:DeviceDiscovery
    var body:some View{VStack(alignment:.leading,spacing:9){Button{discovery.start()}label:{Label("蓝牙发现工作台",systemImage:"antenna.radiowaves.left.and.right")}.buttonStyle(Quiet());Text(discovery.status).font(.system(size:11)).foregroundStyle(muted)}}
}
