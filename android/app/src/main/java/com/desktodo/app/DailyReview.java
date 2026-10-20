package com.desktodo.app;
import android.content.*;import android.widget.*;import org.json.*;import java.time.*;import java.time.format.DateTimeFormatter;import java.util.*;
/** Local, deterministic end-of-day review. No task mutations, network or model calls. */
final class DailyReview {
 static final String[] TITLES={"今日完成记录","已逾期","今天稍后","明日到期","未设截止","更晚安排"};
 final List<List<JSONObject>> groups=new ArrayList<>();
 DailyReview(JSONArray active,JSONArray history,Instant now){
  for(int i=0;i<6;i++)groups.add(new ArrayList<>());Instant start=now.atZone(ScreenData.ZONE).toLocalDate().atStartOfDay(ScreenData.ZONE).toInstant(),next=start.atZone(ScreenData.ZONE).plusDays(1).toInstant(),end=start.atZone(ScreenData.ZONE).plusDays(2).toInstant();Set<String> seen=new HashSet<>();
  for(int i=0;i<active.length();i++){JSONObject t=active.optJSONObject(i);if(t==null||!seen.add(t.optString("id")))continue;Instant due=instant(t.optString("due"));if(due==null)groups.get(4).add(t);else groups.get(due.isBefore(now)?1:due.isBefore(next)?2:due.isBefore(end)?3:5).add(t);}
  for(int i=history.length()-1;i>=0;i--){JSONObject t=history.optJSONObject(i);if(t==null||!seen.add(t.optString("id"))||!t.optString("recordType").equals("completed"))continue;Instant done=instant(t.optString("completedAt"));if(done==null||done.isBefore(start)||done.isAfter(now))continue;groups.get(0).add(t);}
  for(int n=1;n<6;n++)groups.get(n).sort(Comparator.comparing((JSONObject t)->{Instant d=instant(t.optString("due"));return d==null?Instant.MAX:d;}).thenComparing(t->t.optString("id")));
 }
 static Instant instant(String value){try{return Instant.parse(value);}catch(Exception e){return null;}}
 static String stamp(Instant time){return DateTimeFormatter.ofPattern("MM/dd HH:mm").withZone(ScreenData.ZONE).format(time);}
 String text(Instant now){StringBuilder s=new StringBuilder("每日收尾 · "+stamp(now)+"\n按北京时间、本机保留记录整理；未更改任何事项。\n");for(int i=0;i<groups.size();i++){s.append("\n").append(TITLES[i]).append(" · ").append(groups.get(i).size()).append(" 项\n");for(JSONObject t:groups.get(i)){s.append("• ").append(t.optString("title"));Instant due=instant(t.optString("due"));if(due!=null)s.append(" · ").append(stamp(due));s.append("\n");}}return s.toString();}
 static void render(MainActivity a){Instant now=Instant.now();DailyReview review=new DailyReview(a.tasks,a.history,now);LinearLayout intro=a.card("收好今天，给明天留一点从容");intro.addView(a.text("截至 "+stamp(now)+" · 北京时间 · 本机保留记录",14,a.muted));a.button(intro,"重新整理本机记录",a::draw);if(a.dirty||a.screenPending)intro.addView(a.text("有内容待同步，以下为本机记录，可能与屏幕不同。",14,AppUi.DANGER));
  for(int i=0;i<review.groups.size();i++){List<JSONObject> tasks=review.groups.get(i);LinearLayout card=a.card(TITLES[i]+" · "+tasks.size()+" 项");if(tasks.isEmpty())card.addView(a.text("暂无事项",14,a.muted));for(JSONObject t:tasks){TextView title=a.text(t.optString("title"),17,a.ink);title.setTextIsSelectable(true);card.addView(title);Instant due=instant(t.optString("due"));if(due!=null)card.addView(a.text(stamp(due),13,a.muted));}}
  a.body.addView(a.text("只读整理，不会自动改期、完成、通知或切换屏幕。历史裁剪、删除或其他端未同步的记录可能不在此处。",13,a.muted));a.primary(a.dock,"复制本机收尾摘要",()->{ClipboardManager clipboard=(ClipboardManager)a.getSystemService(Context.CLIPBOARD_SERVICE);clipboard.setPrimaryClip(ClipData.newPlainText("墨间每日收尾",review.text(now)));a.toast("已复制到剪贴板");});
 }
}
