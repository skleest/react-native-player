/*
* @Author: xeodou
* @Date:   2015
*/
package com.xeodou.rctplayer;

import com.facebook.react.ReactPackage;
import com.facebook.react.bridge.JavaScriptModule;
import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.uimanager.ViewManager;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;


public class ReactPlayerManager implements ReactPackage {

    private static ReactApplicationContext context = null;

    @Override
    public List<Class<? extends JavaScriptModule>> createJSModules() {
        return Collections.emptyList();
    }

    @Override
    public List<ViewManager> createViewManagers(ReactApplicationContext reactContext) {
        return Collections.emptyList();
    }

    @Override
    public List<NativeModule> createNativeModules(
            ReactApplicationContext reactContext) {

        context = reactContext;

        List<NativeModule> modules = new ArrayList<>();
        modules.add(new ReactAudio(reactContext));

        return modules;
    }

    public static ReactApplicationContext getContext() {
        return context;
    }

}
