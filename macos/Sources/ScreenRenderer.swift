import AppKit

struct ScreenContent {
    var tasks:[DeskTask];var settings:Preferences;var weather:WeatherSnapshot?;var quotes:[StockQuote]
    var now=Date();var afterHours=false;var brief="";var commute:CommuteSnapshot?;var focusEnd:Date?;var nextEvent:NextCalendarEvent?;var calendarStatus="未启用系统日历"
}
enum ScreenRenderer {
    static func stockMovement(_ percent:Double)->String {
        if percent == 0{return "— 0.00%"}
        return (percent>0 ? "▲ ":"▼ ")+String(format:"%+.2f%%",percent)
    }
    static func render(_ content:ScreenContent,accent:Bool=true)->NSImage {
        NSImage(size:NSSize(width:800,height:480),flipped:true){ bounds in
            NSColor.white.setFill();bounds.fill()
            let painter=Painter(content)
            if content.afterHours { painter.calendar() } else { painter.work() }
            NSColor.white.setFill();NSRect(x:0,y:80,width:800,height:24).fill()
            NSGraphicsContext.current?.imageInterpolation = .none
            if accent,let url=Bundle.main.url(forResource:"StaticAccent-"+(content.afterHours ? "calendar":content.settings.layout.rawValue),withExtension:"png"),let image=NSImage(contentsOf:url){image.draw(in:bounds)}
            return true
        }
    }
    static func blackFrame(_ content:ScreenContent)throws->Data {
        try bitmap(render(content,accent:false))
    }
    static func raster(_ image:NSImage)throws->[UInt8] {
        guard let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil) else{throw DeskError(message:"无法生成屏幕画面")}
        var rgba=[UInt8](repeating:255,count:800*480*4)
        guard let context=CGContext(data:&rgba,width:800,height:480,bitsPerComponent:8,bytesPerRow:3200,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{throw DeskError(message:"无法生成显示数据")}
        context.interpolationQuality = .none
        context.draw(cg,in:CGRect(x:0,y:0,width:800,height:480))
        return rgba
    }
    static func bitmap(_ image:NSImage)throws->Data {
        let rgba=try raster(image)
        var bytes=[UInt8](repeating:0,count:48000)
        for i in 0..<384000 { if rgba[i*4]>150 && Int(rgba[i*4])>Int(rgba[i*4+1])*2 && Int(rgba[i*4])>Int(rgba[i*4+2])*2 {bytes[i/8] |= UInt8(128>>(i%8));continue}; if Int(rgba[i*4])*299+Int(rgba[i*4+1])*587+Int(rgba[i*4+2])*114 >= 160000 { bytes[i/8] |= UInt8(128>>(i%8)) } }
        return Data(bytes)
    }
    static func savePNG(_ image:NSImage,to url:URL)throws {
        let raw=Data(try raster(image))
        guard let provider=CGDataProvider(data:raw as CFData),let cg=CGImage(width:800,height:480,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:3200,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent),let data=NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:]) else{return}
        try data.write(to:url)
    }

}
private struct Painter {
    let c:ScreenContent
    init(_ content:ScreenContent){c=content}
    var active:[DeskTask]{InformationLogic.ordered(c.tasks)}
    func text(_ value:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat=18,_ width:CGFloat=752,_ height:CGFloat=48,_ bold:Bool=false){
        let p=NSMutableParagraphStyle();p.lineBreakMode = height>50 ? .byWordWrapping:.byTruncatingTail
        (value as NSString).draw(in:NSRect(x:x,y:y,width:width,height:height),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:bold ? .semibold:.regular),.foregroundColor:NSColor.black,.paragraphStyle:p])
    }
    func rule(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ vertical:Bool=false){let p=NSBezierPath();p.lineWidth=1;p.move(to:NSPoint(x:x,y:y));p.line(to:NSPoint(x:vertical ? x:x+w,y:vertical ? y+w:y));NSColor.black.setStroke();p.stroke()}
    func outline(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat){NSColor.black.setStroke();NSBezierPath(rect:NSRect(x:x,y:y,width:w,height:h)).stroke()}
    func weatherIcon(_ x:CGFloat,_ y:CGFloat,_ code:Int,_ scale:CGFloat=1){
        NSColor.white.setFill();NSColor.black.setStroke()
        if code==0||code==1||code==2 { let p=NSBezierPath(ovalIn:NSRect(x:x+3*scale,y:y,width:18*scale,height:18*scale));p.lineWidth=1.5;p.stroke() }
        if code != 0 {
            for r in [NSRect(x:8,y:13,width:24,height:16),NSRect(x:18,y:7,width:22,height:22),NSRect(x:33,y:14,width:17,height:15)]{
                let p=NSBezierPath(ovalIn:NSRect(x:x+r.minX*scale,y:y+r.minY*scale,width:r.width*scale,height:r.height*scale));p.fill();p.stroke()
            }
            let body=NSRect(x:x+16*scale,y:y+19*scale,width:26*scale,height:10*scale);body.fill();rule(x+15*scale,y+29*scale,28*scale)
            if code>=51 { for i in 0..<3 {rule(x+20*scale+CGFloat(i)*9*scale,y+33*scale,5*scale,true)} }
        }
    }
    func weatherLine(_ x:CGFloat,_ y:CGFloat,_ width:CGFloat){
        guard let w=c.weather else{text(c.settings.city+" · 天气待更新",x,y,18,width);return}
        weatherIcon(x,y+4,w.code,0.8);text("\(c.settings.city) · \(w.text)",x+52,y,17,width-52)
        text(String(format:"%.0f°",w.temperature),x+52,y+25,30,width-52,40,true)
        if let day=w.days.first {text(String(format:"%.0f° / %.0f°",day.low,day.high),x+116,y+36,14,width-116)}
    }
    func header(){
        text(dateText(c.now,"HH:mm"),24,10,52,200,64,true)
        text(dateText(c.now,"MM月dd日  EEEE"),242,22,19,284)
        text(lunarText(c.now),242,52,14,284)
        weatherLine(548,14,228)
    }
    func stocks(){
        rule(24,422,752)
        for i in 0..<5 {
            let x:CGFloat=24+CGFloat(i)*152
            if i<c.quotes.count {let q=c.quotes[i];text(q.name,x,430,13,145,18);text(String(format:"%.2f",q.price),x,449,19,74,24,true);text(ScreenRenderer.stockMovement(q.percent),x+76,452,12,74,20,true)}
            else {text(i<c.settings.stocks.count ? c.settings.stocks[i]:"未配置",x,434,13,145);text("—",x,453,16,145)}
        }
        var time="待更新"
        if let stamp=c.quotes.map({$0.asOf}).min(),stamp.count==14 {
            let month=String(stamp.dropFirst(4).prefix(2)),day=String(stamp.dropFirst(6).prefix(2))
            let hour=String(stamp.dropFirst(8).prefix(2)),minute=String(stamp.dropFirst(10).prefix(2))
            time="\(month)/\(day) \(hour):\(minute)"
        }
        text("行情可能延迟 · "+time+"   天气 Open-Meteo   本周完成 \(InformationLogic.weekCount(c.tasks,at:c.now)) / \(c.settings.info.weeklyGoal) 项",24,470,8,752,10)
    }
    func todos(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ title:String="待办清单",_ timeline:Bool=false,_ limit:Int=6){
        text(title,x,y,23,w-70,32,true);text("\(active.count) 项",x+w-55,y+5,15,55)
        let count=min(limit,max(1,Int((h-42)/46)));let rowHeight=min(58,(h-(active.count>count ? 64:40))/CGFloat(count))
        for (i,task) in active.prefix(count).enumerated(){
            let top=y+42+CGFloat(i)*rowHeight
            let left=x+(timeline ? 84:24)
            if timeline {text(task.due.map{dateText($0,"HH:mm")} ?? "待定",x,top+1,17,76,30,true)} else{outline(x+1,top+5,10,10)}
            text((task.pinned == true ? "★ ":"")+task.title,left,top,19,w-(left-x),26,task.overdue)
            text(dueText(task),left,top+26,12,w-(left-x),18)
        }
        if active.isEmpty{text("没有未完成事项，留点时间给自己。",x+2,y+64,18,w,48)}
        if active.count>count{text("另有 \(active.count-count) 项，见 Mac 清单",x,y+h-14,11,w,16)}
    }
    func note(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ title:String,_ body:String){text(title,x,y,13,w,24);rule(x,y+27,w);text(body,x,y+41,19,w,h-41)}
    func forecast(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ compact:Bool=false){
        text("三日天气",x,y,compact ? 16:18,w,24,true)
        let offset:CGFloat=compact ? 27:35,row:CGFloat=compact ? 20:32
        for (i,day) in (c.weather?.days ?? []).prefix(3).enumerated(){let top=y+offset+CGFloat(i)*row
            text(["今天","明天","后天"][i],x,top,compact ? 12:14,40)
            weatherIcon(x+(compact ? 32:42),top-1,day.code,compact ? 0.35:0.48)
            text(String(format:"%.0f° / %.0f°",day.low,day.high),x+(compact ? 62:84),top,compact ? 13:16,w-(compact ? 62:84))
        }
        if c.weather==nil{text("联网后更新天气",x,y+44,15,w)}
    }
    func informationCards(_ x:CGFloat,_ width:CGFloat){
        let cards=c.settings.info.cards
        for slot in 0..<2 {
            let key=slot<cards.count ? cards[slot]:(slot==0 ? "nextEvent":"outdoor")
            let title:String,body:String
            switch key {
            case "nextEvent":title="下一场日程";body=c.nextEvent?.summary(at:c.now) ?? c.calendarStatus
            case "outdoor":title="出门天气";body=InformationLogic.outdoor(c.weather,at:c.now)
            case "countdown":title="重要的日子";body=InformationLogic.nearest(c.settings.info.dates,at:c.now).map{InformationLogic.countdown($0,at:c.now)} ?? "在 Mac 添加重要日期"
            case "week":title="本周进度";body="已完成 \(InformationLogic.weekCount(c.tasks,at:c.now)) 项\n本周目标 \(c.settings.info.weeklyGoal) 项"
            default:title="桌面小纸条";body=c.settings.note
            }
            note(x,slot==0 ? 120:266,width,136,title,body)
        }
    }
    func work(){
        header();let layout=c.settings.layout
        switch layout {
        case .focus:
            todos(24,118,500,284);rule(548,116,286,true)
            informationCards(572,204)
        case .agenda:
            todos(24,118,500,284,"今日安排",true,5);rule(548,116,286,true)
            informationCards(572,204)
        case .minimal:
            text("今天，只做重要的事。",24,116,15,752)
            for (i,t) in active.prefix(3).enumerated(){let y:CGFloat=160+CGFloat(i)*76;outline(28,y+9,14,14);text((t.pinned == true ? "★ ":"")+t.title,62,y,28,710,40,true);text(dueText(t),62,y+42,13,710)}
            if active.isEmpty{text("今天的留白，也很珍贵。",24,194,34,752,90,true)}
        case .overview:
            todos(24,118,478,284);rule(526,116,286,true)
            informationCards(550,226)
        case .pomodoro:
            todos(24,118,430,284,"专心做事",false,5);rule(478,116,286,true)
            text("专注时刻",510,120,18,266)
            let minutes=c.focusEnd.map{max(0,Int(ceil($0.timeIntervalSince(c.now)/60)))} ?? c.settings.focusMinutes
            text("\(minutes)",510,171,96,230,120,true);text("分钟",680,242,18,90)
            text(c.focusEnd == nil ? "在 Mac 开始一段专注":"专注进行中",510,302,17,260)
            text(active.first?.title ?? "为自己留一段不被打扰的时间",510,348,18,260,54)
        case .living:
            todos(24,118,478,284,"留给自己的小事",false,5);rule(526,116,286,true)
            text(dateText(c.now,"dd"),554,118,84,210,110,true);text(lunarText(c.now),554,228,19,220)
            note(554,281,222,122,"重要的日子",InformationLogic.nearest(c.settings.info.dates,at:c.now).map{InformationLogic.countdown($0,at:c.now)} ?? c.settings.note)
        case .custom:
            let width=(752*c.settings.customRatio/8).rounded(.down)*8
            todos(24,118,width-24,338,"我的待办",false,7);rule(24+width,116,340,true)
            let x=48+width,w=728-width;let count=max(1,c.settings.customModules.count);let height=338/CGFloat(count)
            for (i,module) in c.settings.customModules.enumerated(){let y:CGFloat=118+CGFloat(i)*height
                switch module {case "weather":forecast(x,y,w,true);case "stocks":
                    text("自选行情",x,y,15,w)
                    if c.quotes.isEmpty {text("等待行情数据",x,y+28,12,w)}
                    for (j,q) in c.quotes.prefix(5).enumerated(){text(q.name+" "+ScreenRenderer.stockMovement(q.percent),x,y+26+CGFloat(j)*13,11,w)}
                default:note(x,y,w,height-8,"桌面小纸条",c.settings.note)}
            }
        }
        if c.settings.layout != .custom { stocks() }
    }
    func calendar(){
        text("下班之后",24,19,26,420,40,true);text("把时间，还给生活。",24,58,15,420)
        text(dateText(c.now,"HH:mm"),650,24,32,126,50,true)
        text(dateText(c.now,"yyyy年 M月"),24,121,21,270)
        text(dateText(c.now,"dd"),18,160,112,284,138,true)
        text(lunarText(c.now),24,307,22,270)
        text(dateText(c.now,"EEEE"),24,347,20,270)
        weatherLine(24,405,280)
        rule(316,118,344,true)
        text(dateText(c.now,"yyyy / MM"),346,116,24,430,40,true)
        var cal=Calendar(identifier:.gregorian);cal.timeZone=TimeZone(identifier:"Asia/Shanghai")!;let components=cal.dateComponents([.year,.month],from:c.now);let first=cal.date(from:components)!;let offset=(cal.component(.weekday,from:first)+5)%7;let days=cal.range(of:.day,in:.month,for:first)!
        for (i,day) in ["一","二","三","四","五","六","日"].enumerated(){text(day,346+CGFloat(i)*62,163,15,58)}
        for day in days {let position=offset+day-1;let x=346+CGFloat(position%7)*62;let y=202+CGFloat(position/7)*35
            if day==cal.component(.day,from:c.now){outline(x-6,y-3,43,31)}
            text("\(day)",x,y,18,50,23,day==cal.component(.day,from:c.now))
            if let date=cal.date(byAdding:.day,value:day-1,to:first),let marker=CalendarData.marker(date){text(marker,x+28,y+4,8,16,16)}
        }
        rule(346,425,430);text(InformationLogic.nearest(c.settings.info.dates,at:c.now).map{InformationLogic.countdown($0,at:c.now).replacingOccurrences(of:"\n",with:" · ")} ?? CalendarData.nextTerm(c.now) ?? c.settings.note,346,441,17,430,34)
    }
}
