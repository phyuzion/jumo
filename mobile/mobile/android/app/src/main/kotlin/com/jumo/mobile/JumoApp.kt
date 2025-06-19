package com.jumo.mobile

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.util.Log

class JumoApp : Application() {

    companion object {
        private var instance: JumoApp? = null
        val context: JumoApp get() = instance!!
        
        // 현재 앱이 포그라운드에 있는지 여부를 저장
        private var isAppInForeground = false
        
        // 현재 앱이 포그라운드에 있는지 확인
        fun isAppInForeground() = isAppInForeground
    }
    
    // 활성화된 Activity 카운터
    private var activeActivityCount = 0

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d("JumoApp", "onCreate() in FlutterApplication")
        
        // Activity 라이프사이클 콜백 등록
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}

            override fun onActivityStarted(activity: Activity) {
                if (activeActivityCount == 0) {
                    // 앱이 백그라운드에서 포그라운드로 전환되었음
                    isAppInForeground = true
                    Log.d("JumoApp", "App moved to FOREGROUND")
                }
                activeActivityCount++
            }

            override fun onActivityResumed(activity: Activity) {
                isAppInForeground = true
            }

            override fun onActivityPaused(activity: Activity) {}

            override fun onActivityStopped(activity: Activity) {
                activeActivityCount--
                if (activeActivityCount == 0) {
                    // 앱이 포그라운드에서 백그라운드로 전환되었음
                    isAppInForeground = false
                    Log.d("JumoApp", "App moved to BACKGROUND")
                }
            }

            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}

            override fun onActivityDestroyed(activity: Activity) {}
        })
    }
}
