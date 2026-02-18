# Action Cable looks up channels via a registry populated when channel classes
# are loaded. In development with Zeitwerk lazy loading, channel files aren't
# loaded until something references them — but Action Cable's registry lookup
# doesn't trigger autoloading. This ensures channels are always loaded.
Rails.application.config.to_prepare do
  MergeChannel
end
