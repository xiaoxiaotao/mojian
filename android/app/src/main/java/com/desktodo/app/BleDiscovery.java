package com.desktodo.app;

import android.app.Activity;
import android.bluetooth.*;
import android.bluetooth.le.*;
import android.os.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import org.json.JSONObject;

/** One foreground discovery/read transaction. No credentials are read over BLE. */
final class BleDiscovery {
    static final UUID SERVICE=UUID.fromString("7f510001-8be5-4b2c-a47f-87c7e72e7050");
    static final UUID ENDPOINT=UUID.fromString("7f510003-8be5-4b2c-a47f-87c7e72e7050");
    interface Listener { void status(String text); void found(String address); }
    final Activity activity; final Listener listener; final Handler handler=new Handler(Looper.getMainLooper());
    BluetoothLeScanner scanner; BluetoothGatt gatt; boolean active=false,connecting=false; int reads=0;
    final Runnable timeout=()->finish("未找到可连接的工作台；请靠近设备并重试，刷屏期间蓝牙会暂时停止");
    BleDiscovery(Activity a,Listener l){activity=a;listener=l;}
    void start(){
        close();active=true;connecting=false;reads=0;
        try {
            BluetoothManager manager=(BluetoothManager)activity.getSystemService(Activity.BLUETOOTH_SERVICE);
            BluetoothAdapter adapter=manager==null?null:manager.getAdapter();
            if(adapter==null||!adapter.isEnabled()){finish("请先开启手机蓝牙，再点“蓝牙连接工作台”");return;}
            scanner=adapter.getBluetoothLeScanner();
            if(scanner==null){finish("蓝牙扫描暂不可用，请重试");return;}
            listener.status("正在查找 Desk-EPD…");
            scanner.startScan(Collections.singletonList(new ScanFilter.Builder().setServiceUuid(new ParcelUuid(SERVICE)).build()),new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),scan);
            handler.postDelayed(timeout,30000);
        } catch(SecurityException e){finish("需要附近设备权限；旧版安卓还需开启定位服务");}
          catch(Exception e){finish("蓝牙扫描启动失败，请重试");}
    }
    final ScanCallback scan=new ScanCallback(){
        @Override public void onScanResult(int type,ScanResult result){
            if(!active||connecting)return;connecting=true;
            try {scanner.stopScan(this);listener.status("正在读取工作台地址…");gatt=result.getDevice().connectGatt(activity,false,callbacks,BluetoothDevice.TRANSPORT_LE);if(gatt==null)finish("连接未建立，请重试");}
            catch(SecurityException e){finish("蓝牙连接权限未授予");}
        }
        @Override public void onScanFailed(int error){finish("蓝牙扫描失败（"+error+"），请稍后重试");}
    };
    final BluetoothGattCallback callbacks=new BluetoothGattCallback(){
        @Override public void onConnectionStateChange(BluetoothGatt g,int status,int state){
            handler.post(()->{
                if(!active||g!=gatt)return;
                if(status!=BluetoothGatt.GATT_SUCCESS||state==BluetoothProfile.STATE_DISCONNECTED){finish("蓝牙连接已断开；设备可能正在刷新，请重试");return;}
                if(state==BluetoothProfile.STATE_CONNECTED)try{if(!g.discoverServices())finish("读取服务失败，请重试");}catch(SecurityException e){finish("蓝牙权限不足");}
            });
        }
        @Override public void onServicesDiscovered(BluetoothGatt g,int status){handler.post(()->{
            if(!active||g!=gatt)return;
            BluetoothGattService service=g.getService(SERVICE);
            BluetoothGattCharacteristic endpoint=service==null?null:service.getCharacteristic(ENDPOINT);
            if(status!=BluetoothGatt.GATT_SUCCESS||endpoint==null){finish("设备固件尚未支持自动地址，请更新固件或手动填写地址");return;}
            try{if(!g.readCharacteristic(endpoint))finish("读取地址失败，请重试");}catch(SecurityException e){finish("蓝牙权限不足");}
        });}
        @Override public void onCharacteristicRead(BluetoothGatt g,BluetoothGattCharacteristic c,int status){read(g,c.getUuid(),c.getValue(),status);}
        @Override public void onCharacteristicRead(BluetoothGatt g,BluetoothGattCharacteristic c,byte[] value,int status){read(g,c.getUuid(),value,status);}
    };
    void read(BluetoothGatt g,UUID id,byte[] value,int status){handler.post(()->{
        if(!active||g!=gatt||!ENDPOINT.equals(id))return;
        if(status!=BluetoothGatt.GATT_SUCCESS||value==null){finish("读取地址失败，请重试");return;}
        String payload=new String(value,StandardCharsets.UTF_8).trim();
        android.util.Log.i("DeskBLE","Endpoint read: bytes="+value.length+" payload="+payload);
        try{
            String ip=payload.startsWith("{")?new JSONObject(payload).getString("ip"):payload;
            if(ip.equals("0.0.0.0")){
                listener.status("工作台正在连接Wi-Fi，稍后自动重试…");
                if(++reads<8){handler.postDelayed(()->readAgain(g),2000);return;}
                finish("工作台还没有可用IP，请检查它的Wi-Fi连接");return;
            }
            String[] parts=ip.split("\\.",-1);
            if(parts.length!=4)throw new Exception();
            for(String p:parts)if(!p.matches("[0-9]{1,3}")||Integer.parseInt(p)>255)throw new Exception();
            String address="http://"+ip;
            close();listener.found(address);
        }catch(Exception e){
            if(++reads<3){listener.status("正在重新读取设备地址…");handler.postDelayed(()->readAgain(g),1200);return;}
            finish("蓝牙地址数据不完整，请重试或更新设备固件");
        }
    });}
    void readAgain(BluetoothGatt g){
        if(!active||g!=gatt)return;
        try{BluetoothGattService service=g.getService(SERVICE);if(service==null||!g.readCharacteristic(service.getCharacteristic(ENDPOINT)))finish("重新读取地址失败，请重试");}catch(Exception e){finish("连接已断开，请重试");}
    }
    void finish(String message){handler.post(()->{if(!active)return;close();listener.status(message);});}
    void close(){
        active=false;handler.removeCallbacks(timeout);
        try{if(scanner!=null)scanner.stopScan(scan);}catch(Exception ignored){}
        scanner=null;
        if(gatt!=null){try{gatt.disconnect();gatt.close();}catch(Exception ignored){}gatt=null;}
    }
}
