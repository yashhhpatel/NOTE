package com.noteflow.noteflow

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * Home-screen widget: shows the active-note count and up to a few pinned note
 * titles, synced from Dart via the home_widget plugin (see
 * HomeWidgetService). Tapping anywhere opens the app. No background isolate,
 * no network — purely a read of locally-saved widget data.
 */
class NoteflowWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val activeCount = widgetData.getInt("active_count", 0)
        val pinnedJson = widgetData.getString("pinned_titles", "[]") ?: "[]"
        val pinnedTitles = try {
            val arr = JSONArray(pinnedJson)
            (0 until arr.length()).map { arr.getString(it) }
        } catch (e: Exception) {
            emptyList()
        }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.noteflow_widget).apply {
                setTextViewText(
                    R.id.widget_count,
                    if (activeCount == 0) "No notes yet" else "$activeCount notes"
                )
                setTextViewText(
                    R.id.widget_pinned,
                    if (pinnedTitles.isEmpty()) "" else pinnedTitles.joinToString("\n") { "• $it" }
                )

                val pendingIntent =
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
