package com.yesanith.tyria_codex

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Date

/**
 * The home screen widget: the next world boss with a countdown that ticks by itself, the two resets
 * and the events after the first.
 *
 * The app writes the schedule once (the events run on a fixed daily schedule in UTC, so a start time
 * is a minute of the day) together with the words in the language of the player. Everything else is
 * worked out here from the clock, so the widget stays right with the app closed.
 */
class TyriaWidgetProvider : HomeWidgetProvider() {

    private data class Start(val at: Long, val name: String, val map: String)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = System.currentTimeMillis()
        val starts = nextStarts(widgetData.getString("schedule", "") ?: "", now, 3)
        val clock = SystemClock.elapsedRealtime()
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val tap = launch?.let {
            PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }
        val format = DateFormat.getTimeFormat(context)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.tyria_widget)
            views.setTextViewText(R.id.label_next, widgetData.getString("label_next", "Next boss"))
            views.setTextViewText(R.id.label_daily, widgetData.getString("label_daily", "Daily reset"))
            views.setTextViewText(R.id.label_weekly, widgetData.getString("label_weekly", "Weekly reset"))

            val first = starts.firstOrNull()
            if (first == null) {
                views.setTextViewText(R.id.next_name, widgetData.getString("label_none", "Open the app"))
                views.setTextViewText(R.id.next_map, "")
                views.setViewVisibility(R.id.next_timer, View.GONE)
            } else {
                views.setTextViewText(R.id.next_name, first.name)
                views.setTextViewText(R.id.next_map, first.map)
                views.setViewVisibility(R.id.next_timer, View.VISIBLE)
                countDown(views, R.id.next_timer, first.at - now, clock)
            }
            countDown(views, R.id.daily_timer, nextDailyReset(now) - now, clock)
            countDown(views, R.id.weekly_timer, nextWeeklyReset(now) - now, clock)

            // the events after the first, a line each, left out when there is no such event
            val after = starts.drop(1)
            val rows = listOf(
                Triple(R.id.later_1, R.id.later_1_time, R.id.later_1_name),
                Triple(R.id.later_2, R.id.later_2_time, R.id.later_2_name),
            )
            rows.forEachIndexed { i, (row, time, name) ->
                val start = after.getOrNull(i)
                if (start == null) {
                    views.setViewVisibility(row, View.GONE)
                } else {
                    views.setViewVisibility(row, View.VISIBLE)
                    views.setTextViewText(time, format.format(Date(start.at)))
                    views.setTextViewText(name, start.name)
                }
            }

            if (tap != null) views.setOnClickPendingIntent(R.id.root, tap)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /** a chronometer that counts down to [remaining] milliseconds from now, drawn by the system itself */
    private fun countDown(views: RemoteViews, viewId: Int, remaining: Long, clock: Long) {
        views.setChronometerCountDown(viewId, true)
        views.setChronometer(viewId, clock + remaining, null, true)
    }

    /** the next [count] starts after [now], from lines of "minute of the day (UTC), event, map" */
    private fun nextStarts(schedule: String, now: Long, count: Int): List<Start> {
        val day = 86_400_000L
        val midnight = now - Math.floorMod(now, day)
        val out = ArrayList<Start>()
        for (line in schedule.split('\n')) {
            val parts = line.split('\t')
            if (parts.size < 3) continue
            val minute = parts[0].toLongOrNull() ?: continue
            var at = midnight + minute * 60_000L
            if (at <= now) at += day
            out.add(Start(at, parts[1], parts[2]))
        }
        out.sortBy { it.at }
        return out.take(count)
    }

    private fun nextDailyReset(now: Long): Long {
        val day = 86_400_000L
        return now - Math.floorMod(now, day) + day
    }

    /** Monday 07:30 UTC. 1 January 1970 was a Thursday, three days after a Monday */
    private fun nextWeeklyReset(now: Long): Long {
        val day = 86_400_000L
        val dayIndex = Math.floorDiv(now, day)
        val monday = dayIndex - Math.floorMod(dayIndex + 3, 7L)
        var at = monday * day + 7 * 3_600_000L + 30 * 60_000L
        if (at <= now) at += 7 * day
        return at
    }
}
