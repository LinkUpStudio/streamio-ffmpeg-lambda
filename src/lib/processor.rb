# frozen_string_literal: true

require 'aws-sdk-s3'
require 'streamio-ffmpeg'

class FileUploader
  def self.upload_file(target_bucket, target_object, transcoded_file)
    Aws::S3::Resource.new.bucket(target_bucket)
                     .object(target_object).upload_file(transcoded_file)
  end
end

class TranscodedFile
  def self.base_directory
    '/tmp/transcoded_file/'
  end

  attr_reader :original_file_path, :version, :options

  def initialize(original_file_path, version, options)
    @original_file_path = original_file_path.to_s
    @version = version
    @options = options

    process
  end

  def directory_path
    @directory_path ||= "#{self.class.base_directory}#{version}/".tap do |path|
      FileUtils.mkdir_p(path) unless Dir.exist?(path)
    end
  end

  def filename
    @filename ||= options['filename'] || 'filename'
  end

  def file_path
    @file_path ||= "#{directory_path}#{filename}"
  end

  def to_s
    file_path
  end

  def metadata
    return nil unless (movie = FFMPEG::Movie.new(file_path)).valid?

    { duration: movie.duration,
      bitrate: movie.bitrate,
      size: movie.size,
      width: movie.width,
      height: movie.height,
      frame_rate: movie.frame_rate }.compact
  end

  private

  def process
    movie = FFMPEG::Movie.new(original_file_path)
    movie.transcode(file_path, options['transcoder_preset'])
  end
end

class OriginalFile
  ORIGINAL_FILE_PATH = '/tmp/original/'

  attr_reader :local_file_name

  def original_full_file_path
    @original_full_file_path ||= "#{ORIGINAL_FILE_PATH}#{local_file_name}"
  end

  def to_s
    original_full_file_path
  end

  def initialize(bucket_name, input_file_path, local_file_name = 'file')
    @local_file_name = local_file_name
    object = Aws::S3::Resource.new.bucket(bucket_name).object(input_file_path)
    FileUtils.mkdir_p(ORIGINAL_FILE_PATH) unless Dir.exist?(ORIGINAL_FILE_PATH)
    object.get(response_target: original_full_file_path)
  end
end
