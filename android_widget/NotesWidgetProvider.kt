// KukKeep home-screen widget provider (Google-Keep parity).
//
// Lives in the app's Kotlin package (com.kuklabs.kukkeep — same as MainActivity
// and the generated R class), NOT the applicationId (com.kuklabs.keep). CI copies
// this file into android/app/src/main/kotlin/com/kuklabs/kukkeep/ after
// `flutter create`, and the manifest references it by its fully-qualified name.
//
// Display-only + tap-to-open: reads note_title/note_subtitle pushed from Dart via
// home_widget, and opens the app on tap. No background Dart callback is used.
package com.kuklabs.kukkeep

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class NotesWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.notes_widget).apply {
                setTextViewText(R.id.widget_title, widgetData.getString("note_title", null) ?: "Kuk Keep")
                setTextViewText(
                    R.id.widget_subtitle,
                    widgetData.getString("note_subtitle", null) ?: "Tap to open your notes",
                )
                val pending = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("kukkeep://open"),
                )
                setOnClickPendingIntent(R.id.widget_root, pending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
