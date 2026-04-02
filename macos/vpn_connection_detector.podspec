#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint vpn_connection_detector.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'vpn_connection_detector'
  s.version          = '2.0.3'
  s.summary          = 'A Flutter plugin to detect VPN connection status.'
  s.description      = <<-DESC
A Flutter plugin that detects VPN connection status on macOS using native platform APIs.
                       DESC
  s.homepage         = 'https://github.com/bazl-E/vpn_connection_detector'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'bazl-E' => 'basiltalks85@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
