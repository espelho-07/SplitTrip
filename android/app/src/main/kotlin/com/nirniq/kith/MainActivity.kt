package com.nirniq.kith

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.nirniq.kith/widgets"
    private var initialDeepLink: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val uri: Uri? = intent?.data
        if (uri != null) {
            val deepLink = uri.toString()
            initialDeepLink = deepLink
            flutterEngine?.let { engine ->
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onDeepLink", deepLink)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Widget Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgets" -> {
                    KithWidgetHelper.updateAllWidgets(applicationContext)
                    result.success(true)
                }
                "isPinningSupported" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                        result.success(appWidgetManager.isRequestPinAppWidgetSupported)
                    } else {
                        result.success(false)
                    }
                }
                "requestPinWidget" -> {
                    val widgetType = call.argument<String>("type") ?: "snapshot"
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                        if (appWidgetManager.isRequestPinAppWidgetSupported) {
                            val providerClass = when (widgetType) {
                                "quick_add" -> QuickAddWidgetProvider::class.java
                                "budget" -> BudgetWidgetProvider::class.java
                                "debts" -> DebtsWidgetProvider::class.java
                                "trip" -> TripWidgetProvider::class.java
                                "smart" -> SmartKithWidgetProvider::class.java
                                else -> KithSnapshotWidgetProvider::class.java
                            }
                            val myProvider = ComponentName(applicationContext, providerClass)
                            val pinned = appWidgetManager.requestPinAppWidget(myProvider, null, null)
                            result.success(pinned)
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "getInitialDeepLink" -> {
                    result.success(initialDeepLink)
                }
                else -> result.notImplemented()
            }
        }

        // Native Notifications Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nirniq.kith/notifications").setMethodCallHandler { call, result ->
            when (call.method) {
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: (System.currentTimeMillis() % 100000).toInt()
                    val title = call.argument<String>("title") ?: "Kith"
                    val body = call.argument<String>("body") ?: ""
                    val route = call.argument<String>("route")
                    KithNotificationHelper.showNotification(applicationContext, id, title, body, route)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
