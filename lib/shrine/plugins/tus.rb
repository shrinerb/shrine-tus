require "json"
require "uri"

class Shrine
  module Plugins
    module Tus
      module AttacherMethods
        def assign(value)
          if value.is_a?(String) && value != ""
            data = JSON.parse(value)
            data["id"] = tus_url_to_storage_id(data["id"], cache.storage) if URI.regexp =~ data["id"]
            super(data.to_json)
          else
            super
          end
        end

        private

        def tus_url_to_storage_id(tus_url, storage)
          tus_uid = tus_url.split("/").last

          if defined?(Storage::FileSystem) && storage.is_a?(Storage::FileSystem)
            "#{tus_uid}.file"
          elsif defined?(Storage::Gridfs) && storage.is_a?(Storage::Gridfs)
            grid_info = storage.bucket.find(filename: tus_uid).limit(1).first
            grid_info[:_id].to_s
          elsif defined?(Storage::S3) && storage.is_a?(Storage::S3)
            tus_uid
          else
            raise Error, "undefined conversion of tus URL to storage id for storage #{storage.inspect}"
          end
        end
      end
    end

    register_plugin(:tus, Tus)
  end
end
