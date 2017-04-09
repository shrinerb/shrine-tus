# Shrine::Tus

Provides tools for integrating [Shrine] with [tus-ruby-server].

## Installation

```ruby
gem "shrine-tus"
```

## Usage

Once the file has been uploaded to `tus-ruby-server`, you want to attach it to
a database record and move it to permanent Shrine storage.

```rb
class VideoUploader < Shrine
  plugin :default_storage, cache: :tus # set Shrine::Storage::Tus as temporary storage
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

The simplest setup is to have Shrine download the file uploaded to
`tus-ruby-server` through the app, which you can do by setting
`Shrine::Storage::Tus` as the temporary Shrine storage.

```rb
gem "shrine-url", "~> 0.3" # dependency of Shrine::Storage::Tus
```
```rb
require "shrine/storage/tus"

Shrine.storages[:tus] = Shrine::Storage::Tus.new
```
```rb
class VideoUploader < Shrine
  plugin :default_storage, cache: :tus # set Shrine::Storage::Tus as temporary storage
end
```

By default `wget` will be used for downloading, but if you need support for
partial downloads (e.g. you want to use `restore_cached_data`), you can switch
to using [Down] for downloads.

```rb
Shrine::Storage::Tus.new(downloader: :down)
```

If you want to Shrine, instead of downloading through the `tus-ruby-server`
app, to download directly from the tus storage, you can assign the tus storage
instance to `Shrine::Storage::Tus`:

```rb
Shrine::Storage::Tus.new(tus_storage: Tus::Server.opts[:storage])
```

Finally, if you want to use the same kind of permanent storage as your
`tus-ruby-server` uses, you can setup your temporary Shrine storage to match
the one your tus server uses, and load the `tus` plugin which will translate
the assigned tus URL to the corresponding storage ID.

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

For more details, and an explanation of pros and cons for each of the
approaches, see [shrine-tus-demo].

## Contributing

```sh
$ rake test
```

## License

[MIT](/LICENSE.txt)

[Shrine]: https://github.com/janko-m/shrine
[tus-ruby-server]: https://github.com/janko-m/tus-ruby-server
[Down]: https://github.com/janko-m/down
[shrine-tus-demo]: https://github.com/janko-m/shrine-tus-demo
