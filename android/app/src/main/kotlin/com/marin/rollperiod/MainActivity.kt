package com.marin.rollperiod

import io.flutter.embedding.android.FlutterActivity
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ComponentName
import android.view.View
import android.app.PendingIntent
import android.content.Intent




class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.marin.rollperiod/widget").setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    val intent = Intent(this, AlertWidgetProvider::class.java)
                    intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    val ids = AppWidgetManager.getInstance(this)
                        .getAppWidgetIds(ComponentName(this, AlertWidgetProvider::class.java))
                    intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    sendBroadcast(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        // New channel for vessel widget
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.marin.rollperiod/vessel_widget").setMethodCallHandler { call, result ->
            when (call.method) {
                "updateVesselWidget" -> {
                    val intent = Intent(this, VesselWidgetProvider::class.java)
                    intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    val ids = AppWidgetManager.getInstance(this)
                        .getAppWidgetIds(ComponentName(this, VesselWidgetProvider::class.java))
                    intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    sendBroadcast(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

}

class AlertWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Force update all widgets
        val manager = AppWidgetManager.getInstance(context)
        val thisWidget = ComponentName(context, AlertWidgetProvider::class.java)
        val allWidgetIds = manager.getAppWidgetIds(thisWidget)
        for (widgetId in allWidgetIds) {
            updateAppWidget(context, manager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == REFRESH_ACTION || intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, AlertWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)

            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val historyJson = prefs.getString("flutter.alertHistoryData", null)
        val views = RemoteViews(context.packageName, R.layout.alert_widget)

        // Toujours afficher les 5 conteneurs
        views.setViewVisibility(R.id.alert1_container, View.VISIBLE)
        views.setViewVisibility(R.id.alert2_container, View.VISIBLE)
        views.setViewVisibility(R.id.alert3_container, View.VISIBLE)
        views.setViewVisibility(R.id.alert4_container, View.VISIBLE)
        views.setViewVisibility(R.id.alert5_container, View.VISIBLE)

        // Initialiser tous les champs avec des valeurs par défaut
        val defaultText = " "
        listOf(
            R.id.alert1_time, R.id.alert1_date, R.id.alert1_roll,
            R.id.alert2_time, R.id.alert2_date, R.id.alert2_roll,
            R.id.alert3_time, R.id.alert3_date, R.id.alert3_roll,
            R.id.alert4_time, R.id.alert4_date, R.id.alert4_roll,
            R.id.alert5_time, R.id.alert5_date, R.id.alert5_roll
        ).forEach { views.setTextViewText(it, defaultText) }

        if (historyJson != null) {
            try {
                val jsonObject = JSONObject(historyJson)
                val alertArray = jsonObject.getJSONArray("alertHistory")

                // Afficher les alertes disponibles (jusqu'à 5)
                val maxAlerts = minOf(5, alertArray.length())

                for (i in 0 until maxAlerts) {
                    val alert = alertArray.getJSONObject(i)
                    val time = alert.getString("time")
                    val date = alert.getString("date")
                    val rollPeriod = alert.getString("rollPeriod")

                    when (i) {
                        0 -> {
                            views.setTextViewText(R.id.alert1_time, time)
                            views.setTextViewText(R.id.alert1_date, date)
                            views.setTextViewText(R.id.alert1_roll, rollPeriod)
                        }
                        1 -> {
                            views.setTextViewText(R.id.alert2_time, time)
                            views.setTextViewText(R.id.alert2_date, date)
                            views.setTextViewText(R.id.alert2_roll, rollPeriod)
                        }
                        2 -> {
                            views.setTextViewText(R.id.alert3_time, time)
                            views.setTextViewText(R.id.alert3_date, date)
                            views.setTextViewText(R.id.alert3_roll, rollPeriod)
                        }
                        3 -> {
                            views.setTextViewText(R.id.alert4_time, time)
                            views.setTextViewText(R.id.alert4_date, date)
                            views.setTextViewText(R.id.alert4_roll, rollPeriod)
                        }
                        4 -> {
                            views.setTextViewText(R.id.alert5_time, time)
                            views.setTextViewText(R.id.alert5_date, date)
                            views.setTextViewText(R.id.alert5_roll, rollPeriod)
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
                views.setTextViewText(R.id.widget_title, "Error loading data")
            }
        }
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    companion object {
        const val REFRESH_ACTION = "com.marin.rollperiod.REFRESH_ACTION"
    }
}