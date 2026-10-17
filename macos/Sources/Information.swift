import Foundation

struct ImportantDate:Codable,Identifiable,Equatable {
    var id=UUID();var title:String;var date:Date
}
struct InformationSettings:Codable,Equatable {
    var dates:[ImportantDate]=[]
    var weeklyGoal=20
    var cards=["nextEvent","outdoor"]
    var calendarEnabled=false
    var calendarIDs:[String]=[]
}
extension Preferences {
    var info:InformationSettings {get{information ?? InformationSettings()}set{information=newValue}}
}
struct HourForecast:Codable {
    var time:Date;var rainProbability:Double?;var apparent:Double?;var wind:Double?
}
struct NextCalendarEvent:Equatable {
    var title:String;var start:Date;var end:Date;var location:String;var allDay:Bool
    func summary(at now:Date)->String {
        let when:String
        if allDay{when=dateText(start,"MM/dd")+" 全天"}
        else if start<=now{when="进行中 · "+dateText(end,"HH:mm")+"结束"}
        else if WorkSchedule.calendar.isDate(start,inSameDayAs:now){when=dateText(start,"HH:mm")+" · 还有\(Int(ceil(start.timeIntervalSince(now)/60)))分钟"}
        else{when=dateText(start,"MM/dd HH:mm")}
        return when+"\n"+title+(location.isEmpty ? "":"\n"+location)
    }
}
enum InformationLogic {
    static func ordered(_ tasks:[DeskTask])->[DeskTask] {
        tasks.filter{!$0.done}.sorted {a,b in
            if (a.pinned ?? false) != (b.pinned ?? false){return a.pinned ?? false}
            if a.due != b.due{return (a.due ?? .distantFuture)<(b.due ?? .distantFuture)}
            return false
        }
    }
    static func weekCount(_ tasks:[DeskTask],at now:Date)->Int {
        var cal=WorkSchedule.calendar;cal.firstWeekday=2;cal.minimumDaysInFirstWeek=4
        guard let interval=cal.dateInterval(of:.weekOfYear,for:now) else{return 0}
        return tasks.filter{$0.done && $0.completedAt.map{$0>=interval.start && $0<interval.end && $0<=now} == true}.count
    }
    static func countdown(_ item:ImportantDate,at now:Date)->String {
        let cal=WorkSchedule.calendar
        let days=cal.dateComponents([.day],from:cal.startOfDay(for:now),to:cal.startOfDay(for:item.date)).day ?? 0
        return item.title+"\n"+(days==0 ? "就是今天":days>0 ? "还有 \(days) 天":"已过 \(-days) 天")
    }
    static func nearest(_ dates:[ImportantDate],at now:Date)->ImportantDate? {
        let today=WorkSchedule.calendar.startOfDay(for:now)
        return dates.filter{$0.date>=today}.min{$0.date<$1.date} ?? dates.max{$0.date<$1.date}
    }
    static func outdoor(_ weather:WeatherSnapshot?,at now:Date)->String {
        guard let w=weather else{return "天气暂不可用"}
        guard now.timeIntervalSince(w.fetched)<3600 else{return "天气已过期，联网后更新"}
        let hours=(w.hours ?? []).filter{$0.time>=now.addingTimeInterval(-1800) && $0.time<now.addingTimeInterval(10800)}
        guard !hours.isEmpty else{return "逐小时预报待更新"}
        var lines:[String]=[]
        if let rain=hours.compactMap({$0.rainProbability}).max(){lines.append("3小时降雨最高\(Int(rain.rounded()))%");if rain>=60{lines.append("出门记得带伞")}}
        var details:[String]=[]
        if let feel=hours.first?.apparent{details.append("体感\(Int(feel.rounded()))℃")}
        if let wind=hours.compactMap({$0.wind}).max(),wind>=8{details.append(String(format:"风%.0f m/s",wind))}
        if !details.isEmpty{lines.append(details.joined(separator:" · "))}
        return lines.isEmpty ? "逐小时数据不完整":lines.joined(separator:"\n")
    }
}
