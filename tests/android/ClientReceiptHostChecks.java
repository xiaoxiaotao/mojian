// Host-only regression using real DeskApi/ScreenSync/SyncPolicy/CommitReceipt and a loopback fake ESP32.
// Compile with JDK17 and org.json 20240303 on the classpath; never package this fixture in an APK.
// DeskModel/DeskExtras below only satisfy unrelated ScreenSync method references; the tested
// commitAcknowledged path uses actual JSONObject metadata and does not call either stub.
package com.desktodo.app;
import org.json.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import com.sun.net.httpserver.*;
final class DeskModel {static JSONObject copy(JSONObject value){return new JSONObject(value.toString());}static String layoutId(JSONObject cfg){return "fixture-layout";}}
final class DeskExtras {static JSONObject deviceConfig(JSONObject cfg){return cfg;}}
public final class ClientReceiptHostChecks {
 static int count;static String mode="legacy";static int polls;static int stateReads,commitAttempts;
 static void check(boolean value){count++;if(!value)throw new AssertionError("check "+count);}
 static void respond(HttpExchange e,int status,String text)throws Exception{byte[] body=text.getBytes(StandardCharsets.UTF_8);e.sendResponseHeaders(status,body.length);e.getResponseBody().write(body);e.close();}
 public static void main(String[] args)throws Exception{
  JSONObject sent=new JSONObject().put("tasks",new JSONArray().put(new JSONObject().put("id","fixture"))).put("layout_id","fixture-layout").put("content_key","visual-key").put("phone_settings",new JSONObject().put("note","original"));JSONObject latest=DeskModel.copy(sent).put("baseline_ready",true).put("needs_full",false);
  check(ScreenSync.commitAcknowledged(sent,latest));check(!ScreenSync.commitAcknowledged(sent,DeskModel.copy(latest).put("content_key","other")));check(!ScreenSync.commitAcknowledged(sent,DeskModel.copy(latest).put("phone_settings",new JSONObject().put("note","other"))));check(!ScreenSync.commitAcknowledged(sent,DeskModel.copy(latest).put("baseline_ready",false)));check(!ScreenSync.commitAcknowledged(sent,DeskModel.copy(latest).put("needs_full",true)));check(!ScreenSync.commitAcknowledged(sent,DeskModel.copy(latest).put("tasks",new JSONArray())));check(!ScreenSync.commitAcknowledged(sent,DeskModel.copy(latest).put("layout_id","other")));
  HttpServer server=HttpServer.create(new InetSocketAddress(InetAddress.getLoopbackAddress(),0),0);
  server.createContext("/api/local/state",e->{try{stateReads++;respond(e,200,new JSONObject().put("display_busy",mode.equals("busy")&&stateReads==1).toString());}catch(Exception x){throw new RuntimeException(x);}});
  server.createContext("/api/local/commit",e->{try{check(e.getRequestURI().getRawQuery().contains("async=1"));commitAttempts++;while(e.getRequestBody().read()!=-1){}polls=0;if(mode.equals("race")&&commitAttempts==1)respond(e,423,"{\"error\":\"busy\"}");else if(mode.equals("legacy"))respond(e,200,"{\"ok\":true}");else if(mode.equals("malformed"))respond(e,202,"{}");else respond(e,202,"{\"transaction_id\":\"fixture-tx\"}");}catch(Exception x){throw new RuntimeException(x);}});
  server.createContext("/api/local/transaction",e->{try{polls++;check(e.getRequestURI().getRawQuery().equals("id=fixture-tx"));String id=mode.equals("wrong")?"other":"fixture-tx";String state=mode.equals("failed")?"failed":mode.equals("unknown")?"unknown":polls==1?"pending":"completed";respond(e,200,new JSONObject().put("transaction_id",id).put("status",state).put("error","fixture failure").toString());}catch(Exception x){throw new RuntimeException(x);}});
  server.start();String origin="http://127.0.0.1:"+server.getAddress().getPort();try{DeskApi.commit(origin,sent,new byte[48000],false);check(polls==0);mode="success";DeskApi.commit(origin,sent,new byte[48000],false);check(polls==2);mode="busy";stateReads=0;DeskApi.commit(origin,sent,new byte[48000],false);check(stateReads>=2);mode="race";commitAttempts=0;DeskApi.commit(origin,sent,new byte[48000],false);check(commitAttempts==2);for(String item:new String[]{"failed","wrong","unknown","malformed"}){mode=item;boolean rejected=false;try{DeskApi.commit(origin,sent,new byte[48000],false);}catch(Exception expected){rejected=true;}check(rejected);}}finally{server.stop(0);}System.out.println("PASS: "+count+" native Android client host checks (visual receipts, real loopback HTTP legacy200/202 pending-completed/failed/wrong-id/unknown/malformed, display_busy/423 recovery)");
 }
}
