import AppKit

// Fictional off-screen fixtures only. Never reads state, network or screen.
@MainActor enum ReadabilityTest {
    static func run(){
        let args=ProcessInfo.processInfo.arguments
        let directory=URL(fileURLWithPath:args.last=="--readability-test" ? "/tmp/mojian-readability":args.last!)
        try! FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let now=ISO8601DateFormatter().date(from:"2026-10-29T09:30:00+08:00")!
        let titles=["整理产品需求与质量检查","确认客户的设计方案和交付日期","量、赢、警：复杂汉字清晰度","记得喝水，休息一下眼睛","这是一条很长的测试事项，应该省略而不是挤到其他模块"]
        let tasks=titles.enumerated().map{DeskTask(title:$0.element,due:now.addingTimeInterval(Double($0.offset-1)*3600))}
        let names=["示例甲","示例乙","示例丙","示例长名称测试","示例戊"]
        let changes=[4.77,-9.99,0,123.45,-0.01]
        let quotes=names.enumerated().map{StockQuote(code:"fixture-\($0.offset)",name:$0.element,price:[1234.56,9.87,500000.99,18.76,2.34][$0.offset],change:0,percent:changes[$0.offset],asOf:"20261029093000")}
        let weather=WeatherSnapshot(temperature:22,code:2,days:[DayForecast(date:"2026-10-29",low:18,high:25,code:2),DayForecast(date:"2026-10-30",low:17,high:23,code:61),DayForecast(date:"2026-10-31",low:16,high:22,code:0)],fetched:now)
        func ink(_ frame:Data,_ x:Int,_ y:Int,_ w:Int,_ h:Int)->Int {
            var count=0
            for yy in y..<y+h{for xx in x..<x+w{if frame[yy*100+xx/8] & UInt8(128>>(xx%8))==0{count+=1}}}
            return count
        }
        for layout in DeskLayout.allCases {
            var settings=Preferences();settings.layout=layout;settings.info.cards=["week","outdoor"]
            let content=ScreenContent(tasks:tasks,settings:settings,weather:weather,quotes:quotes,now:now)
            let image=ScreenRenderer.render(content,accent:false),frame=try! ScreenRenderer.bitmap(image)
            precondition(frame.count==48000 && frame[8000..<10400].allSatisfy{$0==255})
            if layout != .custom {
                for column in 0..<5 {
                    let x=24+column*152
                    precondition(ink(frame,x,423,145,18)>30,"Stock name missing")
                    precondition(ink(frame,x,441,145,19)>30,"Stock price missing")
                    precondition(ink(frame,x+16,460,129,20)>20,"Signed percentage missing")
                    precondition(ink(frame,x,465,10,10)>8,"Vector direction missing")
                }
                precondition(ink(frame,24,465,10,3)<ink(frame,24,472,10,3),"Up triangle points up")
                precondition(ink(frame,176,465,10,3)>ink(frame,176,472,10,3),"Down triangle points down")
            }
            for threshold in [160,168,176] {
                let bytes=try! ScreenRenderer.bitmap(image,threshold:threshold)
                try! saveFrame(bytes,to:directory.appendingPathComponent("\(layout.rawValue)-\(threshold).png"))
            }
        }
        var settings=Preferences();settings.info.artwork=true
        let calendar=ScreenContent(tasks:[],settings:settings,weather:weather,quotes:quotes,now:now,afterHours:true)
        try! saveFrame(ScreenRenderer.blackFrame(calendar),to:directory.appendingPathComponent("calendar-168.png"))
        // At the narrowest supported Mac column, changing only the name must
        // never change any direction or percentage pixels in the reserved area.
        var narrow=Preferences();narrow.layout = .custom;narrow.customRatio=0.78
        var longQuotes=quotes;longQuotes[0].name="中远海运控股超长名称用于测试"
        let narrowContent=ScreenContent(tasks:tasks,settings:narrow,weather:weather,quotes:longQuotes,now:now)
        let narrowFrame=try! ScreenRenderer.blackFrame(narrowContent)
        var emptyQuotes=longQuotes;emptyQuotes[0].name=""
        let emptyFrame=try! ScreenRenderer.blackFrame(ScreenContent(tasks:tasks,settings:narrow,weather:weather,quotes:emptyQuotes,now:now))
        for y in 253..<271{for x in 688..<776{let bit=UInt8(128>>(x%8));precondition(narrowFrame[y*100+x/8]&bit==emptyFrame[y*100+x/8]&bit,"Name cannot obscure movement")}}
        precondition(ink(narrowFrame,704,253,72,18)>20)
        try! saveFrame(narrowFrame,to:directory.appendingPathComponent("custom-narrow.png"))
        var notes=Preferences();notes.layout = .overview;notes.info.cards=["note","note"];notes.note=String(repeating:"请确认客户的交付安排和文档，检查所有信息。",count:5)
        let longNote=try! ScreenRenderer.blackFrame(ScreenContent(tasks:[],settings:notes,weather:weather,quotes:quotes,now:now))
        notes.note=""
        let blankNote=try! ScreenRenderer.blackFrame(ScreenContent(tasks:[],settings:notes,weather:weather,quotes:quotes,now:now))
        precondition(ink(longNote,550,215,226,35)>20,"Third body line visible")
        for y in 0..<480{for x in 0..<800 where !(x>=550 && x<776 && ((y>=161 && y<256)||(y>=307 && y<402))){let bit=UInt8(128>>(x%8));precondition(longNote[y*100+x/8]&bit==blankNote[y*100+x/8]&bit,"Paragraph stays inside body")}}
        try! saveFrame(longNote,to:directory.appendingPathComponent("long-cards.png"))
        let sixRows=ScreenContent(tasks:[],settings:settings,weather:weather,quotes:[],now:ISO8601DateFormatter().date(from:"2026-11-30T09:30:00+08:00")!,afterHours:true)
        let calendarSix=try! ScreenRenderer.blackFrame(sixRows)
        precondition(ink(calendarSix,346,400,430,23)>40 && ink(calendarSix,346,423,430,1)==0,"Six calendar rows clear footer")
        try! saveFrame(calendarSix,to:directory.appendingPathComponent("calendar-six-rows.png"))
        print("PASS: all layouts, five stock names/prices/signed movements, vector arrow direction, narrow-name isolation, paragraph bounds, six-week calendar, red reserve; 1-bit threshold previews exported")
    }
    static func saveFrame(_ bytes:Data,to url:URL)throws {
        guard let provider=CGDataProvider(data:bytes as CFData),let image=CGImage(width:800,height:480,bitsPerComponent:1,bitsPerPixel:1,bytesPerRow:100,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGBitmapInfo(rawValue:0),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent),let png=NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:]) else{throw DeskError(message:"无法保存黑白测试画面")}
        try png.write(to:url)
    }
}
