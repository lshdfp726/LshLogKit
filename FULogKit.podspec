Pod::Spec.new do |spec|
  spec.name         = "FULogKit"
  spec.version      = "1.0.0"
  spec.license      = 'MIT'
  spec.summary      = "Source code for FaceUnity RenderKit usability encapsulation"
  spec.description  = "FaceUnity RenderKit usability encapsulation. convenient and easy to user FaceUnity function"
  spec.homepage     = "http://git.faceunity.com/Terminal/iOS/Modules/FULogKit"
  spec.author       = { 'faceunity' => 'jiajunyao@faceunity.com' }
  spec.source       = { "http": "https://www.faceunity.com/sdk/FULogKit-v1.0.0.zip"}
  spec.source_files = 'FULogKit.framework/**/*.{h,m}'
  spec.ios.vendored_frameworks = 'FULogKit.framework'
  spec.requires_arc = true
  spec.ios.deployment_target = '12.0'
  spec.pod_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }
  spec.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'}
  
end

