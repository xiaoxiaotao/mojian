package com.desktodo.app;

import android.content.Context;
import android.util.AtomicFile;
import org.json.*;
import java.io.*;

/** Atomic local conversation/proposal persistence; never contains model credentials. */
final class AgentStore {
    private final AtomicFile file;
    JSONArray messages=new JSONArray(),proposals=new JSONArray(),memories=new JSONArray();
    boolean loaded=true;
    AgentStore(Context context){file=new AtomicFile(new File(context.getFilesDir(),"assistant-state.json"));load();}
    AgentStore(File path){file=new AtomicFile(path);load();}
    private void load(){if(!file.getBaseFile().exists())return;try{JSONObject j=new JSONObject(new String(file.readFully(),java.nio.charset.StandardCharsets.UTF_8));messages=j.getJSONArray("messages");proposals=j.getJSONArray("proposals");memories=j.getJSONArray("memories");}catch(Exception e){loaded=false;}}
    synchronized void save()throws Exception {
        if(!loaded)throw new Exception("助手记录读取失败，原文件已保留，请先恢复数据");
        JSONObject j=new JSONObject().put("version",1).put("messages",messages).put("proposals",proposals).put("memories",memories);
        FileOutputStream stream=null;try{stream=file.startWrite();stream.write(j.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));file.finishWrite(stream);}catch(Exception e){if(stream!=null)file.failWrite(stream);throw new Exception("助手记录保存失败");}
    }
    void message(String role,String content)throws Exception {
        messages.put(new JSONObject().put("role",role).put("content",content.substring(0,Math.min(12000,content.length()))).put("time",System.currentTimeMillis()));
        while(messages.length()>50)messages.remove(0);save();
    }
    void append(JSONArray incoming)throws Exception{JSONArray next=DeskModel.copy(proposals);for(int i=0;i<incoming.length();i++)next.put(DeskModel.copy(incoming.getJSONObject(i)));while(next.length()>40){int remove=-1;for(int i=0;i<next.length();i++)if(!next.getJSONObject(i).optString("status").equals("pending")){remove=i;break;}if(remove<0)throw new Exception("待确认操作过多，请先处理已有卡片");next.remove(remove);}JSONArray old=proposals;proposals=next;try{save();}catch(Exception e){proposals=old;throw e;}}
    JSONObject proposal(String id)throws Exception{for(int i=0;i<proposals.length();i++)if(proposals.getJSONObject(i).optString("id").equals(id))return proposals.getJSONObject(i);throw new Exception("操作卡片不存在");}
    void recoverApplying()throws Exception{boolean changed=false;for(int i=0;i<proposals.length();i++){JSONObject p=proposals.getJSONObject(i);if(p.optString("status").equals("applying")){p.put("status","interrupted").put("result","上次确认执行被中断，请核对手机清单和设置后重新提出，避免重复执行");changed=true;}}if(changed)save();}
}
