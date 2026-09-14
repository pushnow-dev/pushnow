require 'xcodeproj'

project = Xcodeproj::Project.open('JiZhi.xcodeproj')
files = {
  'JiZhi' => %w[
    JiZhi/Models/DiscoverySubscription.swift
    JiZhi/Services/Discovery/DiscoverySubscriptionStore.swift
    JiZhi/Services/Discovery/DiscoverySubscriptionCopy.swift
    JiZhi/ViewModels/DiscoverySubscriptionsViewModel.swift
    JiZhi/Views/Discover/DiscoverySubscriptionEditor.swift
  ],
  'JiZhiTests' => %w[JiZhi/Tests/DiscoverySubscriptionTests.swift]
}
files.each do |name, paths|
  target = project.targets.find { |item| item.name == name }
  raise "Missing target #{name}" unless target
  paths.each do |path|
    reference = project.files.find { |file| file.path == path } || project.main_group.new_file(path)
    target.source_build_phase.add_file_reference(reference) unless target.source_build_phase.files_references.include?(reference)
  end
end
project.save
