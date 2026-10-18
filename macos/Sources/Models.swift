import Foundation
import AppKit
import Security
import LocalAuthentication

struct DeskTask: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var title: String
    var due: Date?
    var done = false
    var completedAt: Date?
    var pinned:Bool? = nil
    var repeatRule:String? = nil
    var repeatSeries:String? = nil
    var repeatDay:Int? = nil
    var nextID:String? = nil
    var nextKey:String? = nil
    var skipped:Bool? = nil
    var overdue: Bool { !done && (due.map { $0 < Date() } ?? false) }
}
enum DeskLayout: String, Codable, CaseIterable, Identifiable {
    case focus, agenda, minimal, overview, pomodoro, living, custom
    var id: String { rawValue }
    var title: String { switch self { case .focus: "专注办公"; case .agenda: "今日安排"; case .minimal: "极简桌面"; case .overview: "信息总览"; case .pomodoro: "专注计时"; case .living: "生活陪伴"; case .custom: "我的布局" } }
    var subtitle: String { switch self { case .focus: "让重要的事，占据更多空间"; case .agenda: "按时间，轻松安排一天"; case .minimal: "少一点干扰，多一点从容"; case .overview: "待办、天气与提醒，一眼看清"; case .pomodoro: "一次，只专心做好一件事"; case .living: "工作之外，也关照生活"; case .custom: "按你的习惯，组合每一块" } }
    var symbol: String { switch self { case .focus: "checklist"; case .agenda: "calendar.day.timeline.left"; case .minimal: "rectangle"; case .overview: "square.grid.2x2"; case .pomodoro: "timer"; case .living: "leaf"; case .custom: "slider.horizontal.3" } }
}
struct Preferences: Codable, Equatable {
    var deviceURL = ""
    var layout: DeskLayout = .focus
    var city = "苏州"
    var latitude = 31.30
    var longitude = 120.58
    var stocks = ["sh600737","sz002714","sh603893","sz002273","sh688234"]
    var scheduleEnabled = false
    var respectHolidays = true
    var startMinute = 9 * 60
    var endMinute = 18 * 60
    var weekdays = [2,3,4,5,6]
    var notifications = false
    var autoSync = false
    var deepSeekModel = "deepseek-flash"
    var homeAddress = ""
    var workAddress = ""
    var commuteBuffer = 15
    var note = "把注意力，留给真正重要的事。"
    var customRatio = 0.67
    var customModules = ["weather","stocks","note"]
    var focusMinutes = 25
    var information:InformationSettings? = nil
}
struct DayForecast: Codable, Identifiable {
    var id: String { date }
    var date: String; var low: Double; var high: Double; var code: Int
}
struct WeatherSnapshot: Codable {
    var temperature: Double; var code: Int; var days: [DayForecast]; var fetched: Date
    var hours:[HourForecast]? = nil
    var text: String { weatherName(code) }
}
struct StockQuote: Codable, Identifiable {
    var id: String { code }
    var code: String; var name: String; var price: Double; var change: Double; var percent: Double; var asOf: String
}
struct CommuteSnapshot: Codable {
    var minutes: Int; var fetched: Date
    var trafficSummary: String? = nil
    var distanceKM: Double? = nil
    var text: String { "驾车约 \(minutes) 分钟" }
}
struct SavedState: Codable {
    var tasks: [DeskTask] = []
    var settings = Preferences()
    var weather: WeatherSnapshot?
    var quotes: [StockQuote] = []
    var afterHours = false
}
struct AssistantLine: Identifiable, Codable {
    var id = UUID(); var user: Bool; var text: String
}
func weatherName(_ code: Int) -> String {
    switch code { case 0: "晴"; case 1,2: "多云"; case 3: "阴"; case 45,48: "雾"; case 51...67,80...82: "雨"; case 71...77,85,86: "雪"; case 95...99: "雷雨"; default: "天气未知" }
}
func dateText(_ date: Date, _ format: String) -> String {
    let formatter=DateFormatter();formatter.locale=Locale(identifier:"zh_CN");formatter.timeZone=TimeZone(identifier:"Asia/Shanghai");formatter.dateFormat=format;return formatter.string(from:date)
}
func lunarText(_ date: Date) -> String {
    var calendar=Calendar(identifier:.chinese);calendar.timeZone=TimeZone(identifier:"Asia/Shanghai")!
    let c=calendar.dateComponents([.month,.day,.isLeapMonth],from:date)
    let months=["正月","二月","三月","四月","五月","六月","七月","八月","九月","十月","冬月","腊月"]
    let days=["初一","初二","初三","初四","初五","初六","初七","初八","初九","初十","十一","十二","十三","十四","十五","十六","十七","十八","十九","二十","廿一","廿二","廿三","廿四","廿五","廿六","廿七","廿八","廿九","三十"]
    return "农历"+(c.isLeapMonth == true ? "闰":"")+months[max(0,min(11,(c.month ?? 1)-1))]+days[max(0,min(29,(c.day ?? 1)-1))]
}

func dueText(_ task: DeskTask) -> String {
    guard let due=task.due else { return "随时完成" }
    return (task.overdue ? "已逾期 · " : "") + dateText(due,"MM/dd HH:mm")
}
enum Vault {
    static let service="com.desktodo.mac.credentials"
    static func get(_ account: String,interactive:Bool=false) -> String {
        let context=LAContext();context.interactionNotAllowed = !interactive
        let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne,kSecUseAuthenticationContext as String:context]
        var result:CFTypeRef?;guard SecItemCopyMatching(query as CFDictionary,&result)==errSecSuccess,let data=result as? Data else{return ""};return String(data:data,encoding:.utf8) ?? ""
    }
    @discardableResult static func put(_ account:String,_ value:String)->Bool {
        let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account]
        if value.isEmpty { return true }
        let data=Data(value.utf8)
        let status=SecItemUpdate(query as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if status==errSecItemNotFound { var item=query;item[kSecValueData as String]=data;return SecItemAdd(item as CFDictionary,nil)==errSecSuccess }
        return status==errSecSuccess
    }
}
struct DeskError: LocalizedError { var message:String;var errorDescription:String?{message} }
func parseISODate(_ value:String)->Date? {
    let f=ISO8601DateFormatter();if let date=f.date(from:value){return date};f.formatOptions=[.withInternetDateTime,.withFractionalSeconds];return f.date(from:value)
}
