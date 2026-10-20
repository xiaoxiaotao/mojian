package com.desktodo.app;
import org.json.*;
import java.net.*;
import java.io.*;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.util.*;

final class DeskApi {
 static byte[] request(String address,String method,byte[] data,String contentType)throws Exception{return request(address,method,data,contentType,"");}
 static byte[] request(String address,String method,byte[] data,String contentType,String token)throws Exception{
  HttpURLConnection c=(HttpURLConnection)new URL(address).openConnection();boolean stateRequest=new URL(address).getPath().equals("/api/local/state");c.setConnectTimeout(stateRequest?4000:8000);c.setReadTimeout(method.equals("POST")?90000:stateRequest?6000:15000);c.setRequestMethod(method);c.setInstanceFollowRedirects(false);if(!token.isEmpty())c.setRequestProperty("Authorization","Bearer "+token);
  try{if(data!=null){c.setDoOutput(true);c.setRequestProperty("Content-Type",contentType);c.setFixedLengthStreamingMode(data.length);try(OutputStream s=c.getOutputStream()){s.write(data);}}int code=c.getResponseCode();InputStream input=code>=200&&code<300?c.getInputStream():c.getErrorStream();ByteArrayOutputStream out=new ByteArrayOutputStream();if(input!=null)try(InputStream s=input){byte[] b=new byte[4096];int n;while((n=s.read(b))!=-1){out.write(b,0,n);if(out.size()>2_000_000)throw new Exception("响应数据过大");}}byte[] bytes=out.toByteArray();if(code<200||code>=300){String m="连接失败（"+code+"）";try{m=new JSONObject(new String(bytes,StandardCharsets.UTF_8)).optString("error",m);}catch(Exception ignored){}throw new Exception(m);}return bytes;}finally{c.disconnect();}
 }
 static JSONObject json(String url)throws Exception{return new JSONObject(new String(request(url,"GET",null,null),StandardCharsets.UTF_8));}
 static JSONObject state(String origin)throws Exception{return json(origin+"/api/local/state");}
 static byte[] base(String origin)throws Exception{byte[] b=request(origin+"/api/local/base","GET",null,null);if(b.length!=48000)throw new Exception("画面数据不完整");return b;}
 static void commit(String origin,JSONObject meta,byte[] frame,boolean full)throws Exception{
  String boundary="MoJianAndroid"+UUID.randomUUID().toString().replace("-","");ByteArrayOutputStream out=new ByteArrayOutputStream();out.write(("--"+boundary+"\r\nContent-Disposition: form-data; name=\"metadata\"\r\n\r\n"+meta+"\r\n--"+boundary+"\r\nContent-Disposition: form-data; name=\"frame\"; filename=\"frame.bin\"\r\nContent-Type: application/octet-stream\r\n\r\n").getBytes(StandardCharsets.UTF_8));out.write(frame);out.write(("\r\n--"+boundary+"--\r\n").getBytes(StandardCharsets.UTF_8));request(origin+"/api/local/commit?full="+(full?1:0),"POST",out.toByteArray(),"multipart/form-data; boundary="+boundary);
 }
 static JSONObject weather(JSONObject cfg)throws Exception{
  JSONObject j=json("https://api.open-meteo.com/v1/forecast?latitude="+cfg.getDouble("latitude")+"&longitude="+cfg.getDouble("longitude")+"&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code&forecast_days=3&hourly=precipitation_probability,apparent_temperature,wind_speed_10m&wind_speed_unit=ms&timezone=Asia%2FShanghai");j.getJSONObject("current").getDouble("temperature_2m");j.put("fetched",System.currentTimeMillis());j.put("city",cfg.getString("city"));return j;
 }
 static JSONArray cities(String name)throws Exception{return json("https://geocoding-api.open-meteo.com/v1/search?name="+URLEncoder.encode(name,"UTF-8")+"&count=5&language=zh").optJSONArray("results");}
 static JSONArray stocks(JSONArray codes)throws Exception{
  JSONArray out=new JSONArray();if(codes.length()==0)return out;List<String> cs=new ArrayList<>();for(int i=0;i<codes.length();i++)cs.add(codes.getString(i));String text=new String(request("https://qt.gtimg.cn/q="+String.join(",",cs),"GET",null,null),Charset.forName("GB18030"));
  for(String code:cs){String key="v_"+code+"=\"";int start=text.indexOf(key);if(start<0)throw new Exception("部分行情未返回，保留上次结果");int end=text.indexOf('"',start+key.length());if(end<0)throw new Exception("行情数据不完整");String[] f=text.substring(start+key.length(),end).split("~",-1);if(f.length<=32)throw new Exception("行情字段不完整");double price=Double.parseDouble(f[3]),percent=Double.parseDouble(f[32]);if(!Double.isFinite(price)||price<=0||!Double.isFinite(percent))throw new Exception("行情数字无效");out.put(new JSONObject().put("code",code).put("name",f[1]).put("price",price).put("percent",percent).put("asOf",f[30]));}return out;
 }
 static String weatherText(int code){if(code==0)return "晴";if(code<=3)return "多云";if(code<=48)return "雾";if(code<=67)return "雨";if(code<=77)return "雪";if(code<=82)return "阵雨";return "雷雨";}
}
