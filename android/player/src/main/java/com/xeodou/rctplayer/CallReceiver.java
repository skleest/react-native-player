package com.xeodou.rctplayer;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.support.v4.content.LocalBroadcastManager;
import android.telephony.PhoneStateListener;
import android.telephony.TelephonyManager;
import android.util.Log;

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
                            sendMessage("playing");
                            isStateIdle = true;
                        }
                        break;
                    }
                    case TelephonyManager.CALL_STATE_OFFHOOK: {
                        isStateIdle = false;
                        Log.d(TAG, "CALL_STATE_OFFHOOK");
                        sendMessage("paused");
                        break;
                    }
                    case TelephonyManager.CALL_STATE_RINGING: {
                        isStateIdle = false;
                        Log.d(TAG, "CALL_STATE_RINGING");
                        sendMessage("paused");
                        break;
                    }
                    default: {}
                }
            } catch (Exception ex) {

            }
        }
    };

    private void sendMessage(String state) {
        Log.d("sender", "Broadcasting message");
        Intent intent = new Intent("call-state-event");
        // You can also include some extra data.
        intent.putExtra("state", state);
        LocalBroadcastManager.getInstance(context).sendBroadcast(intent);
    }

//    public void onPlaybackStateChanged(String playbackState) {
//        WritableMap params = Arguments.createMap();
//        params.putString("state", playbackState);
//    }

//    public class LocalBroadcastService extends IntentService {
//
//        private static final String TAG = "LocalBroadcastService";
//
//        public InternalService() {
//            super("LocalBroadcastService");
//            Log.i(TAG, "Creating intent service.");
//        }
//
//        @Override
//        protected void onHandleIntent(Intent intent) {
//            LocalBroadcastManager localBroadcastManager = LocalBroadcastManager.getInstance(this);
//            Intent customEvent= new Intent("my-custom-event");
//            customEvent.putExtra("my-extra-data", "that's it");
//            localBroadcastManager.sendBroadcast(customEvent);
//        }
//    }
}
