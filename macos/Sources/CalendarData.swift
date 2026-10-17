import Foundation
// 2026 dates: State Council notice (2025-11-04); solar terms: Hong Kong Observatory.
// Other years intentionally have no fabricated official holiday/solar-term dates.
enum CalendarData {
    static let holidays:[(String,String,String)]=[("2026-01-01","2026-01-03","元旦"),("2026-02-15","2026-02-23","春节"),("2026-04-04","2026-04-06","清明"),("2026-05-01","2026-05-05","劳动节"),("2026-06-19","2026-06-21","端午"),("2026-09-25","2026-09-27","中秋"),("2026-10-01","2026-10-07","国庆")]
    static let adjusted:Set<String>=["2026-01-04","2026-02-14","2026-02-28","2026-05-09","2026-09-20","2026-10-10"]
    static let terms:[(String,String)]=[("01-05","小寒"),("01-20","大寒"),("02-04","立春"),("02-18","雨水"),("03-05","惊蛰"),("03-20","春分"),("04-05","清明"),("04-20","谷雨"),("05-05","立夏"),("05-21","小满"),("06-05","芒种"),("06-21","夏至"),("07-07","小暑"),("07-23","大暑"),("08-07","立秋"),("08-23","处暑"),("09-07","白露"),("09-23","秋分"),("10-08","寒露"),("10-23","霜降"),("11-07","立冬"),("11-22","小雪"),("12-07","大雪"),("12-22","冬至")]
    static func holiday(_ date:Date)->String? {let key=dateText(date,"yyyy-MM-dd");return holidays.first{key >= $0.0 && key <= $0.1}?.2}
    static func marker(_ date:Date)->String? {let key=dateText(date,"yyyy-MM-dd");if adjusted.contains(key){return "班"};if holiday(date) != nil{return "休"};return nil}
    static func nextTerm(_ date:Date)->String? {guard dateText(date,"yyyy")=="2026" else{return nil};let key=dateText(date,"MM-dd");return terms.first{$0.0>=key}.map{$0.1+" · "+$0.0.replacingOccurrences(of:"-",with:"月")+"日"}}
    static func workday(_ date:Date,_ p:Preferences)->Bool {if p.respectHolidays {let key=dateText(date,"yyyy-MM-dd");if adjusted.contains(key){return true};if holiday(date) != nil{return false}};return p.weekdays.contains(WorkSchedule.calendar.component(.weekday,from:date))}
}
