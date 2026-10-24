package com.kingdomain.king_domain

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createUpdatesChannel()
    }

    /**
     * Pushes are sent to this channel (backend src/push.js CHANNEL_ID, and the default channel in the
     * manifest). It has to exist before the first push arrives while the app is closed, and the app has
     * always been opened once by then, because that is when it registers for pushes.
     */
    private fun createUpdatesChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel("kd_updates", "Job updates", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "When you are picked, paid, or asked for something on a job"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
