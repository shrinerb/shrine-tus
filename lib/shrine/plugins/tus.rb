require "json"
require "uri"

class Shrine
  module Plugins
    module Tus
      module AttacherMethods
        private

        def cached(data, **options)
          data = data.dup
          data = JSON.parse(data) if data.is_a?(String)

          if URI.regexp =~ (data["id"] || data[:id])
            id         = data.delete("id") || data.delete(:id)
            data["id"] = tus_url_to_storage_id(id, cache.storage)
          end

          super(data, **options)
        end

        def tus_url_to_storage_id(tus_url, storage)
          tus_uid = tus_url.split("/").last

          if defined?(Storage::FileSystem) && storage.is_a?(Storage::FileSystem)
            tus_uid
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
