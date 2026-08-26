package com.nirniq.kith

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale

object KithWidgetHelper {

    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_SNAPSHOT = "flutter.kith_widget_snapshot"

    fun getSnapshot(context: Context): JSONObject? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val jsonStr = prefs.getString(KEY_SNAPSHOT, null) ?: return null
        return try {
            JSONObject(jsonStr)
        } catch (e: Exception) {
            null
        }
    }

    fun formatCurrency(amountInPaise: Long, isPrivacyMode: Boolean): String {
        if (isPrivacyMode) return "₹••••"
        val rupees = amountInPaise / 100.0
        val isNegative = rupees < 0
        val absRupees = Math.abs(rupees)
        val format = NumberFormat.getNumberInstance(Locale("en", "IN"))
        format.minimumFractionDigits = 0
        format.maximumFractionDigits = 2
        val formatted = format.format(absRupees)
        return if (isNegative) "-₹$formatted" else "₹$formatted"
    }

    fun createDeepLinkPendingIntent(context: Context, deepLinkUri: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse(deepLinkUri)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun updateAllWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)

        // 1. Snapshot Widget
        val snapshotIds = appWidgetManager.getAppWidgetIds(ComponentName(context, KithSnapshotWidgetProvider::class.java))
        for (id in snapshotIds) {
            updateSnapshotWidget(context, appWidgetManager, id)
        }

        // 2. Quick Add Widget
        val quickAddIds = appWidgetManager.getAppWidgetIds(ComponentName(context, QuickAddWidgetProvider::class.java))
        for (id in quickAddIds) {
            updateQuickAddWidget(context, appWidgetManager, id)
        }

        // 3. Budget Widget
        val budgetIds = appWidgetManager.getAppWidgetIds(ComponentName(context, BudgetWidgetProvider::class.java))
        for (id in budgetIds) {
            updateBudgetWidget(context, appWidgetManager, id)
        }

        // 4. Debts Widget
        val debtsIds = appWidgetManager.getAppWidgetIds(ComponentName(context, DebtsWidgetProvider::class.java))
        for (id in debtsIds) {
            updateDebtsWidget(context, appWidgetManager, id)
        }

        // 5. Trip Widget
        val tripIds = appWidgetManager.getAppWidgetIds(ComponentName(context, TripWidgetProvider::class.java))
        for (id in tripIds) {
            updateTripWidget(context, appWidgetManager, id)
        }

        // 6. Smart Kith Widget
        val smartIds = appWidgetManager.getAppWidgetIds(ComponentName(context, SmartKithWidgetProvider::class.java))
        for (id in smartIds) {
            updateSmartKithWidget(context, appWidgetManager, id)
        }
    }

    fun updateSnapshotWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_kith_snapshot)
        val data = getSnapshot(context)
        val isSignedOut = data?.optBoolean("isSignedOut", false) ?: false

        if (data == null || isSignedOut) {
            views.setViewVisibility(R.id.layout_snapshot_content, View.GONE)
            views.setViewVisibility(R.id.layout_snapshot_signed_out, View.VISIBLE)
            views.setOnClickPendingIntent(
                R.id.btn_snapshot_signin,
                createDeepLinkPendingIntent(context, "kith://auth", 101)
            )
            views.setOnClickPendingIntent(
                R.id.widget_snapshot_root,
                createDeepLinkPendingIntent(context, "kith://home", 100)
            )
        } else {
            views.setViewVisibility(R.id.layout_snapshot_content, View.VISIBLE)
            views.setViewVisibility(R.id.layout_snapshot_signed_out, View.GONE)

            val isPrivacy = data.optBoolean("isPrivacyMode", false)
            val spentPaise = data.optLong("spentPaise", 0L)
            val budgetPaise = data.optLong("budgetPaise", 0L)
            val remainingPaise = data.optLong("remainingPaise", 0L)
            val comparisonText = data.optString("comparisonText", "Spent this month")

            views.setTextViewText(R.id.txt_snapshot_amount, formatCurrency(spentPaise, isPrivacy))
            views.setTextViewText(R.id.txt_snapshot_subtitle, comparisonText)

            if (budgetPaise > 0) {
                val percent = Math.min(100, Math.max(0, ((spentPaise.toDouble() / budgetPaise) * 100).toInt()))
                views.setProgressBar(R.id.progress_snapshot_budget, 100, percent, false)
                views.setTextViewText(R.id.txt_snapshot_budget_info, "Budget: ${formatCurrency(budgetPaise, isPrivacy)}")
                val remainingStr = if (remainingPaise >= 0) {
                    "${formatCurrency(remainingPaise, isPrivacy)} left"
                } else {
                    "${formatCurrency(Math.abs(remainingPaise), isPrivacy)} over"
                }
                views.setTextViewText(R.id.txt_snapshot_remaining, remainingStr)
                views.setViewVisibility(R.id.progress_snapshot_budget, View.VISIBLE)
                views.setViewVisibility(R.id.txt_snapshot_budget_info, View.VISIBLE)
                views.setViewVisibility(R.id.txt_snapshot_remaining, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.progress_snapshot_budget, View.GONE)
                views.setTextViewText(R.id.txt_snapshot_budget_info, "No monthly budget set")
                views.setTextViewText(R.id.txt_snapshot_remaining, "Set budget")
            }

            views.setOnClickPendingIntent(
                R.id.widget_snapshot_root,
                createDeepLinkPendingIntent(context, "kith://home", 102)
            )
            views.setOnClickPendingIntent(
                R.id.btn_snapshot_quick_add_icon,
                createDeepLinkPendingIntent(context, "kith://expense/add", 103)
            )
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    fun updateQuickAddWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_quick_add)

        views.setOnClickPendingIntent(
            R.id.btn_quick_add_main,
            createDeepLinkPendingIntent(context, "kith://expense/add", 201)
        )
        views.setOnClickPendingIntent(
            R.id.btn_quick_add_voice,
            createDeepLinkPendingIntent(context, "kith://expense/voice", 202)
        )
        views.setOnClickPendingIntent(
            R.id.btn_quick_add_receipt,
            createDeepLinkPendingIntent(context, "kith://expense/receipt", 203)
        )
        views.setOnClickPendingIntent(
            R.id.widget_quick_add_root,
            createDeepLinkPendingIntent(context, "kith://expense/add", 200)
        )

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    fun updateBudgetWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_budget)
        val data = getSnapshot(context)
        val isPrivacy = data?.optBoolean("isPrivacyMode", false) ?: false
        val spentPaise = data?.optLong("spentPaise", 0L) ?: 0L
        val budgetPaise = data?.optLong("budgetPaise", 0L) ?: 0L
        val remainingPaise = data?.optLong("remainingPaise", 0L) ?: 0L
        val monthName = data?.optString("monthName", "MONTH") ?: "MONTH"
        val dailyRunwayPaise = data?.optLong("dailyRunwayPaise", 0L) ?: 0L

        views.setTextViewText(R.id.txt_budget_month, "$monthName BUDGET".uppercase())

        if (budgetPaise > 0) {
            val percent = Math.min(100, Math.max(0, ((spentPaise.toDouble() / budgetPaise) * 100).toInt()))
            views.setTextViewText(R.id.txt_budget_percent, "$percent%")
            views.setTextViewText(
                R.id.txt_budget_spent_total,
                "${formatCurrency(spentPaise, isPrivacy)} / ${formatCurrency(budgetPaise, isPrivacy)}"
            )
            views.setProgressBar(R.id.progress_budget_bar, 100, percent, false)

            val remainingStr = if (remainingPaise >= 0) {
                "${formatCurrency(remainingPaise, isPrivacy)} left"
            } else {
                "${formatCurrency(Math.abs(remainingPaise), isPrivacy)} over"
            }
            views.setTextViewText(R.id.txt_budget_remaining, remainingStr)

            val runwayStr = if (dailyRunwayPaise > 0) {
                "${formatCurrency(dailyRunwayPaise, isPrivacy)}/day"
            } else {
                "Runway 0/day"
            }
            views.setTextViewText(R.id.txt_budget_daily_runway, runwayStr)
        } else {
            views.setTextViewText(R.id.txt_budget_percent, "0%")
            views.setTextViewText(R.id.txt_budget_spent_total, "${formatCurrency(spentPaise, isPrivacy)} spent")
            views.setProgressBar(R.id.progress_budget_bar, 100, 0, false)
            views.setTextViewText(R.id.txt_budget_remaining, "No budget set")
            views.setTextViewText(R.id.txt_budget_daily_runway, "Tap to set")
        }

        views.setOnClickPendingIntent(
            R.id.widget_budget_root,
            createDeepLinkPendingIntent(context, "kith://budget", 301)
        )

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    fun updateDebtsWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_debts)
        val data = getSnapshot(context)
        val isPrivacy = data?.optBoolean("isPrivacyMode", false) ?: false
        val owedTotalPaise = data?.optLong("moneyOwedTotalPaise", 0L) ?: 0L
        val youOweTotalPaise = data?.optLong("moneyYouOweTotalPaise", 0L) ?: 0L
        val topDebtsArray = data?.optJSONArray("topDebts")

        if (owedTotalPaise > 0 && topDebtsArray != null && topDebtsArray.length() > 0) {
            views.setTextViewText(R.id.txt_debts_header, "YOU'RE OWED")
            views.setTextViewText(R.id.txt_debts_total, formatCurrency(owedTotalPaise, isPrivacy))
            views.setViewVisibility(R.id.layout_debts_list, View.VISIBLE)
            views.setViewVisibility(R.id.layout_debts_all_clear, View.GONE)

            val item1 = topDebtsArray.optJSONObject(0)
            if (item1 != null) {
                views.setViewVisibility(R.id.layout_debts_item1, View.VISIBLE)
                views.setTextViewText(R.id.txt_debts_item1_name, item1.optString("name", "Friend"))
                views.setTextViewText(R.id.txt_debts_item1_amount, formatCurrency(item1.optLong("amountPaise", 0L), isPrivacy))
            } else {
                views.setViewVisibility(R.id.layout_debts_item1, View.GONE)
            }

            val item2 = topDebtsArray.optJSONObject(1)
            if (item2 != null) {
                views.setViewVisibility(R.id.layout_debts_item2, View.VISIBLE)
                views.setTextViewText(R.id.txt_debts_item2_name, item2.optString("name", "Friend"))
                views.setTextViewText(R.id.txt_debts_item2_amount, formatCurrency(item2.optLong("amountPaise", 0L), isPrivacy))
            } else {
                views.setViewVisibility(R.id.layout_debts_item2, View.GONE)
            }
        } else if (youOweTotalPaise > 0) {
            views.setTextViewText(R.id.txt_debts_header, "YOU OWE")
            views.setTextViewText(R.id.txt_debts_total, formatCurrency(youOweTotalPaise, isPrivacy))
            views.setViewVisibility(R.id.layout_debts_list, View.VISIBLE)
            views.setViewVisibility(R.id.layout_debts_all_clear, View.GONE)

            val youOweArray = data?.optJSONArray("topYouOwe")
            val item1 = youOweArray?.optJSONObject(0)
            if (item1 != null) {
                views.setViewVisibility(R.id.layout_debts_item1, View.VISIBLE)
                views.setTextViewText(R.id.txt_debts_item1_name, item1.optString("name", "Friend"))
                views.setTextViewText(R.id.txt_debts_item1_amount, formatCurrency(item1.optLong("amountPaise", 0L), isPrivacy))
            } else {
                views.setViewVisibility(R.id.layout_debts_item1, View.GONE)
            }
            views.setViewVisibility(R.id.layout_debts_item2, View.GONE)
        } else {
            views.setTextViewText(R.id.txt_debts_header, "DEBTS & CREDITS")
            views.setTextViewText(R.id.txt_debts_total, "₹0")
            views.setViewVisibility(R.id.layout_debts_list, View.GONE)
            views.setViewVisibility(R.id.layout_debts_all_clear, View.VISIBLE)
        }

        views.setOnClickPendingIntent(
            R.id.widget_debts_root,
            createDeepLinkPendingIntent(context, "kith://personal/debts", 401)
        )

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    fun updateTripWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_trip)
        val data = getSnapshot(context)
        val isPrivacy = data?.optBoolean("isPrivacyMode", false) ?: false
        val activeTripId = data?.optString("activeTripId", "") ?: ""
        val activeTripTitle = data?.optString("activeTripTitle", "") ?: ""
        val activeTripEmoji = data?.optString("activeTripEmoji", "✈️") ?: "✈️"
        val activeTripSpent = data?.optLong("activeTripSpentPaise", 0L) ?: 0L
        val activeTripBalance = data?.optLong("activeTripUserBalancePaise", 0L) ?: 0L
        val activeTripMembers = data?.optInt("activeTripMemberCount", 0) ?: 0

        if (activeTripId.isNotEmpty() && activeTripTitle.isNotEmpty()) {
            views.setViewVisibility(R.id.layout_trip_content, View.VISIBLE)
            views.setViewVisibility(R.id.layout_trip_empty, View.GONE)

            views.setTextViewText(R.id.txt_trip_title, "$activeTripEmoji ${activeTripTitle.uppercase()}")
            views.setTextViewText(R.id.txt_trip_members, "$activeTripMembers members")
            views.setTextViewText(R.id.txt_trip_spent, "${formatCurrency(activeTripSpent, isPrivacy)} spent total")

            val balancePrefix = if (activeTripBalance > 0) "+" else ""
            views.setTextViewText(
                R.id.txt_trip_balance_amount,
                "$balancePrefix${formatCurrency(activeTripBalance, isPrivacy)}"
            )

            views.setOnClickPendingIntent(
                R.id.widget_trip_root,
                createDeepLinkPendingIntent(context, "kith://trip/$activeTripId", 501)
            )
        } else {
            views.setViewVisibility(R.id.layout_trip_content, View.GONE)
            views.setViewVisibility(R.id.layout_trip_empty, View.VISIBLE)
            views.setOnClickPendingIntent(
                R.id.btn_trip_create,
                createDeepLinkPendingIntent(context, "kith://create-trip", 502)
            )
            views.setOnClickPendingIntent(
                R.id.widget_trip_root,
                createDeepLinkPendingIntent(context, "kith://trips", 500)
            )
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    fun updateSmartKithWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_smart_kith)
        val data = getSnapshot(context)
        val headline = data?.optString("smartHeadline", "Everything is up to date ✓") ?: "Everything is up to date ✓"
        val subtext = data?.optString("smartSubtext", "All expenses and debts are settled") ?: "All expenses and debts are settled"
        val actionLabel = data?.optString("smartActionLabel", "Open Kith") ?: "Open Kith"
        val actionLink = data?.optString("smartActionDeepLink", "kith://home") ?: "kith://home"

        views.setTextViewText(R.id.txt_smart_headline, headline)
        views.setTextViewText(R.id.txt_smart_subtext, subtext)
        views.setTextViewText(R.id.btn_smart_action, actionLabel)

        views.setOnClickPendingIntent(
            R.id.btn_smart_action,
            createDeepLinkPendingIntent(context, actionLink, 601)
        )
        views.setOnClickPendingIntent(
            R.id.widget_smart_kith_root,
            createDeepLinkPendingIntent(context, actionLink, 600)
        )

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
