package com.example.marin

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import org.json.JSONObject
import android.content.Intent
import android.content.ComponentName


class VesselWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == REFRESH_ACTION || intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, VesselWidgetProvider::class.java)
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
        val vesselDataJson = prefs.getString("flutter.vesselData", null)
        val views = RemoteViews(context.packageName, R.layout.vessel_widget)

        if (vesselDataJson != null) {
            try {
                val jsonObject = JSONObject(vesselDataJson)
                val vesselProfile = jsonObject.getJSONObject("vesselProfile")
                val loadingCondition = jsonObject.getJSONObject("loadingCondition")

                // Update vessel info
                views.setTextViewText(R.id.vessel_name, vesselProfile.getString("name"))
                views.setTextViewText(R.id.vessel_length, "Length: ${vesselProfile.getDouble("length").toString()} m")
                views.setTextViewText(R.id.vessel_beam, "Beam: ${vesselProfile.getDouble("beam").toString()} m")
                views.setTextViewText(R.id.vessel_depth, "Depth: ${vesselProfile.getDouble("depth").toString()} m")

                // Update loading condition
                views.setTextViewText(R.id.condition_name, loadingCondition.getString("name"))
                views.setTextViewText(R.id.condition_gm, "GM: ${loadingCondition.getDouble("gm").toString()} m")
                views.setTextViewText(R.id.condition_vcg, "VCG: ${loadingCondition.getDouble("vcg").toString()} m")

            } catch (e: Exception) {
                e.printStackTrace()
                views.setTextViewText(R.id.widget_title, "Error loading data")
            }
        } else {
            views.setTextViewText(R.id.widget_title, "No vessel data")
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    companion object {
        const val REFRESH_ACTION = "com.example.marin.REFRESH_VESSEL_WIDGET"
    }
}