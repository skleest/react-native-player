package com.xeodou.rctplayer;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.support.annotation.Nullable;
import android.telephony.PhoneStateListener;
import android.telephony.TelephonyManager;
import android.util.Log;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.xeodou.rctplayer.ReactPlayerManager;

/**
 * Created by hunkyojung on 2016. 12. 28..
 */

public class CallReceiver extends BroadcastReceiver {
    Boolean isStateIdle = true;
    TelephonyManager telManager;
    Context context;

    private static final String TAG = "CallReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        Log.d(TAG, "onReceive");
        this.context = context;

        telManager = (TelephonyManager)context.getSystemService(Context.TELEPHONY_SERVICE);
        telManager.listen(phoneListener, PhoneStateListener.LISTEN_CALL_STATE);
    }

    private final PhoneStateListener phoneListener = new PhoneStateListener() {
        @Override
        public void onCallStateChanged(int state, String incomingNumber) {
            Log.d(TAG, "onCallStateChanged" + incomingNumber);
            try {
                switch (state) {
                    case TelephonyManager.CALL_STATE_IDLE: {
                        if (isStateIdle) {
                            Log.d(TAG, "CALL_STATE_IDLE");
                            onPlaybackStateChanged("playing");
                            isStateIdle = true;
                        }
                        break;
                    }
                    case TelephonyManager.CALL_STATE_OFFHOOK: {
                        isStateIdle = false;
                        Log.d(TAG, "CALL_STATE_OFFHOOK");
                        onPlaybackStateChanged("paused");
                        break;
                    }
                    case TelephonyManager.CALL_STATE_RINGING: {
                        isStateIdle = false;
                        Log.d(TAG, "CALL_STATE_RINGING");
                        onPlaybackStateChanged("paused");
                        break;
                    }
                    default: {}
                }
            } catch (Exception ex) {

            }
        }
    };

    private void sendEvent(String eventName,
                           @Nullable WritableMap params) {

        ReactApplicationContext context = ReactPlayerManager.getContext();
        if(context == null) {
            return;
        }

        ReactPlayerManager.getContext()
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
    }

    public void onPlaybackStateChanged(String playbackState) {
        WritableMap params = Arguments.createMap();
        params.putString("state", playbackState);

        sendEvent("onPlaybackStateChanged", params);
    }
}
