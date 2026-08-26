package com.nirniq.kith

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

class KithSnapshotWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            KithWidgetHelper.updateSnapshotWidget(context, appWidgetManager, appWidgetId)
        }
    }
}
