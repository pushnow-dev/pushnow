require 'xcodeproj'

project = Xcodeproj::Project.open('JiZhi.xcodeproj')
app = project.targets.find { |target| target.name == 'JiZhi' }
paths = %w[
  JiZhi/Services/Devices/SenderManagementService.swift
  JiZhi/Views/Devices/SenderKeysView.swift
  JiZhi/Views/Devices/NotificationLogsView.swift
]
paths.each do |path|
  reference = project.files.find { |file| file.path == path } || project.main_group.new_file(path)
  app.source_build_phase.add_file_reference(reference) unless app.source_build_phase.files_references.include?(reference)
end
tests = project.targets.find { |target| target.name == 'JiZhiUITests' } || project.new_target(:ui_test_bundle, 'JiZhiUITests', :ios, '18.0')
tests.add_dependency(app) unless tests.dependencies.any? { |dependency| dependency.target == app }
tests.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.createitv.pushnow.uitests'
  config.build_settings['PRODUCT_NAME'] = 'JiZhiUITests'
  config.build_settings['SUPPORTED_PLATFORMS'] = 'iphonesimulator iphoneos'
  config.build_settings['SDKROOT'] = 'iphoneos'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['TEST_TARGET_NAME'] = 'JiZhi'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
end
path = 'JiZhi/UITests/AccountFlowUITests.swift'
reference = project.files.find { |file| file.path == path } || project.main_group.new_file(path)
tests.source_build_phase.add_file_reference(reference) unless tests.source_build_phase.files_references.include?(reference)
project.save
scheme_path = 'JiZhi.xcodeproj/xcshareddata/xcschemes/JiZhi.xcscheme'
scheme = Xcodeproj::XCScheme.new(scheme_path)
unless scheme.test_action.testables.any? { |testable| testable.buildable_references.any? { |ref| ref.target_uuid == tests.uuid } }
  scheme.add_test_target(tests)
end
scheme.save_as('JiZhi.xcodeproj', 'JiZhi', true)
