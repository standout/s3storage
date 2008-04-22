module Standout
    module S3Storage #:nodoc:

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def s3_storage(options = {})
          attr_accessor :file
          cattr_accessor :configuration
          after_create :save_file_to_s3
          after_destroy :remove_file_from_s3
          
          self.configuration = {
            :bucket => nil,
            :access_key => nil,
            :secret => nil
          }
          self.configuration.update(options)
          
          include InstanceMethods
          
        end
        
      end

      module InstanceMethods

        def uploaded_data=(uploaded_data)
            @file = uploaded_data
            self.original_filename = sanitize_filename(uploaded_data.original_filename)
            write_attribute :original_filename, sanitize_filename(uploaded_data.original_filename)
            write_attribute :content_type, uploaded_data.content_type.strip
        end
        
        def save_file_to_s3
          connect_to_s3
          check_if_bucket_exists
          save_the_file_to_s3
        end

        def s3_path
          "http://s3.amazonaws.com/#{self.configuration[:bucket]}/#{self.id}/#{self.original_filename}"
        end

        private

        # Makes the required connection to S3
        def connect_to_s3
          AWS::S3::Base.establish_connection!(
            :access_key_id     => self.configuration[:access_key],
            :secret_access_key => self.configuration[:secret]
          )
        end

        def save_the_file_to_s3
          if @file.nil?
            logger.warning "Error: File not attached?"
            self.destroy
          else
            logger.info "Uploading to S3: #{@file.original_filename}"
            AWS::S3::S3Object.store(
              "#{self.id}/#{@file.original_filename}",
              @file.read,
              self.configuration[:bucket],
              :content_type => @file.content_type,
              :access => :public_read
              )
            write_attribute :original_filename, @file.original_filename
            write_attribute :content_type, @file.content_type
            self.save!
          end
        end

        # Tries to remove the file. Since the file could be removed manually 
        # it fails with only a log message that the file could not be removed.
        def remove_file_from_s3
          connect_to_s3
          if AWS::S3::S3Object.exists? "#{self.id}/#{self.original_filename}", self.configuration[:bucket]
            AWS::S3::S3Object.delete "#{self.id}/#{self.original_filename}", self.configuration[:bucket]
            logger.info "File #{self.original_filename} was removed from S3"
          else
            logger.info "File could not be found on S3, and therefore not removed."
          end
        end

        # See if the S3 bucket does exist. If not, create it.
        def check_if_bucket_exists
          unless AWS::S3::Service.buckets.include?(self.configuration[:bucket])
            logger.info "Created bucket #{self.configuration[:bucket]}"
            AWS::S3::Bucket.create(self.configuration[:bucket])
          end
        end

        # Cleans up the filename for use in our applicatoin
        def sanitize_filename(file_name)
           # get only the filename, not the whole path (from IE)
           just_filename = File.basename(file_name) 
           # replace all non-alphanumeric, underscore or periods with underscores
           just_filename.gsub(/[^\w\.\-]/,'_') 
         end
        
      end
    end
end