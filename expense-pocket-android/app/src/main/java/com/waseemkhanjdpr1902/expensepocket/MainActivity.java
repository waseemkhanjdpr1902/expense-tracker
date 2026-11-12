package com.waseemkhanjdpr1902.expensepocket;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Base64;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import androidx.webkit.WebViewAssetLoader;
import java.io.OutputStream;

public class MainActivity extends Activity {
    private static final int PICK_FILE = 100, SAVE_FILE = 101;
    private WebView view;
    private ValueCallback<Uri[]> pendingPick;
    private byte[] pendingSave;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        WebViewAssetLoader assets = new WebViewAssetLoader.Builder()
            .addPathHandler("/", path -> new WebViewAssetLoader.AssetsPathHandler(this).handle("website/" + path)).build();
        view = new WebView(this);
        view.getSettings().setJavaScriptEnabled(true);
        view.getSettings().setDomStorageEnabled(true);
        view.getSettings().setAllowFileAccess(false);
        view.getSettings().setAllowContentAccess(true);
        view.addJavascriptInterface(new SaveBridge(), "ExpensePocketAndroid");
        view.setWebViewClient(new WebViewClient() {
            @Override public WebResourceResponse shouldInterceptRequest(WebView v, WebResourceRequest request) {
                return assets.shouldInterceptRequest(request.getUrl());
            }
            @Override public void onPageFinished(WebView v, String url) {
                if ("https://appassets.androidplatform.net/index.html".equals(url) || "https://appassets.androidplatform.net/".equals(url)) {
                    v.evaluateJavascript("window.download=function(n,c,t){var a=new TextEncoder().encode(c),s='';for(var i=0;i<a.length;i++)s+=String.fromCharCode(a[i]);ExpensePocketAndroid.save(n,t,btoa(s));};", null);
                }
            }
            @Override public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest request) {
                Uri u=request.getUrl();
                if ("https".equals(u.getScheme()) && "appassets.androidplatform.net".equals(u.getHost())) return false;
                if ("https".equals(u.getScheme()) || "http".equals(u.getScheme())) {
                    try { startActivity(new Intent(Intent.ACTION_VIEW, u)); } catch (Exception ignored) {}
                }
                return true;
            }
        });
        view.setWebChromeClient(new WebChromeClient() {
            @Override public boolean onShowFileChooser(WebView w, ValueCallback<Uri[]> cb, FileChooserParams params) {
                if (pendingPick != null) pendingPick.onReceiveValue(null);
                pendingPick=cb;
                try { startActivityForResult(params.createIntent(), PICK_FILE); return true; }
                catch (Exception ex) { pendingPick=null; return false; }
            }
        });
        setContentView(view);
        view.loadUrl("https://appassets.androidplatform.net/index.html");
    }
    private class SaveBridge {
        @JavascriptInterface public void save(String name, String type, String encoded) {
            try {
                final byte[] bytes=Base64.decode(encoded,Base64.DEFAULT);
                if (bytes.length > 10 * 1024 * 1024) return;
                runOnUiThread(() -> {
                    if (pendingSave != null) return;
                    pendingSave=bytes;
                    Intent intent=new Intent(Intent.ACTION_CREATE_DOCUMENT);
                    intent.addCategory(Intent.CATEGORY_OPENABLE);
                    intent.setType(type.equals("application/json") ? "application/json" : "text/csv");
                    intent.putExtra(Intent.EXTRA_TITLE, type.equals("application/json") ? "expense-pocket-backup.json" : "expense-pocket-transactions.csv");
                    try { startActivityForResult(intent,SAVE_FILE); } catch (Exception ex) { pendingSave=null; }
                });
            } catch (Exception ignored) {}
        }
    }
    @Override protected void onActivityResult(int request,int result,Intent data) {
        super.onActivityResult(request,result,data);
        if (request==PICK_FILE && pendingPick!=null) {
            pendingPick.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(result,data)); pendingPick=null;
        }
        if (request==SAVE_FILE) {
            byte[] bytes=pendingSave; pendingSave=null;
            if (result==RESULT_OK && data!=null && data.getData()!=null && bytes!=null) {
                try (OutputStream out=getContentResolver().openOutputStream(data.getData())) { if(out!=null) out.write(bytes); } catch (Exception ignored) {}
            }
        }
    }
    @Override public void onBackPressed() { if(view.canGoBack()) view.goBack(); else super.onBackPressed(); }
}
