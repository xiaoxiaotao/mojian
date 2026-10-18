package com.desktodo.app;

import android.content.Context;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** API credentials stay in private storage encrypted by the Android Keystore. */
final class AgentVault {
    private static final String ALIAS="mojian.deepseek.v1";
    static SecretKey key() throws Exception {
        KeyStore store=KeyStore.getInstance("AndroidKeyStore");store.load(null);
        if(store.containsAlias(ALIAS))return (SecretKey)store.getKey(ALIAS,null);
        KeyGenerator generator=KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(ALIAS,KeyProperties.PURPOSE_ENCRYPT|KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
        return generator.generateKey();
    }
    static void put(Context context,String value)throws Exception {put(context,"deepseek",value);}
    static void put(Context context,String scope,String value)throws Exception {
        if(value==null||value.trim().isEmpty())throw new Exception("密钥不能为空；清除请使用专用按钮");
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.ENCRYPT_MODE,key());
        String iv=Base64.encodeToString(cipher.getIV(),Base64.NO_WRAP);
        String encrypted=Base64.encodeToString(cipher.doFinal(value.trim().getBytes(java.nio.charset.StandardCharsets.UTF_8)),Base64.NO_WRAP);
        if(!context.getSharedPreferences(scope.equals("deepseek")?"mojian-agent-vault":"mojian-vault-"+scope,0).edit().putString("iv",iv).putString("key",encrypted).commit())throw new Exception("密钥保存失败");
    }
    static String get(Context context)throws Exception {return get(context,"deepseek");}
    static String get(Context context,String scope)throws Exception {
        android.content.SharedPreferences p=context.getSharedPreferences(scope.equals("deepseek")?"mojian-agent-vault":"mojian-vault-"+scope,0);String value=p.getString("key","");if(value.isEmpty())return "";
        try{Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.DECRYPT_MODE,key(),new GCMParameterSpec(128,Base64.decode(p.getString("iv",""),Base64.NO_WRAP)));return new String(cipher.doFinal(Base64.decode(value,Base64.NO_WRAP)),java.nio.charset.StandardCharsets.UTF_8);}catch(Exception e){throw new Exception("无法解密模型密钥，请重新配置");}
    }
    static boolean configured(Context context){return context.getSharedPreferences("mojian-agent-vault",0).contains("key");}
    static void clear(Context context){context.getSharedPreferences("mojian-agent-vault",0).edit().clear().commit();}
}
