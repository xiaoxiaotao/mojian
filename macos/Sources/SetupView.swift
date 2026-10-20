import SwiftUI
import AppKit
struct SetupView:View {
    var onFinish:()->Void = {}
    @EnvironmentObject var store:DeskStore
    var body:some View{SetupContents(discovery:store.discovery,onFinish:onFinish).environmentObject(store)}
}
struct SetupContents:View {
    @EnvironmentObject var store:DeskStore
    @ObservedObject var discovery:DeviceDiscovery
    var onFinish:()->Void = {}
    @SwiftUI.State private var step=0
    @SwiftUI.State private var ssid=""
    @SwiftUI.State private var password=""
    @SwiftUI.State private var title=""
    @SwiftUI.State private var repeatRule:RepeatRule = .none
    @SwiftUI.State private var due=Date().addingTimeInterval(3600)
    @SwiftUI.State private var autonomyBusy=false
    @SwiftUI.State private var autoStatus="设备需持续供电；手机与Mac可以退出。"
    var body:some View {
        SectionIntro(eyebrow:"MAKE YOURSELF AT HOME",title:"几步，把桌面安排好。",subtitle:"连接 → 配网 → 选桌面 → 自主更新 → 记一件事")
        Card{VStack(alignment:.leading,spacing:18){
            HStack{Text("第 \(step+1) / 5 步").font(.headline);Spacer();Button("蓝牙配网"){password="";step=1}.buttonStyle(Quiet());Button("自主更新设置"){password="";step=3}.buttonStyle(Quiet())}
            if step==0{Text("通过蓝牙发现工作台，不必先知道IP地址。");DiscoveryContents(discovery:discovery);TextField("或填写已有工作台地址",text:$store.settings.deviceURL).textFieldStyle(.roundedBorder);Button("连接已有设备"){Task{await store.connectDevice()}}.buttonStyle(Quiet())}
            if step==1{Text("配网支持2.4GHz Wi-Fi。已联网可以跳过；更换网络时，按住工作台BOOT键两秒后，五分钟内发送。");TextField("Wi-Fi名称",text:$ssid).textFieldStyle(.roundedBorder);SecureField("Wi-Fi密码（开放网络留空）",text:$password).textFieldStyle(.roundedBorder);Button("通过加密蓝牙发送"){discovery.configureWifi(ssid,password);password=""}.buttonStyle(Primary());Text(discovery.status).font(.caption);Text("失败会回到原网络。密码不写入Mac配置文件，不发送给模型。").font(.caption).foregroundStyle(muted)}
            if step==2{Text("选择桌面；应用时明确全刷一次，保留已有清单。");HStack{ForEach([("work","工作桌面"),("focus","专注桌面"),("life","生活画报")],id:\.0){key,name in Button(name+" · 全刷"){Task{await store.applyScene(key)}}.buttonStyle(Quiet())}}.disabled(!store.connected||store.isSending);ScreenPreview(content:store.content)}
            if step==3{Text("开启设备自主更新后，时钟按分钟局刷，天气每10分钟由ESP32直接获取。天气区采用设备的简洁排版，其他区域保持。");Text("重启后仍需明确应用布局建立基准。股票、日历与其他卡片目前继续由客户端更新。").font(.caption).foregroundStyle(muted);HStack{Button("开启自主时钟与天气"){Task{await configureAutonomy(true)}}.buttonStyle(Primary());Button("关闭自主更新"){Task{await configureAutonomy(false)}}.buttonStyle(Quiet());Button("读取运行状态"){Task{await readAutonomy()}}.buttonStyle(Quiet())}.disabled(!store.connected||autonomyBusy||store.isSending);Text(autoStatus).font(.caption).foregroundStyle(muted)}
            if step==4{Text("记下第一件事。重复事项完成后只生成下一次，不补过去的积压任务。");TextField("待办内容",text:$title).textFieldStyle(.roundedBorder);DatePicker("截止时间",selection:$due);Picker("重复",selection:$repeatRule){ForEach(RepeatRule.allCases,id:\.self){Text($0.title).tag($0)}};Button("添加并局部同步"){if store.addTask(title,due:due,repeatRule:repeatRule){title=""}}.buttonStyle(Primary())}
            Divider()
            HStack{if step>0{Button("上一步"){password="";step-=1}.buttonStyle(Quiet())};Spacer();if step<4{Button("继续"){if step>=1 && !store.connected{store.status="请先连接工作台";return};if step==2 && store.requiresLayoutApplication{store.status="请先明确应用一次布局";return};password="";step+=1}.buttonStyle(Primary())}else{Button("完成配置"){UserDefaults.standard.set(true,forKey:"mojian.setupDone");store.status="配置完成，回到工作台即可使用。";onFinish()}.buttonStyle(Primary())}}
        }}
    }
    func configureAutonomy(_ enabled:Bool)async{guard !autonomyBusy else{return};autonomyBusy=true;defer{autonomyBusy=false};do{let value:[String:Any]=["enabled":enabled,"latitude":store.settings.latitude,"longitude":store.settings.longitude,"city_bitmap":AutonomyConfig.cityBitmap(store.settings.city)];_=try await Remote.data(Remote.deviceURL(store.settings.deviceURL,"/api/local/autonomy"),body:JSONSerialization.data(withJSONObject:value),headers:["Content-Type":"application/json"]);await readAutonomy()}catch{autoStatus=error.localizedDescription}}
    func readAutonomy()async{do{let bytes=try await Remote.data(Remote.deviceURL(store.settings.deviceURL,"/api/local/autonomy"));let value=try JSONSerialization.jsonObject(with:bytes) as? [String:Any] ?? [:];autoStatus=(value["enabled"] as? Bool==true ? "自主更新已开启":"自主更新已关闭")+" · "+(value["weather_available"] as? Bool==true ? "天气缓存可用":"等待获取天气")+(value["error"] as? String ?? "")}catch{autoStatus=error.localizedDescription}}
}
enum AutonomyConfig {
    static func cityBitmap(_ city:String)->String{let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:128,pixelsHigh:20,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!;let context=NSGraphicsContext(bitmapImageRep:bitmap)!;NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=context;NSColor.white.setFill();NSRect(x:0,y:0,width:128,height:20).fill();let attrs:[NSAttributedString.Key:Any]=[.font:ScreenFonts.font(city,16,false),.foregroundColor:NSColor.black];(String(city.prefix(7)) as NSString).draw(at:NSPoint(x:0,y:1),withAttributes:attrs);NSGraphicsContext.restoreGraphicsState();var bytes=Data(repeating:0,count:320);for y in 0..<20{for x in 0..<128{let color=bitmap.colorAt(x:x,y:y)?.usingColorSpace(.deviceRGB);if (color?.redComponent ?? 1)>=0.63{bytes[y*16+x/8]|=UInt8(128>>(x%8))}}};return bytes.base64EncodedString()}
}
