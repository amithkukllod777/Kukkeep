// KukKeep home-screen widget provider (Google-Keep parity).
//
// Lives in the app's Kotlin package (com.kuklabs.kukkeep — same as MainActivity
// and the generated R class), NOT the applicationId (com.kuklabs.keep). CI copies
// this file into android/app/src/main/kotlin/com/kuklabs/kukkeep/ after
// `flutter create`, and the manifest references it by its fully-qualified name.
//
// Shows up to 3 recent notes (pushed from Dart via home_widget). Tapping the body
// opens the app (kukkeep://open); tapping "＋" opens a new note (kukkeep://new) —
// the Dart side listens via HomeWidget.widgetClicked. No background Dart callback.
package com.kuklabs.kukkeep

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
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
        // onUpdate runs IN THE APP PROCESS (it's a broadcast receiver) and fires
        // whenever the widget is placed, every updatePeriodMillis, on boot and on
        // app-update. If anything here throws — a RemoteViews inflation issue, or a
        // PendingIntent built without a mutability flag on Android 12+ — the whole
        // app process crashes, which Android surfaces as "this app has a bug" and
        // repeats every refresh. Guard everything so a widget failure can NEVER
        // take the app down; a broken widget just renders empty instead.
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.notes_widget).apply {
                    val rows = listOf(
                        R.id.widget_note1 to widgetData.getString("note_1", null),
                        R.id.widget_note2 to widgetData.getString("note_2", null),
                        R.id.widget_note3 to widgetData.getString("note_3", null),
                    )
                    var anyShown = false
                    rows.forEach { (id, text) ->
                        if (text.isNullOrBlank()) {
                            setViewVisibility(id, View.GONE)
                        } else {
                            setViewVisibility(id, View.VISIBLE)
                            setTextViewText(id, "•  $text")
                            anyShown = true
                        }
                    }
                    setViewVisibility(R.id.widget_empty, if (anyShown) View.GONE else View.VISIBLE)

                    // Tap targets are best-effort: if building the launch intent
                    // fails on a given OS version, the widget must still render.
                    try {
                        setOnClickPendingIntent(
                            R.id.widget_root,
                            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("kukkeep://open")),
                        )
                        setOnClickPendingIntent(
                            R.id.widget_add,
                            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("kukkeep://new")),
                        )
                    } catch (_: Throwable) { /* tap intents unavailable — widget still shows */ }
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Throwable) {
                // This widget failed to render — skip it, never crash the app.
            }
        }
    }
}
