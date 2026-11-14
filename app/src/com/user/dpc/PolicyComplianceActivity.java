package com.user.dpc;

import android.app.Activity;
import android.os.Bundle;

/** Required on Android 10+: runs at the end of setup. Apply initial policies here. */
public class PolicyComplianceActivity extends Activity {
    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        setResult(RESULT_OK);
        finish();
    }
}
