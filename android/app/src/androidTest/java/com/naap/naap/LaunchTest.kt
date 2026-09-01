// LaunchTest.kt — the cheapest possible "does the app actually come up on a
// real phone" gate (same pattern as Tern's Device Farm smoke). Launching
// MainActivity to RESUMED on rented hardware proves the APK installs, the
// Flutter engine and ML Kit native libraries resolve for the device's ABI,
// and the first frame renders (the Dart side logs NAAPSMOKE_BOOT_OK, which
// scripts/devicefarm_smoke.py requires in the device log).

package com.naap.naap

import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.rule.GrantPermissionRule
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LaunchTest {

    // Granting CAMERA up front keeps any permission dialog from covering the
    // activity on the farm device (the home screen doesn't ask, but a covered
    // activity never reaches RESUMED and the run times out — Tern hit this).
    @get:Rule
    val camera: GrantPermissionRule =
        GrantPermissionRule.grant(android.Manifest.permission.CAMERA)

    @Test
    fun mainActivityReachesResumed() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            scenario.moveToState(Lifecycle.State.RESUMED)
            assertEquals(Lifecycle.State.RESUMED, scenario.state)
            Log.i("NAAPSMOKE", "NAAPSMOKE_LAUNCH: activity=RESUMED")
            // Give the Flutter engine time to boot Dart and paint the first
            // frame so NAAPSMOKE_BOOT_OK lands in the device log.
            Thread.sleep(10_000)
        }
        Log.i("NAAPSMOKE", "NAAPSMOKE_LAUNCH_OK")
    }
}
