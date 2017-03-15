#
# Be sure to run `pod lib lint HawkularAPMTracer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'HawkularAPMTracer'
  s.version          = '0.2.6'
  s.summary          = 'Opentracing compatible tracer with a Hawkular APM recorder'


  s.description      = <<-DESC
Allows any opentracing compatible frameworks to record traces to Hawkular APM.
See http://www.hawkular.org/hawkular-apm/ for more info.
                       DESC

  s.homepage         = 'https://github.com/pat2man/HawkularAPMTracer'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'pat2man' => 'pat2man@gmail.com' }
  s.source           = { :git => 'https://github.com/pat2man/HawkularAPMTracer.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/pat2man'

  s.ios.deployment_target = '8.0'

  s.source_files = 'HawkularAPMTracer/Classes/**/*'
  
  s.public_header_files = 'HawkularAPMTracer/Classes/**/*.h'
  s.frameworks = 'Foundation'
  s.dependency 'opentracing'
end
