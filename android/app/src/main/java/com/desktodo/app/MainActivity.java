package com.desktodo.app;
import android.app.Activity;
import android.Manifest;
import android.os.Build;
import android.content.pm.PackageManager;
import android.widget.TextView;
import android.os.Bundle;
import android.app.AlertDialog;
import android.content.SharedPreferences;
import android.net.Uri;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Button;
public class MainActivity extends Activity {
    WebView web;
    String origin;
    TextView connection;
    BleDiscovery discovery;
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout layout=new LinearLayout(this); layout.setOrientation(LinearLayout.VERTICAL);
        Button bluetooth=new Button(this);bluetooth.setText("蓝牙连接工作台");layout.addView(bluetooth);
        connection=new TextView(this);connection.setPadding(16,8,16,8);layout.addView(connection);
        discovery=new BleDiscovery(this,new BleDiscovery.Listener(){
            public void status(String message){
                String device=getPreferences(MODE_PRIVATE).getString("deviceServer","");
                if(!device.isEmpty()&&device.equals(origin)&&(message.contains("断开")||message.contains("未找到")||message.contains("不完整")))
                    connection.setText("蓝牙发现暂时中断；已保存地址 "+device+"，可继续使用直连页面");
                else connection.setText(message);
            }
            public void found(String address){
                getPreferences(MODE_PRIVATE).edit().putString("server",address).putString("deviceServer",address).apply();
                connection.setText("已自动填入 "+address+"；手机与工作台须在同一局域网");open(address);
            }
        });
        bluetooth.setOnClickListener(v->discover());
        Button settings=new Button(this); settings.setText("设置服务地址"); layout.addView(settings);
        web=new WebView(this); layout.addView(web,new LinearLayout.LayoutParams(-1,0,1)); setContentView(layout);
        web.getSettings().setJavaScriptEnabled(true);
        web.getSettings().setAllowFileAccess(false); web.getSettings().setAllowContentAccess(false);
        web.setWebViewClient(new WebViewClient(){@Override public boolean shouldOverrideUrlLoading(WebView view,String url){Uri u=Uri.parse(url);return origin==null||!origin.equals(u.getScheme()+"://"+u.getAuthority());}});
        settings.setOnClickListener(v->configure());
        String saved=getPreferences(MODE_PRIVATE).getString("server","");
        if(!saved.isEmpty())open(saved);
        discover();
    }
    void discover(){
        String[] permissions=Build.VERSION.SDK_INT>=31?new String[]{Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_CONNECT}:new String[]{Manifest.permission.ACCESS_FINE_LOCATION};
        for(String p:permissions)if(checkSelfPermission(p)!=PackageManager.PERMISSION_GRANTED){requestPermissions(permissions,21);return;}
        discovery.start();
    }
    @Override public void onRequestPermissionsResult(int request,String[] permissions,int[] results){
        super.onRequestPermissionsResult(request,permissions,results);
        if(request==21){for(int result:results)if(result!=PackageManager.PERMISSION_GRANTED){connection.setText("蓝牙权限未授予，可手动设置地址");return;}if(results.length>0)discovery.start();}
    }
    @Override protected void onStop(){super.onStop();if(discovery!=null)discovery.close();}
    @Override protected void onDestroy(){if(discovery!=null)discovery.close();if(web!=null)web.destroy();super.onDestroy();}
    void open(String url){Uri uri=Uri.parse(url);origin=uri.getScheme()+"://"+uri.getAuthority();web.loadUrl(origin+"/");}
    void configure(){EditText input=new EditText(this);input.setSingleLine(true);input.setHint("http://ESP32的IP 或 http://Mac的IP:8787");input.setText(getPreferences(MODE_PRIVATE).getString("server","http://"));new AlertDialog.Builder(this).setTitle("工作台地址（蓝牙可自动填写）").setView(input).setNegativeButton("取消",null).setPositiveButton("连接",(dialog,which)->{String value=input.getText().toString().trim();Uri u=Uri.parse(value);if(("http".equals(u.getScheme())||"https".equals(u.getScheme()))&&u.getHost()!=null&&u.getUserInfo()==null){getPreferences(MODE_PRIVATE).edit().putString("server",value).apply();open(value);}else configure();}).show();}
}
