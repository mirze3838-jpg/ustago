package com.ustago.app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.ustago.app/location"
    private val permissionRequestCode = 4711
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkLocationStatus" -> {
                    result.success(
                        mapOf(
                            "gpsEnabled" to isLocationServiceEnabled(),
                            "permission" to currentPermissionStatus()
                        )
                    )
                }
                "requestLocationPermission" -> requestLocationPermission(result)
                "openLocationSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.fromParts("package", packageName, null)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getCurrentPosition" -> getCurrentPosition(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun isLocationServiceEnabled(): Boolean {
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lm.isLocationEnabled
        } else {
            try {
                lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                    lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            } catch (e: Exception) {
                false
            }
        }
    }

    private fun hasPermission(): Boolean {
        val fine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun prefs() = getSharedPreferences("ustago_location_prefs", Context.MODE_PRIVATE)

    private fun currentPermissionStatus(): String {
        if (hasPermission()) return "granted"
        val askedBefore = prefs().getBoolean("asked_before", false)
        val rationale = shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_FINE_LOCATION)
        // Əvvəl soruşulub və sistem daha izah göstərmirsə -> həmişəlik rədd edilib
        return if (askedBefore && !rationale) "permanentlyDenied" else "denied"
    }

    private fun requestLocationPermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success("granted")
            return
        }
        if (currentPermissionStatus() == "permanentlyDenied") {
            // İcazəni sonsuz təkrarlamırıq - istifadəçini parametrlərə yönləndirmək lazımdır
            result.success("permanentlyDenied")
            return
        }
        pendingPermissionResult?.success("denied")
        pendingPermissionResult = result
        prefs().edit().putBoolean("asked_before", true).apply()
        requestPermissions(
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
            permissionRequestCode
        )
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return
        val res = pendingPermissionResult ?: return
        pendingPermissionResult = null
        if (grantResults.any { it == PackageManager.PERMISSION_GRANTED }) {
            res.success("granted")
        } else {
            val rationale = shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_FINE_LOCATION)
            res.success(if (rationale) "denied" else "permanentlyDenied")
        }
    }

    @Suppress("MissingPermission")
    private fun getCurrentPosition(result: MethodChannel.Result) {
        if (!hasPermission()) {
            result.error("NO_PERMISSION", "Konum icazəsi verilməyib", null)
            return
        }
        if (!isLocationServiceEnabled()) {
            result.error("GPS_DISABLED", "Konum xidməti bağlıdır", null)
            return
        }
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
            .filter { p -> try { lm.isProviderEnabled(p) } catch (e: Exception) { false } }

        var best: Location? = null
        for (p in providers) {
            try {
                val l = lm.getLastKnownLocation(p)
                if (l != null && (best == null || l.time > best!!.time)) best = l
            } catch (e: Exception) { }
        }
        val fresh = best != null && (System.currentTimeMillis() - best!!.time) < 2 * 60 * 1000

        if (fresh) {
            result.success(mapOf("lat" to best!!.latitude, "lng" to best!!.longitude, "accuracy" to best!!.accuracy.toDouble()))
            return
        }
        if (providers.isEmpty()) {
            if (best != null) {
                result.success(mapOf("lat" to best!!.latitude, "lng" to best!!.longitude, "accuracy" to best!!.accuracy.toDouble()))
            } else {
                result.error("NO_PROVIDER", "Konum təminatçısı tapılmadı", null)
            }
            return
        }

        var replied = false
        val handler = Handler(Looper.getMainLooper())
        val listeners = mutableListOf<LocationListener>()
        val fallback = best

        fun finish(loc: Location?) {
            if (replied) return
            replied = true
            listeners.forEach { try { lm.removeUpdates(it) } catch (e: Exception) { } }
            if (loc != null) {
                result.success(mapOf("lat" to loc.latitude, "lng" to loc.longitude, "accuracy" to loc.accuracy.toDouble()))
            } else {
                result.error("TIMEOUT", "Konum vaxtında alınmadı", null)
            }
        }

        for (p in providers) {
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) { handler.post { finish(location) } }
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {}
                @Deprecated("Deprecated in Java")
                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            }
            listeners.add(listener)
            try {
                lm.requestLocationUpdates(p, 0L, 0f, listener, Looper.getMainLooper())
            } catch (e: Exception) { }
        }
        handler.postDelayed({ finish(fallback) }, 15000)
    }
}
