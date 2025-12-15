package com.finlog.finlog

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.net.Uri
import android.database.Cursor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.finlog.finlog/sms"
    private var methodChannel: MethodChannel? = null

    private val localReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.finlog.finlog.SMS_RECEIVED") {
                val sender = intent.getStringExtra("sender")
                val body = intent.getStringExtra("body")
                val timestamp = intent.getLongExtra("timestamp", 0)
                
                android.util.Log.d("FinLog", "MainActivity received broadcast: $sender")

                runOnUiThread {
                    methodChannel?.invokeMethod("onSmsReceived", mapOf(
                        "sender" to sender,
                        "body" to body,
                        "timestamp" to timestamp
                    ))
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Set up method call handler for Flutter -> Native calls
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "scanAllSms" -> {
                    try {
                        val messages = scanAllSms()
                        result.success(messages)
                    } catch (e: Exception) {
                        result.error("SCAN_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        val filter = IntentFilter("com.finlog.finlog.SMS_RECEIVED")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(localReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(localReceiver, filter)
        }
    }

    private fun scanAllSms(): List<Map<String, Any>> {
        val smsList = mutableListOf<Map<String, Any>>()
        val uri = Uri.parse("content://sms/inbox")
        
        try {
            val cursor: Cursor? = contentResolver.query(
                uri,
                arrayOf("address", "body", "date"),
                null,
                null,
                "date DESC"
            )

            cursor?.use {
                while (it.moveToNext()) {
                    try {
                        val sender = it.getString(0) ?: ""
                        val body = it.getString(1) ?: ""
                        val timestamp = it.getLong(2)

                        smsList.add(mapOf(
                            "sender" to sender,
                            "body" to body,
                            "timestamp" to timestamp
                        ))
                    } catch (e: Exception) {
                        // Skip this message if there's an error
                        continue
                    }
                }
            }
        } catch (e: Exception) {
            // Return empty list if permission denied or other error
            android.util.Log.e("FinLog", "Error scanning SMS: ${e.message}")
        }

        return smsList
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(localReceiver)
        } catch (e: Exception) {
            // Receiver might not be registered or already unregistered
        }
    }
}
