package com.nirniq.kith

import io.flutter.app.FlutterApplication

class KithApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        // Register notification channels on application startup
        // This ensures channels exist in Android NotificationManager before
        // any background FCM push or headless service is invoked by the OS.
        KithNotificationHelper.createNotificationChannel(this)
    }
}
