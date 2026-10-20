package com.desktodo.app;
import android.content.Context;
import android.net.nsd.*;
import java.io.IOException;
import java.net.Inet4Address;
import java.util.concurrent.*;
import org.json.JSONObject;

/** Bounded foreground DNS-SD discovery. Names are hints, HTTP identity is authoritative. */
final class DeviceLocator {
 static boolean valid(String id){return id!=null&&id.matches("mojian-[0-9a-f]{12}");}
 static void verify(String expected,JSONObject state)throws IOException{if(expected!=null&&!expected.isEmpty()&&(!valid(expected)||!expected.equals(state.optString("device_id"))))throw new IOException("此地址不是已绑定屏幕，请重新发现；更换屏幕需先解除绑定");}
 static final class Connection {final String origin;final JSONObject state;Connection(String origin,JSONObject state){this.origin=origin;this.state=state;}}
 Connection read(String origin,String expected)throws Exception {
  try{JSONObject state=DeskApi.state(origin);verify(expected,state);return new Connection(origin,state);}
  catch(Exception original){if(!valid(expected))throw original;String found=find(expected);JSONObject state=DeskApi.state(found);verify(expected,state);return new Connection(found,state);}
 }
 final NsdManager manager;volatile Search active;boolean enabled=true;
 DeviceLocator(Context context){manager=(NsdManager)context.getSystemService(Context.NSD_SERVICE);}
 final class Search implements NsdManager.DiscoveryListener {
  final String id;final CountDownLatch ready=new CountDownLatch(1);volatile String origin;volatile boolean closed=false,resolving=false;
  Search(String id){this.id=id;}
  public void onDiscoveryStarted(String t){}
  public void onServiceFound(NsdServiceInfo s){if(closed||resolving||!s.getServiceName().equals(id))return;resolving=true;try{manager.resolveService(s,new NsdManager.ResolveListener(){public void onResolveFailed(NsdServiceInfo info,int code){resolving=false;}public void onServiceResolved(NsdServiceInfo info){if(closed)return;if(info.getHost() instanceof Inet4Address && info.getPort()==80){origin="http://"+info.getHost().getHostAddress();ready.countDown();}else resolving=false;}});}catch(Exception e){resolving=false;}}
  public void onServiceLost(NsdServiceInfo s){}
  public void onDiscoveryStopped(String t){}
  public void onStartDiscoveryFailed(String t,int code){ready.countDown();}
  public void onStopDiscoveryFailed(String t,int code){}
  void close(){closed=true;ready.countDown();try{manager.stopServiceDiscovery(this);}catch(Exception ignored){}}
 }
 String find(String id)throws Exception {
  if(!valid(id)||manager==null)throw new IOException("尚未绑定屏幕，请先用蓝牙发现或输入地址连接一次");
  Search search=new Search(id);
  try{synchronized(this){if(!enabled)throw new IOException("应用已离开前台，暂停寻找屏幕");active=search;manager.discoverServices("_mojian._tcp.",NsdManager.PROTOCOL_DNS_SD,search);}search.ready.await(8,TimeUnit.SECONDS);if(search.closed||search.origin==null)throw new IOException("未找到已绑定屏幕，请检查供电、同一Wi-Fi，或用蓝牙重新发现");return search.origin;}
  finally{search.close();if(active==search)active=null;}
 }
 synchronized void resume(){enabled=true;}
 synchronized void close(){enabled=false;Search search=active;if(search!=null)search.close();}
}
