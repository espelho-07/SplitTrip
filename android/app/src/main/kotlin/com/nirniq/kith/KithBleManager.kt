package com.nirniq.kith

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.*
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.util.UUID

class KithBleManager(
    private val context: Context,
    private val channel: MethodChannel
) {
    companion object {
        private const val TAG = "KithBleManager"
        // Dedicated 128-bit Service UUID for Kith Bluetooth Low Energy mesh discovery
        val KITH_SERVICE_UUID: ParcelUuid = ParcelUuid.fromString("3a8d9001-c817-48f9-b88a-36015b3c5801")
        private const val PROTOCOL_VERSION: Byte = 0x02
        private const val DEFAULT_TIMEOUT_MS: Long = 60000L // 60s battery watchdog
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val bluetoothManager: BluetoothManager? by lazy {
        context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    }
    private val bluetoothAdapter: BluetoothAdapter?
        get() = bluetoothManager?.adapter

    private var advertiser: BluetoothLeAdvertiser? = null
    private var scanner: BluetoothLeScanner? = null

    private var isAdvertising = false
    private var isScanning = false

    private var localDeviceIdHash: Long = 0L
    private var currentTripTokenHash: Int = 0

    private val timeoutRunnable = Runnable {
        Log.i(TAG, "Watchdog timeout reached. Stopping active BLE scan and advertise to conserve battery.")
        stopScanning()
        stopAdvertising()
        notifyStateChanged()
    }

    fun isSupported(): Boolean {
        return context.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE) &&
                bluetoothAdapter != null
    }

    fun isEnabled(): Boolean {
        return bluetoothAdapter?.isEnabled == true
    }

    fun hasAdvertisePermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val advGranted = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_ADVERTISE) == PackageManager.PERMISSION_GRANTED
            val connGranted = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
            advGranted && connGranted
        } else {
            val btGranted = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH) == PackageManager.PERMISSION_GRANTED
            val adminGranted = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_ADMIN) == PackageManager.PERMISSION_GRANTED
            btGranted && adminGranted
        }
    }

    fun hasScanPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val scanGranted = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
            val connGranted = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
            scanGranted && connGranted
        } else {
            val btGranted = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH) == PackageManager.PERMISSION_GRANTED
            val locGranted = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                    ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
            btGranted && locGranted
        }
    }

    fun hasPermissions(): Boolean {
        return hasAdvertisePermissions() && hasScanPermissions()
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            super.onStartSuccess(settingsInEffect)
            isAdvertising = true
            Log.i(TAG, "BLE Advertisement successfully started for tripTokenHash=$currentTripTokenHash")
            notifyStateChanged()
        }

        override fun onStartFailure(errorCode: Int) {
            super.onStartFailure(errorCode)
            isAdvertising = false
            Log.w(TAG, "BLE Advertisement failed to start with code: $errorCode")
            notifyStateChanged()
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            super.onScanResult(callbackType, result)
            if (result == null) return

            val scanRecord = result.scanRecord ?: return
            val serviceData = scanRecord.getServiceData(KITH_SERVICE_UUID) ?: return

            if (serviceData.size < 18) {
                // Ignore malformed or foreign packets
                return
            }

            try {
                val buffer = ByteBuffer.wrap(serviceData)
                val version = buffer.get()
                if (version != PROTOCOL_VERSION) return

                val peerTripTokenHash = buffer.int
                val peerDeviceIdHash = buffer.long
                val peerUserIdHash = buffer.int
                val flags = buffer.get().toInt()

                // 1. Strict Self-Beacon Exclusion: Never detect self as a remote peer!
                if (localDeviceIdHash != 0L && peerDeviceIdHash == localDeviceIdHash) {
                    return
                }

                // 2. Trip Authorization Check: Only match packets belonging to target trip
                if (currentTripTokenHash != 0 && peerTripTokenHash != currentTripTokenHash) {
                    return
                }

                val payload = mapOf(
                    "transport" to "ble",
                    "tripTokenHash" to peerTripTokenHash,
                    "deviceIdHash" to peerDeviceIdHash.toString(),
                    "userIdHash" to peerUserIdHash,
                    "rssi" to result.rssi,
                    "flags" to flags,
                    "deviceAddress" to (try { result.device.address } catch (_: SecurityException) { null })
                )

                mainHandler.post {
                    try {
                        channel.invokeMethod("onBlePeerDiscovered", payload)
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to deliver onBlePeerDiscovered to Flutter engine: ${e.message}")
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error decoding BLE scan payload: ${e.message}")
            }
        }

        override fun onScanFailed(errorCode: Int) {
            super.onScanFailed(errorCode)
            isScanning = false
            Log.w(TAG, "BLE Scan failed with error code: $errorCode")
            notifyStateChanged()
        }
    }

    fun startAdvertising(tripTokenHash: Int, deviceIdHash: Long, userIdHash: Int): Boolean {
        if (!isSupported() || !isEnabled() || !hasAdvertisePermissions()) {
            Log.w(TAG, "startAdvertising: Preconditions not met (supported=${isSupported()}, enabled=${isEnabled()}, permissions=${hasAdvertisePermissions()})")
            return false
        }

        try {
            advertiser = bluetoothAdapter?.bluetoothLeAdvertiser
            if (advertiser == null) {
                Log.w(TAG, "BluetoothLeAdvertiser not available on this device hardware.")
                return false
            }

            stopAdvertising()

            this.currentTripTokenHash = tripTokenHash
            this.localDeviceIdHash = deviceIdHash

            // Compact 18-byte service data payload
            val buffer = ByteBuffer.allocate(18)
            buffer.put(PROTOCOL_VERSION)
            buffer.putInt(tripTokenHash)
            buffer.putLong(deviceIdHash)
            buffer.putInt(userIdHash)
            buffer.put(0x01.toByte()) // flags: active peer

            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
                .setConnectable(false)
                .build()

            val data = AdvertiseData.Builder()
                .addServiceUuid(KITH_SERVICE_UUID)
                .addServiceData(KITH_SERVICE_UUID, buffer.array())
                .setIncludeDeviceName(false)
                .setIncludeTxPowerLevel(false)
                .build()

            advertiser?.startAdvertising(settings, data, advertiseCallback)

            // Arm watchdog timer
            mainHandler.removeCallbacks(timeoutRunnable)
            mainHandler.postDelayed(timeoutRunnable, DEFAULT_TIMEOUT_MS)
            return true
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException in startAdvertising: ${e.message}")
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Exception in startAdvertising: ${e.message}")
            return false
        }
    }

    fun stopAdvertising() {
        if (!isAdvertising && advertiser == null) return
        try {
            advertiser?.stopAdvertising(advertiseCallback)
        } catch (e: SecurityException) {
            Log.w(TAG, "SecurityException in stopAdvertising: ${e.message}")
        } catch (e: Exception) {
            Log.w(TAG, "Exception in stopAdvertising: ${e.message}")
        } finally {
            isAdvertising = false
            advertiser = null
            notifyStateChanged()
        }
    }

    fun startScanning(tripTokenHash: Int, deviceIdHash: Long): Boolean {
        if (!isSupported() || !isEnabled() || !hasScanPermissions()) {
            Log.w(TAG, "startScanning: Preconditions not met (supported=${isSupported()}, enabled=${isEnabled()}, permissions=${hasScanPermissions()})")
            return false
        }

        try {
            scanner = bluetoothAdapter?.bluetoothLeScanner
            if (scanner == null) {
                Log.w(TAG, "BluetoothLeScanner not available on this device hardware.")
                return false
            }

            stopScanning()

            this.currentTripTokenHash = tripTokenHash
            this.localDeviceIdHash = deviceIdHash

            val scanFilter = ScanFilter.Builder()
                .setServiceUuid(KITH_SERVICE_UUID)
                .build()

            val scanSettings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .setReportDelay(0)
                .build()

            scanner?.startScan(listOf(scanFilter), scanSettings, scanCallback)
            isScanning = true
            notifyStateChanged()

            // Arm watchdog timer
            mainHandler.removeCallbacks(timeoutRunnable)
            mainHandler.postDelayed(timeoutRunnable, DEFAULT_TIMEOUT_MS)
            return true
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException in startScanning: ${e.message}")
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Exception in startScanning: ${e.message}")
            return false
        }
    }

    fun stopScanning() {
        if (!isScanning && scanner == null) return
        try {
            scanner?.stopScan(scanCallback)
        } catch (e: SecurityException) {
            Log.w(TAG, "SecurityException in stopScanning: ${e.message}")
        } catch (e: Exception) {
            Log.w(TAG, "Exception in stopScanning: ${e.message}")
        } finally {
            isScanning = false
            scanner = null
            notifyStateChanged()
        }
    }

    fun stopAll() {
        mainHandler.removeCallbacks(timeoutRunnable)
        stopScanning()
        stopAdvertising()
    }

    private fun notifyStateChanged() {
        mainHandler.post {
            try {
                channel.invokeMethod(
                    "onBleStateChanged",
                    mapOf(
                        "isSupported" to isSupported(),
                        "isEnabled" to isEnabled(),
                        "hasPermissions" to hasPermissions(),
                        "hasAdvertisePermissions" to hasAdvertisePermissions(),
                        "hasScanPermissions" to hasScanPermissions(),
                        "isAdvertising" to isAdvertising,
                        "isScanning" to isScanning
                    )
                )
            } catch (e: Exception) {
                Log.w(TAG, "Failed to deliver onBleStateChanged to Flutter engine: ${e.message}")
            }
        }
    }
}
