Pod::Spec.new do |spec|
  spec.name         = "FULogKit-dev"
  spec.module_name  = "FULogKit"
  spec.version      = "1.0.0"
  spec.license      = 'MIT'
  spec.summary      = "Source code for FaceUnity RenderKit usability encapsulation"
  spec.description  = "FaceUnity RenderKit usability encapsulation. convenient and easy to user FaceUnity function"
  spec.homepage     = "http://git.faceunity.com/Terminal/iOS/Modules/FULogKit"
  spec.author       = { 'faceunity' => 'jiajunyao@faceunity.com' }
  spec.source       = { "http": "git@192.168.0.118:Terminal/iOS/Modules/FULogKit.git"}
  spec.requires_arc = true
  spec.ios.deployment_target  = '12.0'
  spec.swift_version = '5.0'
  spec.pod_target_xcconfig = {
    'ENABLE_BITCODE' => 'NO',
    'DEFINES_MODULE' => 'NO',
    'SWIFT_INCLUDE_PATHS' => File.join(__dir__, 'FULogKit/SupportFiles')
  }

  spec.subspec 'FULogKit' do |sp|
    sp.source_files = 'FULogKit/**/*.{h,m,swift,modulemap}'
  end

  spec.default_subspecs = 'FULogKit'
  
end

