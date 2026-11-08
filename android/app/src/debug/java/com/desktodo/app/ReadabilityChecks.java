package com.desktodo.app;
import android.app.*;
import android.os.Bundle;
import android.graphics.*;
import org.json.*;
import java.io.*;
import java.time.Instant;
/** Off-screen fictional rendering only: no preferences, networking or panel writes. */
public final class ReadabilityChecks extends Instrumentation {
 int assertions;
 void check(boolean value,String message){assertions++;if(!value)throw new AssertionError(message);}
 int ink(byte[] bytes,int x,int y,int w,int h){int n=0;for(int yy=y;yy<y+h;yy++)for(int xx=x;xx<x+w;xx++)if((bytes[yy*100+xx/8]&(128>>(xx%8)))==0)n++;return n;}
 @Override public void onCreate(Bundle args){start();}
 @Override public void onStart(){Bundle result=new Bundle();try{
  ScreenFonts.load(getTargetContext());Instant now=Instant.parse("2026-10-29T01:30:00Z");
  JSONArray tasks=new JSONArray();String[] titles={"整理产品需求与质量检查","确认客户的设计方案和交付日期","量、赢、警：复杂汉字清晰度","记得喝水，休息一下眼睛","这是一条很长的测试事项，应该省略而不是挤到其他模块"};
  for(int i=0;i<titles.length;i++)tasks.put(DeskModel.task(titles[i],now.plusSeconds((i-1)*3600L).toString()));
  JSONArray quotes=new JSONArray();String[] names={"示例甲","示例乙","示例丙","示例长名称测试","示例戊"};double[] percent={4.77,-9.99,0,123.45,-0.01},prices={1234.56,9.87,500000.99,18.76,2.34};
  for(int i=0;i<5;i++)quotes.put(new JSONObject().put("name",names[i]).put("price",prices[i]).put("percent",percent[i]).put("asOf","20261029093000"));
  JSONObject weather=new JSONObject().put("city","苏州").put("current",new JSONObject().put("temperature_2m",22).put("weather_code",2));
  for(String kind:new String[]{"focus","agenda","overview","minimal","pomodoro","living","custom"}){
   JSONObject cfg=DeskModel.defaults().put("layout",kind).put("stockConfigured",true).put("cardsVersion",1);String id=DeskModel.layoutId(cfg);
   DeskRenderer renderer=new DeskRenderer(null,tasks,cfg,weather,quotes,now);renderer.full(id);byte[] frame=renderer.frame();
   for(int i=8000;i<10400;i++)check(frame[i]==(byte)255,kind+" red reserve");
   if(!kind.equals("custom")){
    for(int column=0;column<5;column++){int x=24+column*152;check(ink(frame,x,423,145,18)>30,"stock name");check(ink(frame,x,441,145,19)>30,"stock price");check(ink(frame,x+16,460,129,20)>20,"signed percentage");check(ink(frame,x,465,10,10)>8,"vector direction");}
    check(ink(frame,24,465,10,3)<ink(frame,24,472,10,3),"up arrow points up");check(ink(frame,176,465,10,3)>ink(frame,176,472,10,3),"down arrow points down");
   }
   try(FileOutputStream out=new FileOutputStream(new File(getTargetContext().getFilesDir(),"readability-"+kind+".png"))){DeskRenderer.decode(frame).compress(Bitmap.CompressFormat.PNG,100,out);}
  }
  // Unicode truncation must not split a surrogate pair or spill out of a card.
  JSONObject cfg=DeskModel.defaults();DeskRenderer unicode=new DeskRenderer(null,new JSONArray(),cfg,null,new JSONArray(),now);unicode.text("质量检查😀长标题",24,140,22,60);byte[] packed=unicode.frame();for(int y=140;y<178;y++)check(ink(packed,88,y,80,1)==0,"truncation stays in width");
  JSONObject narrow=DeskModel.defaults().put("layout","custom").put("ratio",75).put("cardsVersion",1);JSONArray named=DeskModel.copy(quotes);named.getJSONObject(0).put("name","中远海运控股超长名称用于测试");DeskRenderer nameRenderer=new DeskRenderer(null,tasks,narrow,weather,named,now);nameRenderer.full(DeskModel.layoutId(narrow));byte[] namedFrame=nameRenderer.frame();named.getJSONObject(0).put("name","");DeskRenderer noNameRenderer=new DeskRenderer(null,tasks,narrow,weather,named,now);noNameRenderer.full(DeskModel.layoutId(narrow));byte[] noNameFrame=noNameRenderer.frame();for(int y=260;y<282;y++)for(int x=688;x<776;x++){int mask=128>>(x%8);check((namedFrame[y*100+x/8]&mask)==(noNameFrame[y*100+x/8]&mask),"long name cannot obscure percentage");}
  JSONObject notes=DeskModel.defaults().put("layout","overview").put("cardsVersion",1).put("card1","note").put("card2","note").put("note","请确认客户的交付安排和文档，检查所有信息。请确认客户的交付安排和文档，检查所有信息。请确认客户的交付安排和文档，检查所有信息。");DeskRenderer longCards=new DeskRenderer(null,new JSONArray(),notes,weather,quotes,now);longCards.full(DeskModel.layoutId(notes));byte[] longFrame=longCards.frame();check(ink(longFrame,550,215,226,35)>20,"third body line visible");notes.put("note","");DeskRenderer blankCards=new DeskRenderer(null,new JSONArray(),notes,weather,quotes,now);blankCards.full(DeskModel.layoutId(notes));byte[] blankFrame=blankCards.frame();for(int y=0;y<480;y++)for(int x=0;x<800;x++)if(!(x>=550&&x<776&&((y>=161&&y<256)||(y>=307&&y<402)))){int mask=128>>(x%8);check((longFrame[y*100+x/8]&mask)==(blankFrame[y*100+x/8]&mask),"paragraph stays within card");}try(FileOutputStream out=new FileOutputStream(new File(getTargetContext().getFilesDir(),"readability-long-cards.png"))){DeskRenderer.decode(longFrame).compress(Bitmap.CompressFormat.PNG,100,out);}
  JSONObject cal=DeskModel.defaults().put("layout","calendar").put("cardsVersion",1);DeskRenderer month=new DeskRenderer(null,new JSONArray(),cal,weather,new JSONArray(),Instant.parse("2026-11-30T01:30:00Z"));month.full(DeskModel.layoutId(cal));byte[] monthFrame=month.frame();check(ink(monthFrame,346,400,430,23)>40&&ink(monthFrame,346,423,430,1)==0,"six weeks clear footer");try(FileOutputStream out=new FileOutputStream(new File(getTargetContext().getFilesDir(),"readability-calendar-six-rows.png"))){DeskRenderer.decode(monthFrame).compress(Bitmap.CompressFormat.PNG,100,out);}
  result.putString("stream","PASS: "+assertions+" readability assertions: seven layouts, five stocks, vector signs, red reserve, Unicode truncation, narrow percentages, wrapping bounds, six-week calendar; fictional 1-bit previews saved\n");finish(Activity.RESULT_OK,result);
 }catch(Throwable e){result.putString("stream","FAIL: "+e+"\n");finish(Activity.RESULT_CANCELED,result);}}
}
