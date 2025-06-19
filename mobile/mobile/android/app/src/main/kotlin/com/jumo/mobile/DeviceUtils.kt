package com.jumo.mobile

import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.util.Log
import android.view.Display

object DeviceUtils {
    private const val TAG = "DeviceUtils"
    
    /**
     * 현재 디바이스가 폴더블(접히는) 디바이스인지 확인
     * 기능 중심으로 접근하여 특정 모델에 의존하지 않음
     */
    fun hasExternalDisplay(context: Context): Boolean {
        try {
            // 디스플레이 매니저로 여러 디스플레이 확인
            val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
            val displays = displayManager.displays
            
            // 여러 디스플레이가 있으면 폴더블 기기일 가능성 높음
            if (displays.size > 1) {
                Log.d(TAG, "여러 디스플레이 감지됨: ${displays.size}개")
                return true
            }
            
            // 빌드 프로퍼티 확인 (폴더블 특성)
            try {
                val process = Runtime.getRuntime().exec("getprop ro.build.characteristics")
                val characteristics = process.inputStream.bufferedReader().readText().trim()
                if (characteristics.contains("foldable")) {
                    Log.d(TAG, "폴더블 특성 감지됨")
                    return true
                }
            } catch (e: Exception) {
                // 무시
            }
            
            // 삼성 폴더블 API 확인
            val hasFoldableFeature = try {
                context.packageManager.hasSystemFeature("com.samsung.feature.device_category_foldable") ||
                context.packageManager.hasSystemFeature("com.samsung.feature.cover_display")
            } catch (e: Exception) {
                false
            }
            
            if (hasFoldableFeature) {
                Log.d(TAG, "폴더블 기기 시스템 피처 감지됨")
                return true
            }
            
            return false
        } catch (e: Exception) {
            Log.e(TAG, "폴더블 기기 확인 중 오류", e)
            return false
        }
    }
    
    /**
     * 폴더블 디바이스의 현재 상태를 확인
     * @return true: 열린 상태(OPEN), false: 닫힌 상태(CLOSED)
     */
    fun isDeviceOpen(context: Context): Boolean {
        // 폴더블이 아니면 항상 열려있다고 간주
        if (!hasExternalDisplay(context)) return true
        
        // 방법 1: 시스템 프로퍼티 확인
        var foldStateFromProp = false
        try {
            val process = Runtime.getRuntime().exec("getprop sys.samsung.display.folder_state")
            val foldState = process.inputStream.bufferedReader().readText().trim()
            foldStateFromProp = foldState.equals("OPEN", ignoreCase = true)
        } catch (e: Exception) {
            // 무시
        }
        
        // 방법 2: 메인 디스플레이 상태로 추정
        val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val defaultDisplay = displayManager.getDisplay(Display.DEFAULT_DISPLAY)
        val isMainDisplayOn = defaultDisplay.state == Display.STATE_ON
        
        // 여러 방법을 종합해서 판단
        val isOpen = isMainDisplayOn || foldStateFromProp
        
        // 현재 디스플레이 ID 확인
        val currentDisplayId = try {
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager
            wm.defaultDisplay.displayId
        } catch (e: Exception) {
            0
        }
        
        // 커버 디스플레이(ID=1)가 활성화되어 있으면 닫혀있다고 판단
        val isCoverDisplayActive = currentDisplayId == 1
        
        Log.d(TAG, "디바이스 상태: 열림=$isOpen, 현재 디스플레이=$currentDisplayId")
        
        return if (isCoverDisplayActive) false else isOpen
    }
} 