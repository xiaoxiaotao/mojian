package com.desktodo.app;
import java.time.*;
final class ReminderPolicy {
 static long next(long due,long now,boolean before,boolean quiet,int start,int end){
  long at=before?due-600000:due;if(before&&now>=due||!before&&now-due>86400000)return -1;at=Math.max(at,now+1000);
  if(quiet&&start!=end){ZoneId zone=ZoneId.of("Asia/Shanghai");ZonedDateTime z=Instant.ofEpochMilli(at).atZone(zone);int h=z.getHour();boolean inside=start<end?h>=start&&h<end:h>=start||h<end;if(inside){ZonedDateTime target=z.toLocalDate().atTime(end,0).atZone(zone);if(!target.isAfter(z))target=target.plusDays(1);at=target.toInstant().toEpochMilli();}}
  return before&&at>=due||at-due>86400000?-1:at;
 }
}
