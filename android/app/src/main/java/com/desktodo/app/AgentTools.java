package com.desktodo.app;

import org.json.*;
import java.time.*;
import java.util.*;

/** Fixed product tools. Every write returns a proposal, not a side effect. */
final class AgentTools {
    final JSONObject context;
    final String source;
    final JSONArray proposals=new JSONArray();
    final Map<String,JSONObject> proposed=new HashMap<>();
    AgentTools(JSONObject context,String source){this.context=DeskModel.copy(context);this.source=source;}
    static JSONObject property(String type,String description)throws Exception{return new JSONObject().put("type",type).put("description",description);}
    static JSONObject schema(String name,String description,JSONObject properties,String... required)throws Exception {
        return new JSONObject().put("type","function").put("function",new JSONObject().put("name",name).put("description",description)
            .put("parameters",new JSONObject().put("type","object").put("properties",properties).put("required",new JSONArray(Arrays.asList(required))).put("additionalProperties",false)));
    }
    static JSONArray schemas()throws Exception {
        JSONArray tools=new JSONArray();
        tools.put(schema("get_time","读取当前上海时区时间；日期计算必须以此为准",new JSONObject()));
        tools.put(schema("list_tasks","读取手机最新未完成清单及ID，不能把查询结果说成已完成修改",new JSONObject()));
        tools.put(schema("get_weather","查询已配置城市的实时天气和三日预报；此工具不改城市设置",new JSONObject()));
        tools.put(schema("get_commute","读取用户已主动查询的驾车耗时与出发建议；无缓存或过期必须提示去通勤页更新，不能编造实时路况",new JSONObject()));
        tools.put(schema("get_stocks","查询已配置的最多五支股票最新行情，仅提供信息",new JSONObject()));
        tools.put(schema("get_preferences","读取已配置城市、布局、免打扰设置与用户确认且启用的偏好",new JSONObject()));
        tools.put(schema("propose_task_change","提出待确认的待办操作。绝不立即执行；必须告诉用户仍需点卡片。add需title；edit/complete/delete/pin需真实id；edit仅传需要修改的字段；due必须带时区ISO8601，null表示清除；pin需pinned布尔值。",
            new JSONObject().put("operation",property("string","操作类型").put("enum",new JSONArray(Arrays.asList("add","edit","complete","delete","pin"))))
                .put("id",property("string","从list_tasks读取的真实ID"))
                .put("title",property("string","事项标题，1至100字"))
                .put("due",new JSONObject().put("type",new JSONArray(Arrays.asList("string","null"))).put("description","截止时间，带时区ISO8601；null清除"))
                .put("pinned",property("boolean","是否置顶")),"operation"));
        tools.put(schema("propose_layout","提出布局切换卡片；确认应用会全刷一次，普通待办不会全刷",new JSONObject()
            .put("layout",property("string","布局").put("enum",new JSONArray(Arrays.asList("focus","agenda","minimal","overview","pomodoro","living","custom")))).put("ratio",property("integer","自定义待办比例40至75，默认67")),"layout"));
        tools.put(schema("propose_memory","提出用户明确表达的偏好记忆，必须等用户点确认才记住；不要推测身份、情绪或敏感信息",new JSONObject().put("key",property("string","偏好名称1至32字")).put("value",property("string","用户明确表达的偏好1至200字")),"key","value"));
        tools.put(schema("propose_reminder_settings","提出本地提醒设置；开启后仍需要用户在系统允许通知，模型不能授权系统权限",new JSONObject().put("enabled",property("boolean","启用本地到期提醒")).put("quietEnabled",property("boolean","启用免打扰")).put("quietStart",property("integer","免打扰开始小时0至23")).put("quietEnd",property("integer","免打扰结束小时0至23"))));
        return tools;
    }
    interface ReadTools {JSONObject weather(JSONObject cfg)throws Exception;JSONArray stocks(JSONArray symbols)throws Exception;}
    final ReadTools network=new ReadTools(){public JSONObject weather(JSONObject cfg)throws Exception{return DeskApi.weather(cfg);}public JSONArray stocks(JSONArray codes)throws Exception{return DeskApi.stocks(codes);}};
    JSONObject execute(String name,JSONObject args)throws Exception{return execute(name,args,network);}
    JSONObject execute(String name,JSONObject args,ReadTools reads)throws Exception {
        JSONObject definition=null;JSONArray allowed=schemas();for(int i=0;i<allowed.length();i++){JSONObject f=allowed.getJSONObject(i).getJSONObject("function");if(f.getString("name").equals(name))definition=f;}if(definition==null)throw new Exception("不支持的工具");JSONObject properties=definition.getJSONObject("parameters").getJSONObject("properties");for(Iterator<String> it=args.keys();it.hasNext();)if(!properties.has(it.next()))throw new Exception("工具包含未知参数");
        switch(name){
            case "get_time":return new JSONObject().put("now",ZonedDateTime.now(ZoneId.of("Asia/Shanghai")).toString()).put("timezone","Asia/Shanghai");
            case "list_tasks":return new JSONObject().put("tasks",context.getJSONArray("tasks")).put("capacity",8).put("pin_limit",3);
            case "get_weather":return new JSONObject().put("source","Open-Meteo").put("data",reads.weather(context.getJSONObject("settings")));
            case "get_commute":JSONObject commute=context.optJSONObject("commute");return new JSONObject().put("available",commute!=null&&System.currentTimeMillis()-commute.optLong("fetched")<900000).put("result",DeskExtras.commuteText(new JSONObject().put("commute",commute),Instant.now()));
            case "get_stocks":return new JSONObject().put("source","Tencent quote interface; may be delayed").put("quotes",reads.stocks(context.getJSONObject("settings").getJSONArray("stocks")));
            case "get_preferences":return new JSONObject().put("settings",context.getJSONObject("settings")).put("memories",PreferenceMemory.enabled(context.getJSONArray("memories"))).put("reminders",context.optJSONObject("reminders"));
            case "propose_task_change":case "propose_layout":case "propose_memory":case "propose_reminder_settings":return propose(name,args);
            default:throw new Exception("不支持的工具；此助手只允许墨间产品工具");
        }
    }
    static String string(JSONObject args,String key,int max)throws Exception {
        Object value=args.opt(key);if(!(value instanceof String))throw new Exception(key+"必须是文字");String s=((String)value).trim();if(s.isEmpty()||s.length()>max)throw new Exception(key+"长度无效");return s;
    }
    static int integer(JSONObject args,String key,int low,int high)throws Exception {
        Object v=args.opt(key);if(!(v instanceof Number)||((Number)v).doubleValue()!=Math.rint(((Number)v).doubleValue()))throw new Exception(key+"必须是整数");int n=((Number)v).intValue();if(n<low||n>high)throw new Exception(key+"超出范围");return n;
    }
    static void booleanValue(JSONObject args,String key)throws Exception{if(args.has(key)&&!(args.opt(key) instanceof Boolean))throw new Exception(key+"必须是布尔值");}
    JSONObject propose(String name,JSONObject args)throws Exception {
        String fingerprint=name+SyncPolicy.canonical(args);if(proposed.containsKey(fingerprint))return new JSONObject().put("status","pending_user_confirmation").put("proposal_id",proposed.get(fingerprint).getString("id"));
        if(proposals.length()>=6)throw new Exception("单轮最多六个待确认操作");
        JSONObject p=new JSONObject().put("id",UUID.randomUUID().toString()).put("tool",name).put("args",DeskModel.copy(args)).put("status","pending").put("createdAt",System.currentTimeMillis()).put("source",source.substring(0,Math.min(200,source.length())));
        JSONArray tasks=context.getJSONArray("tasks");
        if(name.equals("propose_task_change")){
            String op=string(args,"operation",16);if(!Arrays.asList("add","edit","complete","delete","pin").contains(op))throw new Exception("未知待办操作");
            if(args.has("title"))string(args,"title",100);
            if(args.has("due")&&!args.isNull("due")){String due=string(args,"due",50);try{Instant.parse(due);}catch(Exception e){throw new Exception("截止时间必须是带时区的ISO8601时间");}}
            booleanValue(args,"pinned");
            if(op.equals("add")){if(tasks.length()>=8)throw new Exception("未完成清单已满");p.put("newTask",DeskModel.task(string(args,"title",100),args.isNull("due")?null:args.optString("due",null)));}
            else {String id=string(args,"id",128);JSONObject found=null;for(int i=0;i<tasks.length();i++)if(tasks.getJSONObject(i).optString("id").equals(id))found=tasks.getJSONObject(i);if(found==null)throw new Exception("待办ID不存在，请先读取清单");p.put("expectedTask",DeskModel.copy(found));if(op.equals("edit")&&!args.has("title")&&!args.has("due"))throw new Exception("没有待编辑字段");if(op.equals("pin")&&!args.has("pinned"))throw new Exception("缺少置顶状态");}
        } else if(name.equals("propose_layout")){
            String layout=string(args,"layout",20);if(!Arrays.asList("focus","agenda","minimal","overview","pomodoro","living","custom").contains(layout))throw new Exception("不支持的布局");if(args.has("ratio"))integer(args,"ratio",40,75);
        } else if(name.equals("propose_memory")){
            String key=string(args,"key",32),value=string(args,"value",200);JSONArray memories=context.getJSONArray("memories");String id=null;
            for(int i=0;i<memories.length();i++){JSONObject m=memories.getJSONObject(i);if(!m.optBoolean("deleted")&&m.optString("key").equals(key)){id=m.getString("id");p.put("expectedMemory",DeskModel.copy(m));}}
            PreferenceMemory.save(memories,id,key,value,source);
        } else {
            if(args.length()==0)throw new Exception("没有提醒设置字段");booleanValue(args,"enabled");booleanValue(args,"quietEnabled");if(args.has("quietStart"))integer(args,"quietStart",0,23);if(args.has("quietEnd"))integer(args,"quietEnd",0,23);
        }
        proposals.put(p);proposed.put(fingerprint,p);return new JSONObject().put("status","pending_user_confirmation").put("proposal_id",p.getString("id")).put("message","仅已生成卡片，尚未执行；请让用户点确认，不要声称已修改或已提醒");
    }
    static String layoutName(String kind){switch(kind){case "focus":return "专注清单";case "agenda":return "日程安排";case "minimal":return "极简留白";case "pomodoro":return "番茄专注";case "living":return "生活节奏";case "custom":return "自定义";default:return "信息总览";}}
    static String dueText(String due){try{return java.time.format.DateTimeFormatter.ofPattern("MM月dd日 HH:mm").withZone(ZoneId.of("Asia/Shanghai")).format(Instant.parse(due));}catch(Exception e){return "时间待核对";}}
    static String summary(JSONObject p)throws Exception {
        JSONObject a=p.getJSONObject("args");String tool=p.getString("tool");
        if(tool.equals("propose_memory"))return "记住「"+a.getString("key")+"」："+a.getString("value");
        if(tool.equals("propose_layout"))return "切换为「"+layoutName(a.getString("layout"))+"」布局（全刷一次）";
        if(tool.equals("propose_reminder_settings")){StringBuilder summary=new StringBuilder("调整本地提醒");if(a.has("enabled"))summary.append(a.getBoolean("enabled")?"\n开启待办提醒":"\n关闭待办提醒");if(a.has("quietEnabled"))summary.append(a.getBoolean("quietEnabled")?"\n开启免打扰":"\n关闭免打扰");if(a.has("quietStart"))summary.append("\n免打扰开始：").append(a.getInt("quietStart")).append(":00");if(a.has("quietEnd"))summary.append("\n免打扰结束：").append(a.getInt("quietEnd")).append(":00");return summary.toString();}
        String op=a.getString("operation");String title=op.equals("add")?a.optString("title"):p.getJSONObject("expectedTask").optString("title");
        String label=op.equals("add")?"新增":op.equals("edit")?"编辑":op.equals("complete")?"完成":op.equals("delete")?"删除":a.optBoolean("pinned")?"置顶":"取消置顶";
        String detail=a.has("title")&&!op.equals("add")?" → "+a.getString("title"):"";
        if(a.has("due"))detail+="\n截止时间："+(a.isNull("due")?"清除":dueText(a.getString("due")));
        return label+"「"+title+"」"+detail;
    }
}
