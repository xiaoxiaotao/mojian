package com.desktodo.app;
import org.json.*;
import java.util.*;
import java.time.*;
import java.time.format.DateTimeFormatter;

final class DeskModel {
 static JSONObject copy(JSONObject j){try{return new JSONObject(j.toString());}catch(Exception e){throw new IllegalArgumentException(e);}}
 static JSONArray copy(JSONArray j){try{return new JSONArray(j.toString());}catch(Exception e){throw new IllegalArgumentException(e);}}
 static JSONObject task(String title,String due)throws Exception{return new JSONObject().put("id",UUID.randomUUID().toString()).put("title",title).put("due",due==null?JSONObject.NULL:due).put("pinned",false);}
 static JSONArray ordered(JSONArray a)throws Exception{List<JSONObject> v=new ArrayList<>();for(int i=0;i<a.length();i++)v.add(a.getJSONObject(i));v.sort((x,y)->Boolean.compare(y.optBoolean("pinned"),x.optBoolean("pinned")));return new JSONArray(v);}
 static int pins(JSONArray a){int n=0;for(int i=0;i<a.length();i++)if(a.optJSONObject(i).optBoolean("pinned"))n++;return n;}
 static String due(JSONObject t){String s=t.optString("due","");if(s.isEmpty()||s.equals("null"))return "未设截止时间";try{Instant d=Instant.parse(s);return (d.isBefore(Instant.now())?"已逾期 · ":"")+DateTimeFormatter.ofPattern("MM/dd HH:mm").withZone(ZoneId.of("Asia/Shanghai")).format(d);}catch(Exception e){return "截止时间待确认";}}
 static boolean overdue(JSONObject t){try{return Instant.parse(t.getString("due")).isBefore(Instant.now());}catch(Exception e){return false;}}
 static String movement(double p){return p==0?"— 0.00%":(p>0?"▲ ":"▼ ")+String.format(Locale.US,"%+.2f%%",p);}
 static String normalizeOrigin(String value)throws Exception{android.net.Uri u=android.net.Uri.parse(value.trim());if(!Arrays.asList("http","https").contains(u.getScheme())||u.getHost()==null||u.getUserInfo()!=null||u.getQuery()!=null||u.getFragment()!=null)throw new Exception("请填写有效的设备地址，如 http://192.168.1.20");return u.getScheme()+"://"+u.getAuthority();}
 static JSONArray symbols(String text)throws Exception{JSONArray a=new JSONArray();Set<String> seen=new HashSet<>();for(String raw:text.trim().split("[,，\\s]+")){if(raw.isEmpty())continue;String s=raw.trim();if(!s.matches("(sh|sz|bj)[0-9]{6}|hk[0-9]{5}|us[A-Z][A-Z0-9.]{0,9}"))throw new Exception("代码格式如 sh600519、sz000001、hk00700、usAAPL");if(!seen.add(s))throw new Exception("股票代码不能重复");a.put(s);}if(a.length()>5)throw new Exception("最多五支股票");return a;}
 static String layoutId(JSONObject cfg){String k=cfg.optString("layout","overview");String id="mac."+k+".red-v2";if(k.equals("custom"))id+="."+cfg.optInt("ratio",67)+".weather-stocks-note";return id+".phone";}
 static String kind(String id)throws Exception{String[] p=id.split("\\.");if(p.length<3||!p[0].equals("mac")||!Arrays.asList("focus","agenda","minimal","overview","pomodoro","living","custom","calendar").contains(p[1]))throw new Exception("设备布局无法识别，请选择布局并明确应用");return p[1];}
 static String contentKey(String value)throws Exception{byte[] bytes=java.security.MessageDigest.getInstance("SHA-256").digest(value.getBytes(java.nio.charset.StandardCharsets.UTF_8));StringBuilder s=new StringBuilder();for(byte b:bytes)s.append(String.format(Locale.US,"%02x",b&255));return s.toString();}
 static String updatedTime(long millis){return millis<=0?"暂无记录":DateTimeFormatter.ofPattern("MM/dd HH:mm").withZone(ZoneId.of("Asia/Shanghai")).format(Instant.ofEpochMilli(millis));}
 static String quoteTime(String stamp){if(!stamp.matches("[0-9]{14}"))return "待确认";return stamp.substring(4,6)+"/"+stamp.substring(6,8)+" "+stamp.substring(8,10)+":"+stamp.substring(10,12);}
 static JSONObject defaults() {try{return new JSONObject().put("layout","overview").put("ratio",67).put("city","苏州").put("latitude",31.30).put("longitude",120.58).put("stocks",new JSONArray()).put("stockConfigured",false).put("note","把重要的事情，留在眼前。").put("weeklyGoal",20).put("card1","week").put("card2","outdoor").put("cardsVersion",0).put("scene","work").put("dates",new JSONArray()).put("focusMinutes",25).put("deskStatus","专注中").put("statusNote","请稍后联系");}catch(Exception e){throw new RuntimeException(e);}}
}
