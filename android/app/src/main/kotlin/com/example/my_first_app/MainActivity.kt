package com.example.my_first_app

import android.Manifest
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val SMS_CHANNEL = "com.aura.bank/sms"
    private val PHOTOS_CHANNEL = "com.aura.bank/photos"
    private val SMS_READ_PERMISSION = 1001
    private val PHOTOS_READ_PERMISSION = 1002

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // SMS Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
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
        
        // Photos Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PHOTOS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPhotos" -> {
                    val limit = call.argument<Int>("limit") ?: 50
                    Log.d("PhotosChannel", "getPhotos called with limit: $limit")
                    
                    if (checkPhotosPermission()) {
                        Log.d("PhotosChannel", "Permission granted, fetching photos...")
                        try {
                            val photosList = getPhotos(limit)
                            Log.d("PhotosChannel", "Fetched ${photosList.length()} photos")
                            result.success(photosList.toString())
                        } catch (e: Exception) {
                            Log.e("PhotosChannel", "Error fetching photos: ${e.message}", e)
                            result.error("FETCH_ERROR", "Error fetching photos: ${e.message}", null)
                        }
                    } else {
                        Log.w("PhotosChannel", "Permission denied")
                        requestPhotosPermission()
                        result.error("PERMISSION_DENIED", "Photos permission not granted", null)
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
    
    // Photos permission and methods
    private fun checkPhotosPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_MEDIA_IMAGES
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
        }
    }
    
    private fun requestPhotosPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.READ_MEDIA_IMAGES),
                PHOTOS_READ_PERMISSION
            )
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE),
                PHOTOS_READ_PERMISSION
            )
        }
    }
    
    private fun getPhotos(limit: Int): JSONArray {
        Log.d("PhotosChannel", "getPhotos() started with limit: $limit")
        val photosList = JSONArray()
        
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }
        
        Log.d("PhotosChannel", "Using collection: $collection")
        
        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATE_ADDED,
            MediaStore.Images.Media.SIZE,
            MediaStore.Images.Media.WIDTH,
            MediaStore.Images.Media.HEIGHT,
            MediaStore.Images.Media.MIME_TYPE
        )
        
        val sortOrder = "${MediaStore.Images.Media.DATE_ADDED} DESC LIMIT $limit"
        
        var cursor: Cursor? = null
        try {
            Log.d("PhotosChannel", "Querying content resolver...")
            cursor = contentResolver.query(collection, projection, null, null, sortOrder)
            
            cursor?.let {
                Log.d("PhotosChannel", "Cursor returned ${it.count} results")
                val idIndex = it.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
                val nameIndex = it.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
                val dateIndex = it.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
                val sizeIndex = it.getColumnIndexOrThrow(MediaStore.Images.Media.SIZE)
                val widthIndex = it.getColumnIndexOrThrow(MediaStore.Images.Media.WIDTH)
                val heightIndex = it.getColumnIndexOrThrow(MediaStore.Images.Media.HEIGHT)
                val mimeIndex = it.getColumnIndexOrThrow(MediaStore.Images.Media.MIME_TYPE)
                
                var count = 0
                while (it.moveToNext()) {
                    val id = it.getLong(idIndex)
                    val contentUri = Uri.withAppendedPath(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                        id.toString()
                    )
                    
                    val photo = JSONObject()
                    photo.put("id", id)
                    photo.put("name", it.getString(nameIndex) ?: "Unknown")
                    photo.put("date", it.getLong(dateIndex))
                    photo.put("size", it.getLong(sizeIndex))
                    photo.put("width", it.getInt(widthIndex))
                    photo.put("height", it.getInt(heightIndex))
                    photo.put("mimeType", it.getString(mimeIndex) ?: "image/*")
                    photo.put("uri", contentUri.toString())
                    
                    photosList.put(photo)
                    count++
                }
                Log.d("PhotosChannel", "Processed $count photos")
            } ?: Log.w("PhotosChannel", "Cursor is null")
        } catch (e: Exception) {
            Log.e("PhotosChannel", "Error in getPhotos: ${e.message}", e)
            throw e
        } finally {
            cursor?.close()
        }
        
        Log.d("PhotosChannel", "getPhotos() returning ${photosList.length()} photos")
        return photosList
    }
}
