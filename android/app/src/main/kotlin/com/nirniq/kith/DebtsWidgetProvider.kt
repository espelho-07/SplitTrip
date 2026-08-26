package com.nirniq.kith

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

class DebtsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            KithWidgetHelper.updateDebtsWidget(context, appWidgetManager, appWidgetId)
        }
    }
}
