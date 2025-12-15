package com.finlog.finlog

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsMessage
import android.util.Log

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("FinLogSms", "SmsReceiver.onReceive called with action: ${intent.action}")
        
        if (intent.action == "android.provider.Telephony.SMS_RECEIVED") {
            val bundle = intent.extras
            try {
                if (bundle != null) {
                    val pdus = bundle.get("pdus") as Array<*>
                    Log.d("FinLogSms", "Processing ${pdus.size} SMS PDUs")
                    
                    for (i in pdus.indices) {
                        val format = bundle.getString("format")
                        val message = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                            SmsMessage.createFromPdu(pdus[i] as ByteArray, format)
                        } else {
                            SmsMessage.createFromPdu(pdus[i] as ByteArray)
                        }

                        val sender = message.displayOriginatingAddress
                        val msgBody = message.displayMessageBody
                        val timestamp = message.timestampMillis

                        Log.d("FinLogSms", "From: $sender, Msg: $msgBody")
                        
                        // Forward to MainActivity via local broadcast
                        val forwardIntent = Intent("com.finlog.finlog.SMS_RECEIVED")
                        forwardIntent.putExtra("sender", sender)
                        forwardIntent.putExtra("body", msgBody)
                        forwardIntent.putExtra("timestamp", timestamp)
                        forwardIntent.setPackage(context.packageName) // Explicit broadcast
                        context.sendBroadcast(forwardIntent)
                        
                        Log.d("FinLogSms", "Broadcast sent to MainActivity")
                    }
                } else {
                    Log.w("FinLogSms", "SMS bundle is null")
                }
            } catch (e: Exception) {
                Log.e("FinLogSms", "Error processing SMS: ${e.message}", e)
            }
        }
    }
}
