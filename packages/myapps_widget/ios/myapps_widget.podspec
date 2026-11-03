#
# MyApps-Widget's iOS bridge: stores widget envelopes in the app's App Group
# and reloads WidgetKit timelines. See doc/en-us/architecture.md.
#
Pod::Spec.new do |s|
  s.name             = 'myapps_widget'
  s.version          = '0.2.0'
  s.summary          = 'Home-screen widget envelope bridge for MyApps.'
  s.description      = <<-DESC
Answers the com.yuanzhe.myapps_widget/bridge method channel: writes one
envelope per widget kind into an App Group and reloads that kind's timelines.
                       DESC
  s.homepage         = 'https://github.com/YuanZhe-99/MyApps-Widget'
  s.license          = { :type => 'GPL-3.0' }
  s.author           = { 'yuanzhe' => 'yuanzhe' }
  s.source           = { :path => '.' }
  s.source_files     = 'myapps_widget/Sources/myapps_widget/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  # WidgetKit exists from iOS 14; every use is behind #available.
  s.weak_frameworks = 'WidgetKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
