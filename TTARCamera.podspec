#
# Be sure to run `pod lib lint TTARCamera.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'TTARCamera'
  s.version          = '0.1.0'
  s.summary          = 'A short description of TTARCamera.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/wenzhaot/TTARCamera'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'wenzhaot' => 'tanwenzhao1025@gmail.com' }
  s.source           = { :git => 'https://github.com/wenzhaot/TTARCamera.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/Wenzhaot'

  s.ios.deployment_target = '12.0'
  
  s.subspec 'Sticker' do |ss|
      ss.source_files = 'TTARCamera/Classes/Sticker/*.{h,m}'
      ss.public_header_files = 'TTARCamera/Classes/Sticker/TTARStickerParser.h', 'TTARCamera/Classes/Sticker/TTARStickerPackage.h', 'TTARCamera/Classes/Sticker/TTARBackgroundRender.h'
  end
  
  s.subspec 'ZIP' do |ss|
      ss.source_files = 'TTARCamera/Classes/ZIP/*.{h,c}'
  end
  
  s.subspec 'Filter' do |ss|
      ss.source_files = 'TTARCamera/Classes/Filter/*.{h,m,metal}'
  end
  
  s.public_header_files = 'TTARCamera/Classes/*.h'
  s.source_files = 'TTARCamera/Classes/*'
  
  s.dependency 'YYModel'
end
