package com.desktodo.app;

import org.json.*;
import java.time.Instant;
import java.util.UUID;

/** Explicit, inspectable preferences. Model suggestions never save themselves. */
final class PreferenceMemory {
    static JSONArray save(JSONArray source,String id,String key,String value,String provenance)throws Exception {
        key=key.trim();value=value.trim();if(key.isEmpty()||key.length()>32||value.isEmpty()||value.length()>200)throw new Exception("名称1至32字，内容1至200字");
        JSONArray out=DeskModel.copy(source);int at=-1;
        for(int i=0;i<out.length();i++){JSONObject m=out.getJSONObject(i);if(id!=null&&id.equals(m.optString("id")))at=i;else if(!m.optBoolean("deleted")&&m.optString("key").equals(key))throw new Exception("该偏好已存在，请编辑现有条目");}
        int active=0;for(int i=0;i<out.length();i++)if(!out.getJSONObject(i).optBoolean("deleted"))active++;
        if(at<0&&(active>=32||out.length()>=64))throw new Exception("记忆已达容量上限，请先整理已有条目");
        JSONObject memory=at<0?new JSONObject().put("id",UUID.randomUUID().toString()).put("createdAt",Instant.now().toString()):DeskModel.copy(out.getJSONObject(at));
        memory.put("key",key).put("value",value).put("source",provenance==null?"手动添加":provenance.substring(0,Math.min(200,provenance.length())))
            .put("updatedAt",Instant.now().toString()).put("enabled",true).put("deleted",false);
        if(at<0)out.put(memory);else out.put(at,memory);return out;
    }
    static JSONArray set(JSONArray source,String id,String field,boolean value)throws Exception {
        if(!field.equals("deleted")&&!field.equals("enabled"))throw new Exception("未知记忆操作");JSONArray out=DeskModel.copy(source);
        for(int i=0;i<out.length();i++){JSONObject m=out.getJSONObject(i);if(m.optString("id").equals(id)){if(field.equals("deleted")&&!value){int active=0;for(int k=0;k<out.length();k++){JSONObject other=out.getJSONObject(k);if(!other.optBoolean("deleted")&&!other.optString("id").equals(id)){active++;if(other.optString("key").equals(m.optString("key")))throw new Exception("同名偏好已存在，无法恢复");}}if(active>=32)throw new Exception("偏好容量已满");}m.put(field,value).put("updatedAt",Instant.now().toString());return out;}}throw new Exception("记忆已变化，请重新查看");
    }
    static JSONArray enabled(JSONArray source)throws Exception {
        JSONArray out=new JSONArray();for(int i=0;i<source.length();i++){JSONObject m=source.getJSONObject(i);if(!m.optBoolean("deleted")&&m.optBoolean("enabled",true))out.put(new JSONObject().put("key",m.getString("key")).put("value",m.getString("value")));}return out;
    }
}
