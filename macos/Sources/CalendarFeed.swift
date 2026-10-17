import Foundation
import EventKit

@MainActor final class CalendarFeed {
    private let events=EKEventStore()
    var choices:[(id:String,title:String)] {
        guard EKEventStore.authorizationStatus(for:.event) == .fullAccess else{return []}
        return events.calendars(for:.event).map{($0.calendarIdentifier,$0.title)}.sorted{$0.title<$1.title}
    }
    func request()async throws->Bool {try await events.requestFullAccessToEvents()}
    func next(ids:[String],at now:Date)->NextCalendarEvent? {
        guard EKEventStore.authorizationStatus(for:.event) == .fullAccess,!ids.isEmpty else{return nil}
        let selected=events.calendars(for:.event).filter{ids.contains($0.calendarIdentifier)}
        guard !selected.isEmpty else{return nil}
        let predicate=events.predicateForEvents(withStart:WorkSchedule.calendar.startOfDay(for:now),end:now.addingTimeInterval(7*86400),calendars:selected)
        let found=events.events(matching:predicate).filter{$0.endDate>now && $0.status != .canceled}.sorted {
            if $0.isAllDay != $1.isAllDay{return !$0.isAllDay}
            return $0.startDate<$1.startDate
        }
        return found.first.map{NextCalendarEvent(title:$0.title ?? "未命名日程",start:$0.startDate,end:$0.endDate,location:$0.location ?? "",allDay:$0.isAllDay)}
    }
    var authorized:Bool {EKEventStore.authorizationStatus(for:.event) == .fullAccess}
}
