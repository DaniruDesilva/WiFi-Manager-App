package com.example.wifi_qr_generator

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class WifiWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val ssid = widgetData.getString("wifi_ssid", null)
                val imagePath = widgetData.getString("wifi_qr_image_path", null)

                if (ssid != null && imagePath != null) {
                    setTextViewText(R.id.widget_title, "Wi-Fi Network")
                    setTextViewText(R.id.widget_ssid, ssid)
                    
                    val imgFile = File(imagePath)
                    if (imgFile.exists()) {
                        val bitmap = BitmapFactory.decodeFile(imgFile.absolutePath)
                        setImageViewBitmap(R.id.widget_qr_image, bitmap)
                        setViewVisibility(R.id.widget_qr_image, View.VISIBLE)
                    } else {
                        setViewVisibility(R.id.widget_qr_image, View.GONE)
                    }
                } else {
                    setTextViewText(R.id.widget_title, "No Wi-Fi Pinned")
                    setTextViewText(R.id.widget_ssid, "Pin a network from the app")
                    setViewVisibility(R.id.widget_qr_image, View.GONE)
                }

                // Add tap action to launch the app
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context, 
                    appWidgetId, 
                    intent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
