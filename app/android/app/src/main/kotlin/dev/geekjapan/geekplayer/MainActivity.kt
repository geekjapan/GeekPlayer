package dev.geekjapan.geekplayer

import com.ryanheise.audioservice.AudioServiceActivity

// `audio_service` requires the Flutter host Activity to extend
// `AudioServiceActivity` (it provides the cached FlutterEngine the plugin's
// background service reuses). With a plain `FlutterActivity`, `AudioService.init`
// throws "The Activity class declared in your AndroidManifest.xml is wrong..."
// at startup, which the error boundary swallows into a blank white screen.
class MainActivity : AudioServiceActivity()
