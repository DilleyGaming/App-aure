package PAQUETE

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Widget de Auré en la pantalla de inicio: cuatro botones que abren la app y hacen la acción. */
class AureWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val vista = RemoteViews(context.packageName, R.layout.aure_widget)
            vista.setTextViewText(R.id.w_hablar, widgetData.getString("w_hablar", "Hablar"))
            vista.setTextViewText(R.id.w_bienvenida, widgetData.getString("w_bienvenida", "Llego a casa"))
            vista.setTextViewText(R.id.w_cena, widgetData.getString("w_cena", "Modo cena"))
            vista.setTextViewText(R.id.w_noches, widgetData.getString("w_noches", "Buenas noches"))
            vista.setOnClickPendingIntent(R.id.w_hablar, abrir(context, "hablar"))
            vista.setOnClickPendingIntent(R.id.w_bienvenida, abrir(context, "esc.bienvenida"))
            vista.setOnClickPendingIntent(R.id.w_cena, abrir(context, "esc.cena"))
            vista.setOnClickPendingIntent(R.id.w_noches, abrir(context, "esc.noches"))
            appWidgetManager.updateAppWidget(id, vista)
        }
    }

    private fun abrir(context: Context, accion: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("aure://accion?c=$accion"))
}
