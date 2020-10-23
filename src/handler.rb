# frozen_string_literal: true

require 'lib/processor'

class VideoHandler
  def self.process(event:, context:)
    bucket_name = event.dig('s3', 'bucket_name')
    input_file_path = event.dig('s3', 'input_file_path')

    original_file = OriginalFile.new(bucket_name, input_file_path)

    versions = {}.tap do |hash|
      event['versions'].each do |version, options|
        transcoded_file = TranscodedFile.new(original_file, version, options)
        target_object = "#{options['location_prefix']}#{options['location']}"
        FileUploader.upload_file(bucket_name, target_object, transcoded_file.to_s)
        hash[version] = transcoded_file.metadata
      end
    end

    { status: :success, versions: versions }
  end
end
