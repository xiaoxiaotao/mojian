package com.desktodo.app;
import android.widget.*;import org.json.*;import java.util.*;
/** Observes existing receipts/caches. Opening this page never imports tasks or writes a frame. */
final class DataHealth {
 final MainActivity a;long lastContact=0,lastReceipt=0;String contactOrigin="",receiptOrigin="";boolean weatherFailed=false,stocksFailed=false,commuteFailed=false;
 DataHealth(MainActivity a){this.a=a;}
 void contacted(String origin){contactOrigin=origin;lastContact=System.currentTimeMillis();}
 void received(String origin){receiptOrigin=origin;lastReceipt=System.currentTimeMillis();}
 long receipt(){return a.origin.equals(receiptOrigin)?lastReceipt:0;}
 static String freshness(long fetched,long now,long ttl,boolean failed){if(fetched<=0)return failed?"更新失败 · 暂无缓存":"尚无数据";long age=now-fetched;if(age< -300000)return "时间异常 · 请核对系统时间";if(age>=ttl)return failed?"更新失败 · 缓存已过期":"缓存已过期";return failed?"更新失败 · 使用上次缓存":"缓存可用";}
 static String connection(String origin,String observed,long contact,long now){if(origin.isEmpty())return "尚未配置设备";if(!origin.equals(observed)||contact<=0)return "本次启动尚未确认连接";long age=now-contact;return age< -300000?"时间异常 · 连接待确认":age>20000?"连接待确认":"设备可访问";}
 String syncTitle(){if(a.busy)return "操作进行中";if(a.resolvingConflict||!a.automaticRetryAllowed&&(a.dirty||a.screenPending))return "有冲突或待核对内容";if(a.remote!=null&&a.remote.optBoolean("needs_full"))return "需要明确应用布局";if(a.dirty||a.screenPending)return "本机有内容待同步";if(a.remote==null||a.base==null)return "尚未读取设备基准";return receipt()==0?"已读取设备 · 尚无发送回执":"已有发送回执";}
 String stamp(long value,String label){return label+"："+(value<=0?"本次尚无记录":DeskModel.updatedTime(value));}
 void row(String title,String status,String detail,String button,Runnable run){LinearLayout card=a.card(title);card.addView(a.text(status,20,a.ink));card.addView(a.text(detail,13,a.muted));a.button(card,button,run);}
 void render(){long now=System.currentTimeMillis();LinearLayout intro=a.card("现在，哪些信息是新的？");intro.addView(a.text("连接、缓存获取和上屏回执分别显示。这里是手机缓存；ESP32自主天气可到自主更新页读取。",14,a.muted));
  row("设备连接",connection(a.origin,contactOrigin,lastContact,now),stamp(a.origin.equals(contactOrigin)?lastContact:0,"最近响应"),"只检查连接",this::check);
  row("屏幕同步",syncTitle(),stamp(receipt(),"最近确认回执")+"\n"+a.message,"打开设备管理",()->a.openPage("设备"));
  row("天气 · "+a.cfg.optString("city","苏州"),freshness(a.weather==null?0:a.weather.optLong("fetched"),now,3600000,weatherFailed),stamp(a.weather==null?0:a.weather.optLong("fetched"),"最近获取")+"\n超过1小时标记过期；缓存可用不代表已上屏。","配置或更新天气",()->a.openInfo("天气城市"));
  JSONArray codes=a.cfg.optJSONArray("stocks");int wanted=codes==null?0:codes.length(),count=0;Set<String> available=new HashSet<>();for(int i=0;i<a.quotes.length();i++)available.add(a.quotes.optJSONObject(i).optString("code"));for(int i=0;i<wanted;i++)if(available.contains(codes.optString(i)))count++;
  row("自选行情",wanted==0?"未选择股票":(stocksFailed?"最近获取失败 · ":"")+"已缓存 "+count+" / "+wanted+" 支","行情时间由供应商提供，可能延迟或处于休市；不把刚获取等同于实时行情。","配置或更新行情",()->a.openInfo("自选股票"));
  JSONObject commute=a.cfg.optJSONObject("commute");row("驾车通勤",freshness(commute==null?0:commute.optLong("fetched"),now,900000,commuteFailed),stamp(commute==null?0:commute.optLong("fetched"),"最近获取")+"\n超过15分钟标记过期；首次使用需高德Key和起终点。","通勤设置",()->a.openPage("通勤建议"));
  a.button(a.body,"系统日历设置",()->a.openPage("手机日历"));a.button(a.body,"设备自主天气状态",()->a.openPage("自主更新"));a.body.addView(a.text("只读诊断不会切换控制端、接管布局或全刷。最近响应与发送回执仅记录本次启动；实屏效果仍需目视确认。",13,a.muted));
 }
 void check(){if(a.origin.isEmpty()){a.openPage("设备");return;}final String destination=a.origin;a.work("只读检查设备连接",()->{try{DeviceLocator.verify(a.deviceID,DeskApi.state(destination));}catch(Exception e){a.ui.post(()->{if(a.origin.equals(destination))lastContact=0;});throw e;}},()->{if(!a.origin.equals(destination))return;contacted(destination);a.message="设备已响应；未导入清单或发送画面。";});}
}
