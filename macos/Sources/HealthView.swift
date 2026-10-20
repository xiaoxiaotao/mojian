import SwiftUI
struct DataHealth {
 static func freshness(_ fetched:Date?,now:Date,ttl:TimeInterval,failed:Bool=false)->String {
  guard let fetched else{return failed ? "更新失败 · 暂无缓存":"尚无数据"}
  let age=now.timeIntervalSince(fetched)
  guard age >= -300 else{return "时间异常 · 请核对系统时间"}
  if age>=ttl{return failed ? "更新失败 · 缓存已过期":"缓存已过期"}
  return failed ? "更新失败 · 使用上次缓存":"缓存可用"
 }
 static func connection(_ address:String,_ contact:Date?,now:Date)->String {
  guard !address.isEmpty else{return "尚未配置设备"}
  guard let contact else{return "本次启动尚未确认连接"}
  let age=now.timeIntervalSince(contact)
  return age < -300 ? "时间异常 · 连接待确认":age>20 ? "连接待确认":"设备可访问"
 }
}
struct HealthView:View {
 @EnvironmentObject var store:DeskStore
 var navigate:(Int)->Void
 var body:some View {
  VStack(alignment:.leading,spacing:20){
   SectionIntro(eyebrow:"EVERYTHING IN SIGHT",title:"现在，哪些信息是新的？",subtitle:"连接成功、数据获取和上屏回执分别显示。这里的缓存状态属于Mac，设备自主天气可在首次配置中查看。")
   row("设备连接",DataHealth.connection(store.settings.deviceURL,store.lastDeviceContact,now:store.now),stamp(store.lastDeviceContact,"最近响应"),"检查连接"){Task{await store.checkHealthConnection()}}
   row("屏幕同步",syncTitle,store.syncStatus+"\n"+stamp(store.lastSync,"最近发送回执"),"设备与设置"){navigate(4)}
   row("天气 · "+store.settings.city,DataHealth.freshness(store.weather?.fetched,now:store.now,ttl:3600,failed:store.weatherFetchFailed),stamp(store.weather?.fetched,"最近获取")+"\n超过1小时标记过期；缓存可用不代表已上屏。","更新天气与行情"){Task{await store.refreshFeeds(forceWeather:true)}}
   row("自选行情",stockTitle,"行情时间由供应商提供，可能延迟或处于休市；不把刚获取等同于实时行情。","配置行情"){navigate(4)}
   row("驾车通勤",commuteTitle,stamp(store.commute?.fetched,"最近获取")+"\n超过15分钟标记过期；缺少路线或Key时先配置。","通勤设置"){navigate(4)}
   if !store.trafficStatus.isEmpty{Text(store.trafficStatus).font(.caption).foregroundStyle(muted)}
   HStack{Button("系统日历设置"){navigate(5)};Button("设备自主天气状态"){navigate(7)}}.buttonStyle(Quiet())
   Text("这里只读诊断和更新客户端缓存；不会自动接管布局或全刷。设备回执不能替代实屏显示检查。").font(.caption).foregroundStyle(muted)
   if !store.healthMessage.isEmpty{Text(store.healthMessage).font(.callout).foregroundStyle(muted)}
   if !store.storageError.isEmpty{Text(store.storageError).foregroundStyle(.red)}
  }
 }
 var syncTitle:String {if store.isSending{return "发送中"};if store.phoneOwnsScreen{return "手机控制中 · Mac未接管"};if store.requiresLayoutApplication{return "需要明确应用布局"};if store.syncPending{return "本机有内容待同步"};return store.lastSync==nil ? "尚无发送回执":"已有发送回执"}
 var stockTitle:String {if store.settings.stocks.isEmpty{return "未选择股票"};let available=Set(store.quotes.map{$0.code});let count=store.settings.stocks.filter{available.contains($0)}.count;return (store.stockFetchFailed ? "最近获取失败 · ":"")+"已缓存 \(count) / \(store.settings.stocks.count) 支"}
 var commuteTitle:String {if store.commute==nil && (store.settings.homeAddress.isEmpty || store.settings.workAddress.isEmpty || store.amapKey.isEmpty){return "需要配置路线与高德Key"};return DataHealth.freshness(store.commute?.fetched,now:store.now,ttl:900,failed:store.commuteFetchFailed)}
 func stamp(_ date:Date?,_ label:String)->String {date.map{label+"："+dateText($0,"MM/dd HH:mm:ss")} ?? label+"：本次尚无记录"}
 func row(_ title:String,_ value:String,_ detail:String,_ action:String,run:@escaping()->Void)->some View {
  Card{VStack(alignment:.leading,spacing:10){HStack(alignment:.top){VStack(alignment:.leading,spacing:6){Text(title).font(.headline);Text(value).font(.system(size:20,weight:.medium))};Spacer();Button(action,action:run).buttonStyle(Quiet()).disabled(store.feedBusy || store.isSending || store.isConnecting || store.healthBusy)};Text(detail).font(.caption).foregroundStyle(muted).fixedSize(horizontal:false,vertical:true)}}
 }
}
extension DeskStore {
 func checkHealthConnection()async {
  guard !healthBusy,!isSending,!isConnecting else{return};healthBusy=true;defer{healthBusy=false}
  let destination=settings.deviceURL
  do{let state=try await transport.state(destination,deviceToken);try DeviceIdentity.verify(settings.deviceID,state.device_id);guard settings.deviceURL==destination else{return};lastDeviceContact=Date();healthMessage="设备已响应；仅检查连接，未导入清单或发送画面。"}catch{guard settings.deviceURL==destination else{return};healthMessage="本次检查失败，请检查供电、Wi-Fi和设备地址。旧内容仍保留。";lastDeviceContact=nil}
 }
}
