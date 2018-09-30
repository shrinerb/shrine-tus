# Shrine::Tus

Provides tools for integrating [Shrine] with [tus-ruby-server].

## Installation

```rb
gem "shrine-tus", "~> 1.2"
```

## Usage

When the file is uploaded to the tus server, you'll probably want to attach
it to a database record and move it to permanent storage. The storage that
tus-ruby-server uses should be considered temporary, as some uploads might
never be finished, and tus-ruby-server needs to clear expired uploads.

Shrine-tus provides **three ways** of moving the file uploaded into the tus
server to permanent storage, which differ in performance and level of
decoupling. But regardless of the approach you choose, the code for attaching
the uploaded file works the same:

```rb
class VideoUploader < Shrine
  # ...
end
```
```rb
class Movie < Sequel::Model
  include VideoUploader::Attachment.new(:video)
end
```
```rb
file_data #=> {"id":"http://tus-server.org/68db42638388ae645ab747b36a837a79", "storage":"cache", "metadata":{...}}
Movie.create(video: file_data)
```

See [shrine-tus-demo] for an example application that uses shrine-tus.

### Metadata

Before we go into the implementation, there is an important caveat about
metadata extraction.

By default Shrine won't try to extract metadata from files that were uploaded
directly, because that would require (at least partially) retrieving file
content from the storage, which could be potentially expensive depending on the
storage and the kind of metadata that are being extracted. For example, when
using disk storage the performance penalty would be minimal, but with S3
storage there will be an HTTP download. If you're only using the
`determine_mime_type` plugin, then this impact will be minimal as only the
first few kilobytes will actualy be downloaded, but if you're doing your own
metadata extraction you'll likely be downloading the whole file.

That being said, you can still tell Shrine to extract metadata. If you want it
to be done automatically on assignment (which is useful if you want to validate
the extracted metadata), you can load the `restore_cached_data` plugin:

```rb
Shrine.plugin :restore_cached_data
```

On the other hand, if you're using backgrounding and don't need to validate the
extracted metadata, you can extract metadata during background promotion using
the `refresh_metadata` plugin (which the `restore_cached_data` plugin uses
internally):

```rb
Shrine.plugin :refresh_metadata
```
```rb
class MyUploader < Shrine
  plugin :processing

  # this will be called in the background if using backgrounding plugin
  process(:store) do |io, context|
    io.tap(&:refresh_metadata!)
  end
end
```

Alternatively, if you have metadata that can be cheaply extracted in the
foreground (such as MIME type), but there is also metadata that you want
extracted asynchronously, you can combine the two approaches. Here is an
example of extracting additional video metadata in the background (provided
the `backgrounding` plugin is used):

```rb
Shrine.plugin :restore_cached_data
```
```rb
class MyUploader < Shrine
  plugin :determine_mime_type # this will be called in the foreground
  plugin :processing

  # this will be called in the background if using backgrounding plugin
  process(:store) do |io, context|
    additional_metadata = io.download do |file|
      # example of metadata extraction
      movie = FFMPEG::Movie.new(file.path) # uses the streamio-ffmpeg gem

      { "duration"   => movie.duration,
        "bitrate"    => movie.bitrate,
        "resolution" => movie.resolution,
        "frame_rate" => movie.frame_rate }
    end

    io.metadata.merge!(additional_metadata)

    io
  end
end
```

### Approach A: Downloading through tus server

Conceptionally the simplest setup is to have Shrine download the uploaded file
through your tus server app. This is also the most decoupled option, because
your main app can remain completely oblivious to what storage the tus server
app uses internally, or in which programming language is it written (e.g. you
could swap it for [tusd] and everything should continue to work the same).

To use this approach, you need to assign `Shrine::Storage::Tus` as your
temporary storage:

```rb
require "shrine/storage/tus"

Shrine.storages = {
  cache: Shrine::Storage::YourTemporaryStorage.new(...),
  store: Shrine::Storage::YourPermanentStorage.new(...),
  tus:   Shrine::Storage::Tus.new
}
```
```rb
class VideoUploader < Shrine
  storages[:cache] = storages[:tus] # set Shrine::Storage::Tus as temporary storage
end
```

`Shrine::Storage::Tus` is a subclass of `Shrine::Storage::Url`, which uses
[Down] for downloading. By default, the `Down::Http` backend is used, which is
implemented using [HTTP.rb].

If you're experiencing a lot of network hiccups while downloading, you might
want to consider switching to the `Down::Wget` backend, as `wget` automatically
resumes the download in case of network hiccups.

```rb
Shrine::Storage::Tus.new(downloader: :wget)
```

### Approach B: Downloading directly from storage

While the appoach **A** is decoupled from the tus server implementation, it
might not be the most performant depending on the overhead between your main
app and the tus server app, how well the web server that you use for the tus
server app handles streaming downloads (whether it blocks the web worker, thus
affecting the app's request throughput), and whether you have hard request
timeout limits like on Heroku. Down will also temporarily cache downloaded
content to disk while copying to the permanent storage, so that adds I/O and
disk usage.

Instead of downloading through the tus server app, you can download directly
from the underlying storage that it uses. This requires that you have the tus
storage configured in your main app (which might already by the case if you're
running tus server in the same process as your main app), and you can pass that
storage to `Shrine::Storage::Tus`:

```rb
Shrine::Storage::Tus.new(tus_storage: Tus::Server.opts[:storage])
```

### Approach C: Tus storage equals Shrine storage

Approach **B** internally utilizes the common interface of each tus storage
object for streaming the file uploaded to that storage, via `#each`. However,
certain Shrine storage classes have optimizations when copying/moving a file
between two storages of the **same kind**.

So if you want to use the same kind of permanent storage as your tus server
uses, you can reap those performance benefits. In order to do this, instead of
using `Shrine::Storage::Tus` as your temporary Shrine storage as we did in
approaches A and B, we will be using a regular Shrine storage which will match
the storage that the tus server uses. In other words, your Shrine storage and
your tus storage would reference the same files. So, if your tus server app is
configured with either of the following storages:

```rb
Tus::Server.opts[:storage] = Tus::Storage::Filesystem.new("data")
Tus::Server.opts[:storage] = Tus::Storage::Gridfs.new(client: mongo, prefix: "tus")
Tus::Server.opts[:storage] = Tus::Storage::S3.new(prefix: "tus", **s3_options)
```

Then Shrine should be configured with the corresponding temporary storage:

```rb
Shrine.storages[:cache] = Shrine::Storage::FileSystem.new("data")
Shrine.storages[:cache] = Shrine::Storage::Gridfs.new(client: mongo, prefix: "tus")
Shrine.storages[:cache] = Shrine::Storage::S3.new(prefix: "tus", **s3_options)
```

In approaches **A** and **B** we didn't need to change the file data received
from the client, because we were using a subclass of `Shrine::Storage::Url`,
which accepts the `id` field as a URL. But with this approach the `id` field
will need to be translated from the tus URL to the correct ID for your
temporary Shrine storage, using the `tus` plugin that ships with shrine-tus.

```rb
Shrine.storages = {
  cache: Shrine::Storage::YourTemporaryStorage.new(...),
  store: Shrine::Storage::YourPermanentStorage.new(...),
}
```
```rb
class VideoUploader < Shrine
  plugin :tus
end
```

Note that it's **not** recommended to use the `delete_promoted` Shrine plugin
with this this approach, because depending on the tus storage implementation
it could cause HEAD requests to the tus server app to return a success for files
that were deleted by Shrine.

These are the performance advantages for each of the official storages:

#### Filesystem

`Shrine::Storage::FileSystem` will have roughly the same performance as in
option **B**, though it will allocate less memory. However, if you load the
`moving` plugin, Shrine will execute a `mv` command between the tus storage
and permanent storage, which executes instantaneously regardless of the
filesize.

```rb
Shrine.plugin :moving
```

#### Mongo GridFS

`Shrine::Storage::Gridfs` will use more efficient copying, resulting in up to
2x speedup according to my benchmarks.

#### AWS S3

`Shrine::Storage::S3` will issue a single S3 COPY request for files smaller
than 100MB, while files 100MB or larger will be divided into multiple chunks
which will be copied individually and in parallel using S3's multipart API.

## Contributing

```sh
$ bundle exec rake test
```

## License

[MIT](/LICENSE.txt)

[Shrine]: https://github.com/shrinerb/shrine
[tus-ruby-server]: https://github.com/janko-m/tus-ruby-server
[Down]: https://github.com/janko-m/down
[HTTP.rb]: https://github.com/httprb/http
[shrine-tus-demo]: https://github.com/shrinerb/shrine-tus-demo
[tusd]: https://github.com/tus/tusd
