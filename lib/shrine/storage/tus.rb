require "shrine/storage/url"
require "down/chunked_io"
require "tempfile"

class Shrine
  module Storage
    class Tus < Url
      attr_reader :tus_storage

      def initialize(tus_storage: nil, **options)
        @tus_storage = tus_storage

        super(delete: true, **options)
      end

      def open(id, **options)
        return super unless tus_storage

        open_from_tus_storage(tus_uid(id), **options)
      rescue ::Tus::NotFound
        raise Shrine::FileNotFound, "file #{id.inspect} not found on storage"
      end

      private

      def open_from_tus_storage(uid, rewindable: true, **)
        info     = get_tus_info(uid)
        response = get_tus_file(uid)

        Down::ChunkedIO.new(
          size:       Integer(info["Upload-Length"]),
          chunks:     response.each,
          on_close:   response.method(:close),
          rewindable: rewindable,
        )
      end

      def get_tus_file(uid)
        tus_storage.get_file(uid)
      end

      def get_tus_info(uid)
        tus_storage.read_info(uid)
      end

      def tus_uid(url)
        url.split("/").last
      end

      # Add "Tus-Resumable" header to HEAD and DELETE requests.
      def request(verb, url, **options)
        super(verb, url, headers: { "Tus-Resumable" => "1.0.0" }, **options)
      end
    end
  end
end
