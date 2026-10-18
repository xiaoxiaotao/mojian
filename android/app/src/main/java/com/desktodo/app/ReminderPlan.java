package com.desktodo.app;
import org.json.*;import java.time.Instant;import java.util.Set;
/** Pure alarm plan so cancellation, deadline changes and restart dedupe are testable. */
final class ReminderPlan {
 static JSONObject build(JSONArray tasks,JSONObject settings,long now,Set<String> sent)throws Exception{
  JSONObject records=new JSONObject();if(!settings.optBoolean("enabled"))return records;
  for(int n=0;n<tasks.length();n++){JSONObject t=tasks.getJSONObject(n);if(t.isNull("due")||t.optString("due").isEmpty())continue;long due;try{due=Instant.parse(t.getString("due")).toEpochMilli();}catch(Exception ignored){continue;}for(boolean before:new boolean[]{true,false}){String key=DeskModel.contentKey(t.getString("id")+"|"+due+"|"+before);if(sent.contains(key))continue;long at=ReminderPolicy.next(due,now,before,settings.optBoolean("quietEnabled"),settings.optInt("quietStart"),settings.optInt("quietEnd"));if(at>=0)records.put(key,new JSONObject().put("id",t.getString("id")).put("due",due).put("before",before).put("at",at));}}
  return records;
 }
}
