package com.netvault.app

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

                var isDisplayed = false
                if (!ssid.isNullOrEmpty() && !imagePath.isNullOrEmpty()) {
                    val imgFile = File(imagePath)
                    if (imgFile.exists() && imgFile.length() > 0) {
                        try {
                            val options = BitmapFactory.Options().apply {
                                inJustDecodeBounds = true
                                BitmapFactory.decodeFile(imgFile.absolutePath, this)
                                var sample = 1
                                val targetDim = 512
                                while ((outWidth / (sample * 2)) >= targetDim && (outHeight / (sample * 2)) >= targetDim) {
                                    sample *= 2
                                }
                                inSampleSize = sample
                                inJustDecodeBounds = false
                            }
                            val bitmap = BitmapFactory.decodeFile(imgFile.absolutePath, options)
                            if (bitmap != null) {
                                setTextViewText(R.id.widget_title, "Wi-Fi Network")
                                setTextViewText(R.id.widget_ssid, ssid)
                                setImageViewBitmap(R.id.widget_qr_image, bitmap)
                                setViewVisibility(R.id.widget_qr_image, View.VISIBLE)
                                setViewVisibility(R.id.widget_empty_layout, View.GONE)
                                isDisplayed = true
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }

                if (!isDisplayed) {
                    setTextViewText(R.id.widget_title, "NetVault Wi-Fi")
                    setTextViewText(R.id.widget_ssid, "No Wi-Fi Pinned Yet")
                    setViewVisibility(R.id.widget_qr_image, View.GONE)
                    setViewVisibility(R.id.widget_empty_layout, View.VISIBLE)
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
