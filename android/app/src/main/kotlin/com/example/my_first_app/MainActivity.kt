package com.example.my_first_app

import android.Manifest
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aura.bank/sms"
    private val SMS_READ_PERMISSION = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAllSms" -> {
                    if (checkSmsPermission()) {
                        val smsList = readAllSms()
                        result.success(smsList.toString())
                    } else {
                        requestSmsPermission()
                        result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                    }
                }
                "searchSms" -> {
                    val query = call.argument<String>("query") ?: ""
                    if (checkSmsPermission()) {
                        val smsList = searchSms(query)
                        result.success(smsList.toString())
                    } else {
                        requestSmsPermission()
                        result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_SMS),
            SMS_READ_PERMISSION
        )
    }

    private fun readAllSms(): JSONArray {
        val smsList = JSONArray()
        val uri = Uri.parse("content://sms/")
        
        val projection = arrayOf(
            "_id",
            "address",
            "body",
            "date",
            "type",
            "read"
        )
        
        val sortOrder = "date DESC"
        
        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(uri, projection, null, null, sortOrder)
            
            cursor?.let {
                val idIndex = it.getColumnIndexOrThrow("_id")
                val addressIndex = it.getColumnIndexOrThrow("address")
                val bodyIndex = it.getColumnIndexOrThrow("body")
                val dateIndex = it.getColumnIndexOrThrow("date")
                val typeIndex = it.getColumnIndexOrThrow("type")
                val readIndex = it.getColumnIndexOrThrow("read")
                
                while (it.moveToNext()) {
                    val sms = JSONObject()
                    sms.put("id", it.getString(idIndex))
                    sms.put("address", it.getString(addressIndex))
                    sms.put("body", it.getString(bodyIndex))
                    sms.put("date", it.getLong(dateIndex))
                    sms.put("type", when (it.getInt(typeIndex)) {
                        1 -> "inbox"
                        2 -> "sent"
                        3 -> "draft"
                        else -> "other"
                    })
                    sms.put("read", it.getInt(readIndex) == 1)
                    smsList.put(sms)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            cursor?.close()
        }
        
        return smsList
    }

    private fun searchSms(query: String): JSONArray {
        val smsList = JSONArray()
        val uri = Uri.parse("content://sms/")
        
        val projection = arrayOf(
            "_id",
            "address",
            "body",
            "date",
            "type",
            "read"
        )
        
        val selection = "address LIKE ? OR body LIKE ?"
        val selectionArgs = arrayOf("%$query%", "%$query%")
        val sortOrder = "date DESC"
        
        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)
            
            cursor?.let {
                val idIndex = it.getColumnIndexOrThrow("_id")
                val addressIndex = it.getColumnIndexOrThrow("address")
                val bodyIndex = it.getColumnIndexOrThrow("body")
                val dateIndex = it.getColumnIndexOrThrow("date")
                val typeIndex = it.getColumnIndexOrThrow("type")
                val readIndex = it.getColumnIndexOrThrow("read")
                
                while (it.moveToNext()) {
                    val sms = JSONObject()
                    sms.put("id", it.getString(idIndex))
                    sms.put("address", it.getString(addressIndex))
                    sms.put("body", it.getString(bodyIndex))
                    sms.put("date", it.getLong(dateIndex))
                    sms.put("type", when (it.getInt(typeIndex)) {
                        1 -> "inbox"
                        2 -> "sent"
                        3 -> "draft"
                        else -> "other"
                    })
                    sms.put("read", it.getInt(readIndex) == 1)
                    smsList.put(sms)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            cursor?.close()
        }
        
        return smsList
    }
}
