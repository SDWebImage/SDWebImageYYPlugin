#
# Be sure to run `pod lib lint SDWebImageYYPlugin.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SDWebImageYYPlugin'
  s.version          = '0.3.0'
  s.summary          = 'A SDWebImage plugin to integrate YYImage & YYCache for image rendering & caching.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/SDWebImage/SDWebImageYYPlugin'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'DreamPiggy' => 'lizhuoli1126@126.com' }
  s.source           = { :git => 'https://github.com/SDWebImage/SDWebImageYYPlugin.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.source_files = 'SDWebImageYYPlugin/Module/SDWebImageYYPlugin.h'
  s.module_map = 'SDWebImageYYPlugin/Module/SDWebImageYYPlugin.modulemap'

  s.dependency 'SDWebImage/Core', '~> 5.4'

  s.subspec 'YYCache' do |ss|
    ss.dependency 'YYCache'
    ss.source_files = 'SDWebImageYYPlugin/Classes/YYCache/**/*', 'SDWebImageYYPlugin/Module/SDWebImageYYPlugin.h'
  end

  s.subspec 'YYImage' do |ss|
    ss.dependency 'YYImage/Core'
    ss.source_files = 'SDWebImageYYPlugin/Classes/YYImage/**/*', 'SDWebImageYYPlugin/Module/SDWebImageYYPlugin.h'
  end
end
