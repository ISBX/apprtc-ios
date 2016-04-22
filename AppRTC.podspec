Pod::Spec.new do |s|
  s.name               = "AppRTC"
  s.version            = "1.0.3"
  s.summary            = "iOS video chat based on WebRTC"
  s.homepage           = "https://github.com/ISBX/apprtc-ios"
  s.author             = "ISBX"
  s.license            = { :type => "BSD", :file => "LICENSE" }
  s.platform           = :ios, "7.0"
  s.source             = { :git => 'https://github.com/ISBX/apprtc-ios.git', :tag => '1.0.3' }
  s.source_files       = "Lib/*.{h,m,c}"
  s.requires_arc       = true
  s.frameworks         = "QuartzCore", "OpenGLES", "CoreGraphics", "CoreVideo", "CoreMedia", "CoreAudio", "AVFoundation", "AudioToolbox", "GLKit", "CFNetwork", "Security"
  s.libraries          = "sqlite3", "stdc++.6", "icucore", "c++"
  s.dependency "libjingle_peerconnection"
  s.dependency "SocketRocket"
end