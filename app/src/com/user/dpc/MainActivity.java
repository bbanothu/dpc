package com.user.dpc;

import android.app.Activity;
import android.app.admin.DevicePolicyManager;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.TextView;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        DevicePolicyManager dpm = getSystemService(DevicePolicyManager.class);
        boolean owner = dpm.isDeviceOwnerApp(getPackageName());
        TextView t = new TextView(this);
        t.setGravity(Gravity.CENTER);
        t.setTextSize(22);
        t.setPadding(48, 48, 48, 48);
        t.setText(owner ? "User DPC\n\nDevice owner: YES\nThis device is fully managed."
                        : "User DPC\n\nDevice owner: NO\nProvision with the QR code from a factory reset.");
        setContentView(t);
    }
}
