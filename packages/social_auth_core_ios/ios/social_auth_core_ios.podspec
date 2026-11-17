#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint social_auth_core_ios.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'social_auth_core_ios'
  s.version          = '0.1.0'
  s.summary          = 'iOS implementation of social_auth_core.'
  s.description      = <<-DESC
Runs the sign-in of social_auth_core with ASWebAuthenticationSession.
                       DESC
  s.homepage         = 'https://github.com/franciscodlx/flutter_social_login'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Francisco' => 'https://github.com/franciscodlx' }
  s.source           = { :path => '.' }
  s.source_files = 'social_auth_core_ios/Sources/social_auth_core_ios/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'social_auth_core_ios_privacy' => ['social_auth_core_ios/Sources/social_auth_core_ios/PrivacyInfo.xcprivacy']}
end
