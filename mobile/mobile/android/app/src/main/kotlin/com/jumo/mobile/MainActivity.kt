package com.jumo.mobile

import android.app.ActivityOptions
import android.app.role.RoleManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.telecom.TelecomManager
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterFragmentActivity() {

    private val TAG = "Jumo Activity"

    private val ACTIVITY_CHANNEL_NAME = "com.jumo.mobile/nativeDefaultDialer"
    private var methodResultForDialer: MethodChannel.Result? = null

    private var flutterAppInitialized = false
    private var pendingIncomingNumber: String? = null
    
    private val REQUEST_CODE_SET_DEFAULT_DIALER = 1001

    // 폴드 상태 체크 핸들러
    private val foldStateCheckHandler = Handler(Looper.getMainLooper())
    private val foldStateCheckRunnable = object : Runnable {
        override fun run() {
            checkDeviceStateAndUpdateDisplay()
            // 주기적으로 체크 (500ms 간격)
            foldStateCheckHandler.postDelayed(this, 500)
        }
    }
    
    // 디바이스 폴드 상태 변경 감지를 위한 리시버
    private val deviceStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                // 디바이스 상태 변경 관련 인텐트들
                "android.intent.action.CONFIGURATION_CHANGED",
                "com.samsung.android.intent.action.DEVICE_STATE_CHANGED",
                Intent.ACTION_SCREEN_ON,
                Intent.ACTION_SCREEN_OFF -> {
                    checkDeviceStateAndUpdateDisplay()
                }
            }
        }
    }

    private val callPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (!granted) {
            Toast.makeText(this, "CALL_PHONE 권한이 필요합니다.", Toast.LENGTH_SHORT).show()
            methodResultForDialer?.success(false)
            methodResultForDialer = null
        } else {
            requestSetDefaultDialer()
        }
    }

    private val roleRequestLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == RESULT_OK) {
            Log.d(TAG, "기본 전화앱 설정 완료")
            // 기본 전화앱으로 설정된 후 통화 상태 초기화
            NativeBridge.resetCallState()
            methodResultForDialer?.success(true)
        } else {
            Log.d(TAG, "기본 전화앱 설정 거부")
            methodResultForDialer?.success(false)
        }
        methodResultForDialer = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 전화가 왔을 때 잠금 화면 위에 표시되도록 설정
        if (intent?.getBooleanExtra("incoming_call", false) == true) {
            Log.d(TAG, "수신 전화 인텐트 감지: 잠금 화면 위에 표시되도록 설정")
            enableLockScreenFlags()
            
            // 폴드 상태 모니터링 시작
            startDeviceStateMonitoring()
            
            // 현재 디스플레이 확인 및 적절한 UI 설정
            val displayManager = getSystemService(Context.DISPLAY_SERVICE) as android.hardware.display.DisplayManager
            val currentDisplay = displayManager.getDisplay(windowManager.defaultDisplay.displayId)
            
            if (currentDisplay.displayId == 1) { // 커버 화면 ID
                Log.d(TAG, "커버 화면에 표시 중: UI 조정")
                setupCoverScreenLayout()
            } else {
                Log.d(TAG, "메인 화면에 표시 중: 기본 UI 사용")
                setupMainScreenLayout()
            }
        }
        
        checkIntentForCall(intent)
    }

    override fun onResume() {
        super.onResume()
        
        // 폴더블 디바이스인 경우에만 상태 모니터링 시작
        if (DeviceUtils.hasExternalDisplay(this)) {
            startDeviceStateMonitoring()
        }
    }
    
    override fun onPause() {
        super.onPause()
        
        // 리시버 등록 해제
        stopDeviceStateMonitoring()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        
        // 새 인텐트 설정
        setIntent(intent)
        
        // 전화가 왔을 때 처리
        if (intent.getBooleanExtra("incoming_call", false)) {
            Log.d(TAG, "onNewIntent: 수신 전화 인텐트 감지")
            enableLockScreenFlags()
            
            // 폴드 상태 모니터링 시작
            startDeviceStateMonitoring()
            
            // 현재 디스플레이 확인 및 적절한 UI 설정
            val displayManager = getSystemService(Context.DISPLAY_SERVICE) as android.hardware.display.DisplayManager
            val currentDisplay = displayManager.getDisplay(windowManager.defaultDisplay.displayId)
            
            if (currentDisplay.displayId == 1) { // 커버 화면 ID
                Log.d(TAG, "커버 화면에 표시 중: UI 조정")
                setupCoverScreenLayout()
            } else {
                Log.d(TAG, "메인 화면에 표시 중: 기본 UI 사용")
                setupMainScreenLayout()
            }
        }
        
        checkIntentForCall(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_SET_DEFAULT_DIALER) {
            if (isDefaultDialer()) {
                Log.d(TAG, "기본 전화앱 설정 완료 (하위 버전)")
                NativeBridge.resetCallState()
                methodResultForDialer?.success(true)
            } else {
                Log.d(TAG, "기본 전화앱 설정 거부 (하위 버전)")
                methodResultForDialer?.success(false)
            }
            methodResultForDialer = null
        }
    }

    private fun checkIntentForCall(intent: Intent?){
        if (intent == null) return

        if (intent.getBooleanExtra("incoming_call", false)) {
            Log.d(TAG, "Incoming call intent received")
            enableLockScreenFlags()
            val number = intent.getStringExtra("incoming_number") ?: ""
            if (!flutterAppInitialized) {
                Log.d(TAG, "Flutter not init => pendingIncomingNumber=$number")
                pendingIncomingNumber = number
            } else {
                Log.d(TAG, "Flutter init => notifyIncomingNumber($number)")
                NativeBridge.notifyIncomingNumber(number)
            }
        } else if (intent.getBooleanExtra("on_call", false)) {
            Log.d(TAG, "On Call intent received")
            val onCallNumber = intent.getStringExtra("on_call_number") ?: ""
            val onCallConnected = intent.getBooleanExtra("on_call_connected", false)
            NativeBridge.notifyOnCall(onCallNumber, onCallConnected) 
        } else if (intent.getBooleanExtra("call_ended", false)) {
            Log.d(TAG, "Call ended intent received")
            val endedNumber = intent.getStringExtra("call_ended_number") ?: ""
            val reason = intent.getStringExtra("call_ended_reason") ?: ""
            NativeBridge.notifyCallEnded(endedNumber, reason) 
        }
        handleDialIntent(intent)
    }

    private fun enableLockScreenFlags() {
        // 잠금 화면 위에 표시 및 화면 켜기
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    private fun requestSetDefaultDialer() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            if (roleManager.isRoleAvailable(RoleManager.ROLE_DIALER)) {
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER)
                roleRequestLauncher.launch(intent)
            } else {
                methodResultForDialer?.success(true)
                methodResultForDialer = null
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Android 8.0 (Oreo) 이상, Android 10 미만
            val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            val changeDialerIntent = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER)
                .putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, packageName)
            
            try {
                startActivityForResult(changeDialerIntent, REQUEST_CODE_SET_DEFAULT_DIALER)
            } catch (e: Exception) {
                Log.e(TAG, "기본 전화앱 설정 인텐트 실행 실패", e)
                methodResultForDialer?.success(false)
                methodResultForDialer = null
            }
        } else {
            // Android 8.0 미만
            methodResultForDialer?.success(false)
            methodResultForDialer = null
        }
    }

    private fun isDefaultDialer(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            return roleManager.isRoleHeld(RoleManager.ROLE_DIALER)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Android 8.0 (Oreo) 이상, Android 10 미만
            val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            return packageName == telecomManager.defaultDialerPackage
        }
        return false
    }

    private fun handleDialIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        if (action == Intent.ACTION_DIAL || action == Intent.ACTION_VIEW) {
            val data: Uri? = intent.data
            if (data != null && data.scheme == "tel") {
                val phoneNumber = data.schemeSpecificPart
                Log.d(TAG, "Dial intent with number: $phoneNumber")
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        NativeBridge.setupChannel(flutterEngine)
        try {
            flutterEngine.plugins.add(SmsPlugin()) 
        } catch (e: Exception) {
            Log.e(TAG, "SmsPlugin 등록 중 오류 발생.", e)
        }
        
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACTIVITY_CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestDefaultDialerManually" -> {
                    methodResultForDialer = result
                    requestSetDefaultDialer()
                    
                }
                "isDefaultDialer" -> {
                    result.success(isDefaultDialer())
                }
                "setAppInitialized" -> {
                    flutterAppInitialized = true
                    pendingIncomingNumber?.let { number ->
                        Log.d(TAG, "Flushing pending incoming call to Flutter: $number")
                        NativeBridge.notifyIncomingNumber(number)
                        pendingIncomingNumber = null
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // 디바이스 상태 모니터링 시작
    private fun startDeviceStateMonitoring() {
        // 폴드 상태 체크 타이머 시작
        startFoldStateMonitoring()
        
        // 인텐트 필터 등록
        val filter = IntentFilter().apply {
            addAction("android.intent.action.CONFIGURATION_CHANGED")
            addAction("com.samsung.android.intent.action.DEVICE_STATE_CHANGED")
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        
        try {
            // Android 12 이상에서는 리시버 등록 시 RECEIVER_NOT_EXPORTED 플래그 필요
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                registerReceiver(deviceStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(deviceStateReceiver, filter)
            }
            Log.d(TAG, "디바이스 상태 리시버 등록 성공")
        } catch (e: Exception) {
            Log.e(TAG, "디바이스 상태 리시버 등록 실패", e)
        }
    }
    
    // 디바이스 상태 모니터링 중지
    private fun stopDeviceStateMonitoring() {
        // 폴드 상태 체크 타이머 중지
        stopFoldStateMonitoring()
        
        // 리시버 등록 해제
        try {
            unregisterReceiver(deviceStateReceiver)
            Log.d(TAG, "디바이스 상태 모니터링 중지")
        } catch (e: IllegalArgumentException) {
            // 리시버가 등록되지 않은 경우 무시
        }
    }
    
    // 디바이스 상태 확인 및 디스플레이 업데이트
    private fun checkDeviceStateAndUpdateDisplay() {
        val isDeviceOpen = DeviceUtils.isDeviceOpen(this)
        val currentDisplayId = windowManager.defaultDisplay.displayId
        
        // 디바이스가 열렸는데 커버 화면에 표시 중이면 메인 화면으로 이동
        if (isDeviceOpen && currentDisplayId == 1) {
            Log.d(TAG, "디바이스가 열렸음: 메인 화면으로 이동")
            moveToMainDisplay()
        } 
        // 디바이스가 닫혔는데 메인 화면에 표시 중이고 전화 통화 중이면 커버 화면으로 이동
        else if (!isDeviceOpen && currentDisplayId == 0 && intent?.getBooleanExtra("incoming_call", false) == true) {
            Log.d(TAG, "디바이스가 닫혔음: 커버 화면으로 이동")
            moveToCoverDisplay()
        }
    }
    
    // 메인 디스플레이로 이동
    private fun moveToMainDisplay() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                // 기존 인텐트 데이터 유지
                if (getIntent().extras != null) {
                    putExtras(getIntent().extras!!)
                }
                
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            }
            
            val options = ActivityOptions.makeBasic().apply {
                launchDisplayId = 0 // 메인 디스플레이 ID
            }
            
            startActivity(intent, options.toBundle())
        } catch (e: Exception) {
            Log.e(TAG, "메인 디스플레이로 이동 실패", e)
        }
    }
    
    // 커버 디스플레이로 이동
    private fun moveToCoverDisplay() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                // 기존 인텐트 데이터 유지
                if (getIntent().extras != null) {
                    putExtras(getIntent().extras!!)
                }
                
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            }
            
            val options = ActivityOptions.makeBasic().apply {
                launchDisplayId = 1 // 커버 디스플레이 ID
            }
            
            startActivity(intent, options.toBundle())
        } catch (e: Exception) {
            Log.e(TAG, "커버 디스플레이로 이동 실패", e)
        }
    }
    
    // 커버 화면용 레이아웃 설정
    private fun setupCoverScreenLayout() {
        try {
            // 상태바 숨기기
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_FULLSCREEN
            
            // 화면 밝기 최대로 설정
            val layoutParams = window.attributes
            layoutParams.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_FULL
            window.attributes = layoutParams
            
            // 항상 화면 켜짐 설정
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            
            // 잠금 화면 위에 표시
            enableLockScreenFlags()
            
            // Flutter 엔진에 커버 화면 모드 알림
            if (flutterEngine != null) {
                MethodChannel(
                    flutterEngine!!.dartExecutor.binaryMessenger,
                    "com.jumo.mobile/displayMode"
                ).invokeMethod("setDisplayMode", "cover")
            }
        } catch (e: Exception) {
            Log.e(TAG, "커버 화면 레이아웃 설정 오류", e)
        }
    }
    
    // 메인 화면용 레이아웃 설정
    private fun setupMainScreenLayout() {
        try {
            // 일반 모드로 UI 복원
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
            
            // 화면 밝기 자동으로 설정
            val layoutParams = window.attributes
            layoutParams.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            window.attributes = layoutParams
            
            // Flutter 엔진에 메인 화면 모드 알림
            if (flutterEngine != null) {
                MethodChannel(
                    flutterEngine!!.dartExecutor.binaryMessenger,
                    "com.jumo.mobile/displayMode"
                ).invokeMethod("setDisplayMode", "main")
            }
        } catch (e: Exception) {
            Log.e(TAG, "메인 화면 레이아웃 설정 오류", e)
        }
    }

    // 폴드 상태 모니터링 시작
    private fun startFoldStateMonitoring() {
        foldStateCheckHandler.removeCallbacks(foldStateCheckRunnable)
        foldStateCheckHandler.post(foldStateCheckRunnable)
        Log.d(TAG, "폴드 상태 모니터링 시작")
    }
    
    // 폴드 상태 모니터링 중지
    private fun stopFoldStateMonitoring() {
        foldStateCheckHandler.removeCallbacks(foldStateCheckRunnable)
        Log.d(TAG, "폴드 상태 모니터링 중지")
    }
}
