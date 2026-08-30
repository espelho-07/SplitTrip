package com.nirniq.kith

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object KithNotificationHelper {
    const val CHANNEL_ID = "kith_activity"
    const val CHANNEL_NAME = "Kith Activity"
    const val CHANNEL_ID_PAYMENTS = "kith_payments"
    const val CHANNEL_NAME_PAYMENTS = "Kith Payments & Settlements"

    fun getSoundUri(context: Context): Uri {
        return Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://${context.packageName}/${R.raw.kith_notification}")
    }

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager: NotificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val soundUri = getSoundUri(context)
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val subtleVibrationPattern = longArrayOf(0, 100, 50, 80)

            // 1. Activity channel (Expenses, Member Updates, Trip Events)
            val activityChannel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Expenses, member updates, and trip activity alerts"
                enableLights(true)
                enableVibration(true)
                vibrationPattern = subtleVibrationPattern
                setSound(soundUri, audioAttributes)
            }
            notificationManager.createNotificationChannel(activityChannel)

            // 2. Dedicated payments channel (Payment Confirmations, Settlement Requests)
            val paymentsChannel = NotificationChannel(CHANNEL_ID_PAYMENTS, CHANNEL_NAME_PAYMENTS, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Payment confirmations, settlement requests, and payment proof notifications"
                enableLights(true)
                enableVibration(true)
                vibrationPattern = subtleVibrationPattern
                setSound(soundUri, audioAttributes)
            }
            notificationManager.createNotificationChannel(paymentsChannel)
        }
    }

    fun showNotification(
        context: Context,
        id: Int,
        title: String,
        body: String,
        route: String? = null
    ) {
        createNotificationChannel(context)

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (!route.isNullOrEmpty()) {
                val uriStr = if (route.startsWith("kith://")) route else "kith://kith.app$route"
                data = Uri.parse(uriStr)
            }
        }

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            id,
            intent,
            pendingIntentFlags
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setSound(getSoundUri(context))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        try {
            val notificationManager = NotificationManagerCompat.from(context)
            notificationManager.notify(id, builder.build())
        } catch (_: SecurityException) {
            // Android 13+ permission catch
        }
    }
}
