package com.desktodo.app;
import android.app.*;import android.os.*;import org.json.*;
/** Explicit opt-in, live discovery + GET only. Never commits tasks or a display frame. */
public final class DeviceDiscoveryChecks extends Instrumentation {
 String id;
 @Override public void onCreate(Bundle args){id=args.getString("deviceID","");start();}
 @Override public void onStart(){Bundle out=new Bundle();DeviceLocator locator=new DeviceLocator(getTargetContext());try{if(!DeviceLocator.valid(id))throw new Exception("Pass an explicit deviceID");String address=locator.find(id);JSONObject state=DeskApi.state(address);DeviceLocator.verify(id,state);DeviceLocator.Connection recovered=locator.read("http://192.0.2.1",id);DeviceLocator.verify(id,recovered.state);if(!recovered.origin.equals(address))throw new Exception("Discovery returned inconsistent address");out.putString("stream","PASS: live Android DNS-SD resolved bound device, recovered from unavailable IP, and HTTP identity matched; GET only, no display writes\n");finish(Activity.RESULT_OK,out);}catch(Throwable e){out.putString("stream","FAIL: "+e+"\n");finish(Activity.RESULT_CANCELED,out);}finally{locator.close();}}
}
