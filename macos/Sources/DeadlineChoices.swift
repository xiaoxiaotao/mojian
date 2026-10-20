import Foundation
struct DeadlineChoices {
 static func hourAfter(_ now:Date)->Date {now.addingTimeInterval(3600)}
 static func tomorrowMorning(_ now:Date)->Date {
  let cal=WorkSchedule.calendar
  return cal.date(bySettingHour:9,minute:0,second:0,of:cal.date(byAdding:.day,value:1,to:now)!)!
 }
}
