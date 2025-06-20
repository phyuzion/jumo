package com.jumo.mobile

import android.app.Application
import android.util.Log

class JumoApp : Application() {

    companion object {
        private var instance: JumoApp? = null
        val context: JumoApp get() = instance!!
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d("JumoApp", "onCreate() in FlutterApplication")
    }
}
