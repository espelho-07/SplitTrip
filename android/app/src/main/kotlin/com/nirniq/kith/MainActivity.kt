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
    private val MIGRATION_CHANNEL = "com.kith.migration/channel"
    private val BLE_CHANNEL = "com.nirniq.kith/ble_discovery"
    private val REQUEST_CODE_PICK_CONTACT = 4242
    private val REQUEST_CODE_SAF_CREATE = 4243
    private var pendingSafCreateResult: MethodChannel.Result? = null
    private var pendingSafCreateContent: String? = null

    private var bleManager: KithBleManager? = null
    private var initialDeepLink: String? = null
    private var flutterEngineInstance: FlutterEngine? = null
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
        val routeExtra: String? = intent?.getStringExtra("route")
            ?: intent?.extras?.getString("route")
            ?: intent?.extras?.getString("tripId")?.let { tripId ->
                val expenseId = intent.extras?.getString("expenseId")
                val settlementId = intent.extras?.getString("settlementId")
                if (!expenseId.isNullOrEmpty()) {
                    "/trip/$tripId?expenseId=$expenseId"
                } else if (!settlementId.isNullOrEmpty()) {
                    "/trip/$tripId?settlementId=$settlementId"
                } else {
                    "/trip/$tripId"
                }
            }
        val deepLink = uri?.toString() ?: routeExtra?.let {
            if (it.startsWith("kith://")) it else "kith://kith.app$it"
        }
        if (deepLink != null) {
            val redacted = redactDeepLink(deepLink)
            android.util.Log.d(TAG, "handleIntent: deepLink=$redacted")
            initialDeepLink = deepLink
            flutterEngineInstance?.let { engine ->
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onDeepLink", deepLink)
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_SAF_CREATE) {
            val result = pendingSafCreateResult
            val content = pendingSafCreateContent
            pendingSafCreateResult = null
            pendingSafCreateContent = null
            if (resultCode == Activity.RESULT_OK && data != null && data.data != null && content != null) {
                try {
                    val uri: Uri = data.data!!
                    contentResolver.openOutputStream(uri)?.use { os ->
                        os.write(content.toByteArray(Charsets.UTF_8))
                        os.flush()
                    }
                    result?.success(uri.toString())
                } catch (e: Exception) {
                    result?.error("WRITE_FAILED", e.message, null)
                }
            } else {
                result?.success(null)
            }
            return
        }
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

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        flutterEngineInstance = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngineInstance = flutterEngine

        // Migration Channel for Cross-App SAF & Share Intent
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MIGRATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(true)
                "saveFileViaSAF" -> {
                    val fileName = call.argument<String>("fileName") ?: "kith_finances_migration.json"
                    val content = call.argument<String>("content")
                    val mimeType = call.argument<String>("mimeType") ?: "application/json"
                    if (content == null) {
                        result.error("INVALID_ARGS", "Content cannot be null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        pendingSafCreateResult = result
                        pendingSafCreateContent = content
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = mimeType
                            putExtra(Intent.EXTRA_TITLE, fileName)
                        }
                        startActivityForResult(intent, REQUEST_CODE_SAF_CREATE)
                    } catch (e: Exception) {
                        pendingSafCreateResult = null
                        pendingSafCreateContent = null
                        result.error("SAF_ERROR", e.message, null)
                    }
                }
                "sharePayload" -> {
                    val title = call.argument<String>("title") ?: "Share Financial Migration Archive"
                    val content = call.argument<String>("content") ?: ""
                    val subject = call.argument<String>("subject") ?: "Kith Financial Migration Archive"
                    try {
                        val sendIntent = Intent().apply {
                            action = Intent.ACTION_SEND
                            putExtra(Intent.EXTRA_TEXT, content)
                            putExtra(Intent.EXTRA_SUBJECT, subject)
                            type = "text/plain"
                        }
                        val shareIntent = Intent.createChooser(sendIntent, title)
                        startActivity(shareIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

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
                    initialDeepLink = null
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

        // Bluetooth Low Energy (BLE) Mesh & Nearby Discovery Channel
        val bleMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLE_CHANNEL)
        bleManager = KithBleManager(applicationContext, bleMethodChannel)
        bleMethodChannel.setMethodCallHandler { call, result ->
            val mgr = bleManager
            if (mgr == null) {
                result.error("UNAVAILABLE", "BLE Manager not initialized", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "isSupported" -> result.success(mgr.isSupported())
                "isEnabled" -> result.success(mgr.isEnabled())
                "hasPermissions" -> result.success(mgr.hasPermissions())
                "startAdvertising" -> {
                    val tripTokenHash = call.argument<Int>("tripTokenHash") ?: 0
                    val deviceIdHash = call.argument<Number>("deviceIdHash")?.toLong() ?: 0L
                    val userIdHash = call.argument<Int>("userIdHash") ?: 0
                    val ok = mgr.startAdvertising(tripTokenHash, deviceIdHash, userIdHash)
                    result.success(ok)
                }
                "stopAdvertising" -> {
                    mgr.stopAdvertising()
                    result.success(true)
                }
                "startScanning" -> {
                    val tripTokenHash = call.argument<Int>("tripTokenHash") ?: 0
                    val deviceIdHash = call.argument<Number>("deviceIdHash")?.toLong() ?: 0L
                    val ok = mgr.startScanning(tripTokenHash, deviceIdHash)
                    result.success(ok)
                }
                "stopScanning" -> {
                    mgr.stopScanning()
                    result.success(true)
                }
                "stopAll" -> {
                    mgr.stopAll()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onStop() {
        bleManager?.stopAll()
        super.onStop()
    }

    override fun onDestroy() {
        bleManager?.stopAll()
        bleManager = null
        try {
            pendingSafCreateResult?.error("ACTIVITY_DESTROYED", "Activity was destroyed before SAF operation completed", null)
        } catch (_: Exception) {}
        pendingSafCreateResult = null
        pendingSafCreateContent = null
        try {
            pendingContactPickerResult?.error("ACTIVITY_DESTROYED", "Activity was destroyed before Contact picker completed", null)
        } catch (_: Exception) {}
        pendingContactPickerResult = null
        flutterEngineInstance = null
        super.onDestroy()
    }
    companion object {
        private const val TAG = "MainActivity"
        private val SENSITIVE_QUERY_PARAMS = setOf(
            "token",
            "claimtoken",
            "secret",
            "p2p_secret",
            "p2psecret",
            "key",
            "s",
            "password",
            "auth",
            "authorization",
            "bearer"
        )

        fun redactDeepLink(uriString: String?): String {
            if (uriString.isNullOrBlank()) return ""
            return try {
                val uri = Uri.parse(uriString)
                val queryNames = uri.queryParameterNames
                if (queryNames.isNullOrEmpty()) {
                    uriString
                } else {
                    val builder = uri.buildUpon().clearQuery()
                    for (param in queryNames) {
                        if (SENSITIVE_QUERY_PARAMS.contains(param.lowercase())) {
                            builder.appendQueryParameter(param, "[REDACTED]")
                        } else {
                            builder.appendQueryParameter(param, uri.getQueryParameter(param))
                        }
                    }
                    builder.build().toString()
                }
            } catch (_: Exception) {
                val regex = Regex("([?&])([a-zA-Z0-9_-]+)=([^&]*)")
                regex.replace(uriString) { matchResult ->
                    val prefix = matchResult.groupValues[1]
                    val key = matchResult.groupValues[2]
                    val value = matchResult.groupValues[3]
                    if (SENSITIVE_QUERY_PARAMS.contains(key.lowercase())) {
                        "$prefix$key=[REDACTED]"
                    } else {
                        "$prefix$key=$value"
                    }
                }
            }
        }
    }
}
