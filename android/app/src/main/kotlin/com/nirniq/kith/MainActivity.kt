package com.nirniq.kith

import android.app.Activity
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.ContactsContract
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.nirniq.kith/widgets"
    private val CONTACTS_CHANNEL = "com.nirniq.kith/contacts"
    private val REQUEST_CODE_PICK_CONTACT = 4242

    private var initialDeepLink: String? = null
    private var pendingContactPickerResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Create notification channels at startup — required before FCM can deliver
        KithNotificationHelper.createNotificationChannel(applicationContext)
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

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_CONTACT) {
            val result = pendingContactPickerResult
            pendingContactPickerResult = null
            if (resultCode == Activity.RESULT_OK && data != null && data.data != null) {
                try {
                    val contactUri: Uri = data.data!!
                    val cursor = contentResolver.query(
                        contactUri,
                        arrayOf(
                            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                            ContactsContract.CommonDataKinds.Phone.NUMBER,
                            ContactsContract.CommonDataKinds.Phone.PHOTO_URI
                        ),
                        null,
                        null,
                        null
                    )
                    var contactMap: Map<String, Any?>? = null
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                            val numIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                            val photoIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.PHOTO_URI)

                            val name = if (nameIdx != -1) it.getString(nameIdx) else ""
                            val phone = if (numIdx != -1) it.getString(numIdx) else ""
                            val photo = if (photoIdx != -1) it.getString(photoIdx) else null

                            contactMap = mapOf(
                                "name" to (name ?: ""),
                                "phone" to (phone ?: ""),
                                "photo" to photo
                            )
                        }
                    }
                    result?.success(contactMap)
                } catch (e: Exception) {
                    result?.success(null)
                }
            } else {
                result?.success(null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Contacts Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTACTS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickContact" -> {
                    try {
                        pendingContactPickerResult = result
                        val pickIntent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
                        startActivityForResult(pickIntent, REQUEST_CODE_PICK_CONTACT)
                    } catch (e: Exception) {
                        pendingContactPickerResult = null
                        result.error("PICK_FAILED", e.message, null)
                    }
                }
                "getContacts" -> {
                    val query = call.argument<String>("query")?.trim()?.lowercase()
                    val limit = call.argument<Int>("limit") ?: 100

                    if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
                        result.success(emptyList<Map<String, Any?>>())
                        return@setMethodCallHandler
                    }

                    try {
                        val contactsList = mutableListOf<Map<String, Any?>>()
                        val seen = mutableSetOf<String>()

                        val projection = arrayOf(
                            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                            ContactsContract.CommonDataKinds.Phone.NUMBER,
                            ContactsContract.CommonDataKinds.Phone.PHOTO_URI
                        )

                        val selection = if (!query.isNullOrEmpty()) {
                            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ? OR ${ContactsContract.CommonDataKinds.Phone.NUMBER} LIKE ?"
                        } else null

                        val selectionArgs = if (!query.isNullOrEmpty()) {
                            arrayOf("%$query%", "%$query%")
                        } else null

                        val cursor = contentResolver.query(
                            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                            projection,
                            selection,
                            selectionArgs,
                            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC LIMIT $limit"
                        )

                        cursor?.use {
                            val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                            val numIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                            val photoIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.PHOTO_URI)

                            while (it.moveToNext() && contactsList.size < limit) {
                                val name = if (nameIdx != -1) it.getString(nameIdx) else ""
                                val rawPhone = if (numIdx != -1) it.getString(numIdx) else ""
                                val photo = if (photoIdx != -1) it.getString(photoIdx) else null

                                val cleanPhone = rawPhone.replace("\\s+".toRegex(), "").replace("-", "")
                                val dedupKey = "$name:$cleanPhone"

                                if (name.isNotEmpty() && !seen.contains(dedupKey)) {
                                    seen.add(dedupKey)
                                    contactsList.add(
                                        mapOf(
                                            "name" to name,
                                            "phone" to cleanPhone,
                                            "photo" to photo
                                        )
                                    )
                                }
                            }
                        }
                        result.success(contactsList)
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, Any?>>())
                    }
                }
                else -> result.notImplemented()
            }
        }

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
                    val channelId = call.argument<String>("channelId")
                    KithNotificationHelper.showNotification(applicationContext, id, title, body, route, channelId)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
