require 'aws/s3'
require 's3_storage'
ActiveRecord::Base.send(:include, Standout::S3Storage)