import Foundation
import CoreFoundation
import CoreBluetooth

struct DeviceState: Decodable {
    struct Item:Decodable {var id:String?;var title:String;var due:String?;var pinned:Bool? = nil;var repeatRule:String? = nil;var repeatSeries:String? = nil;var repeatDay:Int? = nil}
    var accent_supported:Bool?
    var accent_version_supported:String?
    var content_key:String? = nil
    var tasks:[Item];var local_mode:Bool;var needs_full:Bool;var layout_id:String?;var external_layout:Bool?;var baseline_ready:Bool?
}
enum Remote {
    static func data(_ url:URL,body:Data?=nil,headers:[String:String]=[:],timeout:Double=25)async throws->Data {
        var request=URLRequest(url:url);request.timeoutInterval=timeout;request.httpMethod=body == nil ? "GET":"POST";request.httpBody=body
        for (key,value) in headers {request.setValue(value,forHTTPHeaderField:key)}
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let http=response as? HTTPURLResponse,(200..<300).contains(http.statusCode) else {
            let code=(response as? HTTPURLResponse)?.statusCode ?? 0
            if code==401{throw DeskError(message:url.host=="api.deepseek.com" ? "DeepSeek密钥无效，请在设置中更新":"访问口令不正确，请在设备设置中更新")}
            let error=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any]
            throw DeskError(message:(error?["error"] as? String) ?? "请求失败（\(code)），请检查连接或数据源配置")
        };return data
    }
    static func deviceURL(_ origin:String,_ path:String)throws->URL {
        guard let components=URLComponents(string:origin),["http","https"].contains(components.scheme ?? ""),let host=components.host,!host.isEmpty,components.user==nil,components.password==nil,let url=URL(string:path,relativeTo:URL(string:origin)) else {throw DeskError(message:"请填写有效的工作台地址，例如 http://192.168.1.20")};return url.absoluteURL
    }
    static func state(_ origin:String,_ token:String)async throws->DeviceState {
        let bytes=try await data(deviceURL(origin,"/api/local/state"));return try JSONDecoder().decode(DeviceState.self,from:bytes)
    }
    static func send(origin:String,token:String,frame:Data,tasks:[DeskTask],layout:String,contentKey:String,full:Bool,expected:String?=nil)async throws {
        if full {let state=try await state(origin,token);guard state.accent_version_supported == "mojian-red-v2" else{throw DeskError(message:"设备需升级固定红色布局固件后才能应用，请先更新固件")}}
        let iso=ISO8601DateFormatter()
        var metadata:[String:Any]=["tasks":tasks.filter{!$0.done}.prefix(8).map{["id":$0.id,"title":$0.title,"due":$0.due.map{iso.string(from:$0)} as Any? ?? NSNull(),"pinned":$0.pinned ?? false]},"layout_id":layout,"content_key":contentKey,"external_layout":true,"accent_version":"mojian-red-v2","accent_style":String(layout.split(separator:".").dropFirst().first ?? "focus"),"epoch_seconds":Int(Date().timeIntervalSince1970),"updated_at":iso.string(from:Date())]
        if let expected{metadata["expected_content_key"]=expected}
        var items:[[String:Any]]=[];for task in tasks.filter({!$0.done}).prefix(8){var value:[String:Any]=["id":task.id,"title":task.title,"due":task.due.map{iso.string(from:$0)} as Any? ?? NSNull(),"pinned":task.pinned ?? false];if let rule=task.repeatRule{value["repeatRule"]=rule;value["repeatSeries"]=task.repeatSeries ?? task.id;value["repeatDay"]=task.repeatDay ?? 1};items.append(value)};metadata["tasks"]=items
        let meta=try JSONSerialization.data(withJSONObject:metadata)
        let boundary="MoJian"+UUID().uuidString.replacingOccurrences(of:"-",with:"")
        var body=Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"metadata\"\r\n\r\n".utf8);body.append(meta)
        body.append(Data("\r\n--\(boundary)\r\nContent-Disposition: form-data; name=\"frame\"; filename=\"frame.bin\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8));body.append(frame);body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        _=try await data(deviceURL(origin,"/api/local/commit?full=\(full ? 1:0)"),body:body,headers:["Content-Type":"multipart/form-data; boundary="+boundary],timeout:90)
    }
    static func weather(_ settings:Preferences)async throws->WeatherSnapshot {
        let url=URL(string:"https://api.open-meteo.com/v1/forecast?latitude=\(settings.latitude)&longitude=\(settings.longitude)&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=Asia%2FShanghai&forecast_days=3&hourly=precipitation_probability,apparent_temperature,wind_speed_10m&wind_speed_unit=ms")!
        let json=try JSONSerialization.jsonObject(with:await data(url)) as? [String:Any]
        guard let current=json?["current"] as? [String:Any],let temp=current["temperature_2m"] as? Double,let code=current["weather_code"] as? Int,let daily=json?["daily"] as? [String:Any],let dates=daily["time"] as? [String],let low=daily["temperature_2m_min"] as? [Double],let high=daily["temperature_2m_max"] as? [Double],let codes=daily["weather_code"] as? [Int],dates.count==low.count,dates.count==high.count,dates.count==codes.count else {throw DeskError(message:"天气数据暂不可用，保留上次结果")}
        var hours:[HourForecast]=[]
        if let hourly=json?["hourly"] as? [String:Any],let times=hourly["time"] as? [String] {
            let rain=hourly["precipitation_probability"] as? [Any] ?? [],feel=hourly["apparent_temperature"] as? [Any] ?? [],wind=hourly["wind_speed_10m"] as? [Any] ?? []
            let formatter=DateFormatter();formatter.locale=Locale(identifier:"en_US_POSIX");formatter.timeZone=TimeZone(identifier:"Asia/Shanghai");formatter.dateFormat="yyyy-MM-dd'T'HH:mm"
            func value(_ values:[Any],_ i:Int)->Double?{guard i<values.count,let n=values[i] as? NSNumber,n.doubleValue.isFinite else{return nil};return n.doubleValue}
            for (i,t) in times.enumerated(){if let date=formatter.date(from:t){hours.append(HourForecast(time:date,rainProbability:value(rain,i),apparent:value(feel,i),wind:value(wind,i)))}}
        }
        return WeatherSnapshot(temperature:temp,code:code,days:dates.indices.map{DayForecast(date:dates[$0],low:low[$0],high:high[$0],code:codes[$0])},fetched:Date(),hours:hours)
    }
    static func resolveCity(_ name:String)async throws->[(String,Double,Double)] {
        var c=URLComponents(string:"https://geocoding-api.open-meteo.com/v1/search")!;c.queryItems=[.init(name:"name",value:name),.init(name:"count",value:"5"),.init(name:"language",value:"zh")]
        let json=try JSONSerialization.jsonObject(with:await data(c.url!)) as? [String:Any]
        return (json?["results"] as? [[String:Any]] ?? []).compactMap{r in guard let n=r["name"] as? String,let lat=r["latitude"] as? Double,let lon=r["longitude"] as? Double else{return nil};return (n+" · "+(r["admin1"] as? String ?? r["country"] as? String ?? ""),lat,lon)}
    }
    static func stocks(_ values:[String])async throws->[StockQuote] {
        guard values.count<=5,values.allSatisfy({$0.range(of:"^(sh|sz|bj)[0-9]{6}$|^hk[0-9]{5}$|^us[A-Z][A-Z0-9.]{0,9}$",options:.regularExpression) != nil}) else{throw DeskError(message:"最多五支股票，代码如 sh600519、sz000001、hk00700、usAAPL")}
        if values.isEmpty{return []}
        let bytes=try await data(URL(string:"https://qt.gtimg.cn/q="+values.joined(separator:","))!)
        let encoding=String.Encoding(rawValue:CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        guard let source=String(data:bytes,encoding:encoding) else {throw DeskError(message:"行情编码无法读取")}
        var results:[StockQuote]=[]
        for code in values {
            guard let start=source.range(of:"v_\(code)=\""),let end=source[start.upperBound...].firstIndex(of:"\"") else{continue}
            let f=source[start.upperBound..<end].components(separatedBy:"~")
            if f.count>32,let price=Double(f[3]),price>0,let change=Double(f[31]),let percent=Double(f[32]),price.isFinite,change.isFinite,percent.isFinite{results.append(StockQuote(code:code,name:f[1],price:price,change:change,percent:percent,asOf:f[30]))}
        }
        if results.count != values.count{throw DeskError(message:"部分行情未返回，保留上次结果")};return results
    }
    static func commute(_ settings:Preferences,key:String)async throws->CommuteSnapshot {
        guard !key.isEmpty,!settings.homeAddress.isEmpty,!settings.workAddress.isEmpty else{throw DeskError(message:"请配置高德Web服务Key、家和公司地址")}
        func endpoint(_ path:String,_ params:[String:String])->URL {var c=URLComponents(string:"https://restapi.amap.com"+path)!;c.queryItems=(params.merging(["key":key]){a,_ in a}).map{URLQueryItem(name:$0.key,value:$0.value)};return c.url!}
        func geocode(_ address:String)async throws->String {
            let json=try JSONSerialization.jsonObject(with:await data(endpoint("/v3/geocode/geo",["address":address,"city":settings.city]))) as? [String:Any]
            guard json?["status"] as? String=="1",let first=(json?["geocodes"] as? [[String:Any]])?.first,let location=first["location"] as? String else{throw amapError(json,stage:"地址解析")};return location
        }
        let positions=try await (geocode(settings.homeAddress),geocode(settings.workAddress))
        let json=try JSONSerialization.jsonObject(with:await data(endpoint("/v5/direction/driving",["origin":positions.0,"destination":positions.1,"show_fields":"cost,tmcs","strategy":"32"]))) as? [String:Any]
        return try parseCommute(json)
    }
    static func amapError(_ json:[String:Any]?,stage:String)->DeskError {
        let code=json?["infocode"] as? String ?? "未知"
        let messages=["10001":"Key无效，请检查是否完整","10003":"调用额度已用完","10005":"IP白名单不匹配","10009":"Key的平台类型不匹配，请使用Web服务Key","10012":"接口权限不足","10013":"Key已删除","10021":"接口权限不足"]
        return DeskError(message:"高德"+stage+"失败（"+code+"）："+(messages[code] ?? "请检查接口权限、地址和服务额度"))
    }
    static func parseCommute(_ json:[String:Any]?,fetched:Date=Date())throws->CommuteSnapshot {
        guard json?["status"] as? String=="1" else{throw amapError(json,stage:"路线查询")}
        func number(_ value:Any?)->Double? {if let s=value as? String{return Double(s)};return (value as? NSNumber)?.doubleValue}
        guard let route=json?["route"] as? [String:Any],let first=(route["paths"] as? [[String:Any]])?.first,let cost=first["cost"] as? [String:Any],let seconds=number(cost["duration"]),seconds.isFinite,seconds>0,seconds<604800 else{throw DeskError(message:"高德未返回有效驾车耗时，请重试")}
        var distances:[String:Double]=[:],roads:[String]=[]
        for step in first["steps"] as? [[String:Any]] ?? [] {
            for tmc in step["tmcs"] as? [[String:Any]] ?? [] {
                let status=tmc["tmc_status"] as? String ?? "未知"
                guard let distance=number(tmc["tmc_distance"]),distance.isFinite,distance>0 else{continue}
                distances[status,default:0]+=distance
                if ["缓行","拥堵","严重拥堵"].contains(status),let road=step["road_name"] as? String,!road.isEmpty,!roads.contains(road){roads.append(road)}
            }
        }
        var summary:[String]=[]
        for status in ["严重拥堵","拥堵","缓行","畅通","未知"] {if let meters=distances[status],meters>0{summary.append(status+String(format:"约%.1f公里",meters/1000))}}
        var traffic=summary.isEmpty ? "高德未返回分段路况，不能仅凭耗时判断是否堵车":summary.joined(separator:"，")
        if !roads.isEmpty {traffic+="；缓行或拥堵路段："+roads.prefix(3).joined(separator:"、")}
        return CommuteSnapshot(minutes:Int(ceil(seconds/60)),fetched:fetched,trafficSummary:traffic,distanceKM:number(first["distance"]).map{$0/1000})

    }
}
@MainActor final class DeviceDiscovery:NSObject,ObservableObject,@preconcurrency CBCentralManagerDelegate,@preconcurrency CBPeripheralDelegate {
    @Published var status="通过蓝牙发现设备，自动读取局域网地址"
    var found:((String)->Void)?
    var central:CBCentralManager?;var peripheral:CBPeripheral?;var timeout:Timer?
    private var wifiPackets:[Data]=[],wifiIndex=0,configuring=false,reads=0
    let service=CBUUID(string:"7f510001-8be5-4b2c-a47f-87c7e72e7050"),endpoint=CBUUID(string:"7f510003-8be5-4b2c-a47f-87c7e72e7050"),provision=CBUUID(string:"7f510004-8be5-4b2c-a47f-87c7e72e7050")
    func start(){begin(nil)}
    func configureWifi(_ ssid:String,_ password:String){guard (1...32).contains(ssid.utf8.count),password.isEmpty || (8...63).contains(password.utf8.count) else{status="Wi-Fi名称1至32字节，密码8至63字节或留空";return};do{let payload=try JSONSerialization.data(withJSONObject:["ssid":ssid,"password":password]);begin(payload)}catch{status="配网信息无效"}}
    private func begin(_ payload:Data?){stop();reads=0;configuring=payload != nil;wifiIndex=0;if let payload{var offset=0;while offset<payload.count{let end=min(payload.count,offset+19);var packet=Data([offset==0 ? 83:67]);packet.append(payload[offset..<end]);wifiPackets.append(packet);offset=end};wifiPackets.append(Data([69]))};status="正在查找 Desk-EPD…";if central==nil{central=CBCentralManager(delegate:self,queue:.main)}else{scan()};timeout=Timer.scheduledTimer(withTimeInterval:configuring ? 90:30,repeats:false){[weak self]_ in Task{@MainActor in self?.stop();self?.status="操作超时，配网失败时设备保留原网络，请稍后重试"}}}
    func scan(){guard central?.state == .poweredOn else{status="请开启蓝牙并允许附近设备访问";return};central?.scanForPeripherals(withServices:[service])}
    func stop(){timeout?.invalidate();central?.stopScan();if let p=peripheral{central?.cancelPeripheralConnection(p)};peripheral=nil;for i in wifiPackets.indices{wifiPackets[i].resetBytes(in:0..<wifiPackets[i].count)};wifiPackets=[];configuring=false}
    func centralManagerDidUpdateState(_ central:CBCentralManager){if central.state == .poweredOn{scan()}else{status="请在系统设置中开启蓝牙，并允许墨间访问蓝牙"}}
    func centralManager(_ central:CBCentralManager,didDiscover p:CBPeripheral,advertisementData:[String:Any],rssi:NSNumber){if peripheral != nil{return};peripheral=p;p.delegate=self;central.stopScan();status="正在读取设备服务…";central.connect(p)}
    func centralManager(_ central:CBCentralManager,didConnect p:CBPeripheral){p.discoverServices([service])}
    func centralManager(_ central:CBCentralManager,didFailToConnect p:CBPeripheral,error:Error?){stop();status="连接未建立，请重试"}
    func peripheral(_ p:CBPeripheral,didDiscoverServices error:Error?){guard error==nil,let s=p.services?.first else{stop();status="读取服务失败";return};p.discoverCharacteristics([endpoint,provision],for:s)}
    func peripheral(_ p:CBPeripheral,didDiscoverCharacteristicsFor service:CBService,error:Error?){guard error==nil,let c=service.characteristics?.first(where:{$0.uuid==(configuring ? provision:endpoint)}) else{stop();status="请更新设备固件以支持蓝牙配网";return};if configuring{status="正在加密发送Wi-Fi配置；如有系统配对窗口请确认";writeNext(p,c)}else{p.readValue(for:c)}}
    private func writeNext(_ p:CBPeripheral,_ c:CBCharacteristic){guard wifiIndex<wifiPackets.count else{p.readValue(for:c);return};let packet=wifiPackets[wifiIndex];wifiIndex+=1;p.writeValue(packet,for:c,type:.withResponse)}
    func peripheral(_ p:CBPeripheral,didWriteValueFor characteristic:CBCharacteristic,error:Error?){guard p==peripheral else{return};guard error==nil else{stop();status="加密配网写入失败，请完成系统配对后重试";return};writeNext(p,characteristic)}
    private func readProvisionLater(_ p:CBPeripheral){DispatchQueue.main.asyncAfter(deadline:.now()+2){[weak self] in guard let self,self.peripheral==p,let c=p.services?.flatMap({$0.characteristics ?? []}).first(where:{$0.uuid==self.provision}) else{return};p.readValue(for:c)}}
    private func readEndpointLater(_ p:CBPeripheral){DispatchQueue.main.asyncAfter(deadline:.now()+2){[weak self] in guard let self,self.peripheral==p,let characteristic=p.services?.flatMap({$0.characteristics ?? []}).first(where:{$0.uuid==self.endpoint}) else{return};p.readValue(for:characteristic)}}
    func peripheral(_ p:CBPeripheral,didUpdateValueFor characteristic:CBCharacteristic,error:Error?){guard p==peripheral,error==nil,let data=characteristic.value,let value=String(data:data,encoding:.utf8) else{stop();status="读取设备响应失败";return};if characteristic.uuid==provision{guard ["accepted","connected"].contains(value) else{stop();status=value=="press-boot" ? "请按住工作台BOOT两秒，开启五分钟配网窗口后重试":"配网未接受，请检查网络名称与密码";return};status="配置已接收，正在等待工作台接入Wi-Fi…";if value=="accepted"{reads+=1;if reads>25{stop();status="配网超时，工作台保留原网络";return};readProvisionLater(p)}else{readEndpointLater(p)};return};let parts=value.split(separator:".");if value=="0.0.0.0",reads<(configuring ? 25:5){reads+=1;status="工作台正在连接Wi-Fi…";readEndpointLater(p);return};guard parts.count==4,parts.allSatisfy({Int($0).map{(0...255).contains($0)} ?? false}),value != "0.0.0.0" else{stop();status="工作台尚未取得可用地址，请确认Wi-Fi名称、密码和2.4GHz网络";return};let url="http://"+value;stop();status="已发现 "+url;found?(url)}
}
