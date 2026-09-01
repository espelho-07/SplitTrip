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
    const val CHANNEL_ID_EXPENSES = "kith_expenses"
    const val CHANNEL_NAME_EXPENSES = "Kith Expenses"
    const val CHANNEL_ID_TRIPS = "kith_trips"
    const val CHANNEL_NAME_TRIPS = "Kith Trips & Members"
    const val CHANNEL_ID_IPO = "kith_ipo"
    const val CHANNEL_NAME_IPO = "Kith IPO Alerts & Milestones"

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

            // 1. Dedicated payments channel (HIGH Priority)
            val paymentsChannel = NotificationChannel(CHANNEL_ID_PAYMENTS, CHANNEL_NAME_PAYMENTS, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Payment confirmations, settlement requests, and payment proof notifications"
                enableLights(true)
                enableVibration(true)
                vibrationPattern = subtleVibrationPattern
                setSound(soundUri, audioAttributes)
            }
            notificationManager.createNotificationChannel(paymentsChannel)

            // 2. Expenses channel (HIGH Priority for closed-app heads-up delivery)
            val expensesChannel = NotificationChannel(CHANNEL_ID_EXPENSES, CHANNEL_NAME_EXPENSES, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "New expense alerts, edits, and split updates"
                enableLights(true)
                enableVibration(true)
                vibrationPattern = subtleVibrationPattern
                setSound(soundUri, audioAttributes)
            }
            notificationManager.createNotificationChannel(expensesChannel)

            // 3. Trips & Members channel (HIGH Priority)
            val tripsChannel = NotificationChannel(CHANNEL_ID_TRIPS, CHANNEL_NAME_TRIPS, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Trip invites, member join alerts, and trip status updates"
                enableLights(true)
                enableVibration(true)
                vibrationPattern = subtleVibrationPattern
                setSound(soundUri, audioAttributes)
            }
            notificationManager.createNotificationChannel(tripsChannel)

            // 4. Activity channel (HIGH Priority)
            val activityChannel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "General collaboration and balance updates"
                enableLights(true)
                enableVibration(true)
                vibrationPattern = subtleVibrationPattern
                setSound(soundUri, audioAttributes)
            }
            notificationManager.createNotificationChannel(activityChannel)

            // 5. IPO channel (HIGH Priority)
            val ipoChannel = NotificationChannel(CHANNEL_ID_IPO, CHANNEL_NAME_IPO, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "IPO bidding reminders, allotment status, and listing alerts"
                enableLights(true)
                enableVibration(true)
                vibrationPattern = subtleVibrationPattern
                setSound(soundUri, audioAttributes)
            }
            notificationManager.createNotificationChannel(ipoChannel)
        }
    }

    fun showNotification(
        context: Context,
        id: Int,
        title: String,
        body: String,
        route: String? = null,
        channelId: String? = null
    ) {
        createNotificationChannel(context)

        val selectedChannel = channelId ?: CHANNEL_ID_PAYMENTS

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

        val builder = NotificationCompat.Builder(context, selectedChannel)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(if (selectedChannel == CHANNEL_ID_PAYMENTS) NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_DEFAULT)
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
