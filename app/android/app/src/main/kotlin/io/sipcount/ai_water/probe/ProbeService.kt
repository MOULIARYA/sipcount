package io.sipcount.ai_water.probe

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Spike only (I-60) — not part of the shipping app.
 *
 * Why a service at all: the whole run happens while the person is inside ChatGPT, which means
 * Sipcount is backgrounded for every second that matters. Android freezes cached processes within
 * seconds, so a timer owned by the screen would stop sampling exactly when the data starts, and
 * hand back an empty log that reads as "the phone cannot see a prompt". A foreground service is
 * what makes the ten minutes actually get recorded.
 *
 * The notification is not decoration: it is the honest signal that something is sampling.
 */
class ProbeService : Service() {

    companion object {
        private const val CHANNEL = "sipcount_probe"
        private const val ID = 4711

        fun start(ctx: Context) {
            val i = Intent(ctx, ProbeService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ctx.startForegroundService(i) else ctx.startService(i)
        }

        fun stop(ctx: Context) = ctx.stopService(Intent(ctx, ProbeService::class.java))
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Android 14 refuses a foreground service that does not say what it is for.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(ID, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(ID, notification())
        }
        if (!NetworkProbe.startSampling(applicationContext)) {
            stopSelf()          // usage access revoked, or none of the three apps installed
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onDestroy() {
        NetworkProbe.stopSampling()
        super.onDestroy()
    }

    private fun notification(): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Sensor probe", NotificationManager.IMPORTANCE_LOW)
                    .apply { description = "Shown only while the test build is recording byte counts." }
            )
            return Notification.Builder(this, CHANNEL)
                .setContentTitle("Sipcount is recording byte counts")
                .setContentText("Test build only. No addresses, no content.")
                .setSmallIcon(android.R.drawable.stat_sys_download)
                .setOngoing(true)
                .build()
        }
        @Suppress("DEPRECATION")
        return Notification.Builder(this)
            .setContentTitle("Sipcount is recording byte counts")
            .setContentText("Test build only. No addresses, no content.")
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .build()
    }
}
