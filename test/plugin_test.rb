require "test_helper"
require "shrine/plugins/tus"

require "shrine/storage/file_system"
require "shrine/storage/gridfs"
require "shrine/storage/s3"

require "securerandom"
require "tmpdir"

describe Shrine::Plugins::Tus do
  def attacher(storage)
    shrine_class = Class.new(Shrine)
    shrine_class.storages[:cache] = storage
    shrine_class.plugin :tus
    shrine_class::Attacher.new
  end

  describe "for FileSystem" do
    before do
      @storage = Shrine::Storage::FileSystem.new("#{Dir.tmpdir}/shrine")
      @attacher = attacher(@storage)
    end

    it "transforms tus URL to storage id" do
      tus_uid = SecureRandom.hex
      data    = {
        id:       "http://tus-server.org/files/#{tus_uid}",
        storage:  :cache,
        metadata: { "foo" => "bar" },
      }

      @attacher.assign(data)

      assert_equal tus_uid, @attacher.file.id
      assert_equal "bar",   @attacher.file.metadata["foo"]
      assert_equal :cache,  @attacher.file.storage_key
    end

    it "doesn't transform when file has already been transformed" do
      tus_uid = SecureRandom.hex
      data    = {
        id:       tus_uid,
        storage:  :cache,
        metadata: { "foo" => "bar" },
      }

      @attacher.assign(data)

      assert_equal tus_uid, @attacher.file.id
      assert_equal "bar",   @attacher.file.metadata["foo"]
      assert_equal :cache,  @attacher.file.storage_key
    end
  end

  describe "for Gridfs" do
    before do
      mongo = Mongo::Client.new("mongodb://127.0.0.1:27017/mydb", logger: Logger.new(nil))
      @storage = Shrine::Storage::Gridfs.new(client: mongo)
      @attacher = attacher(@storage)
    end

    after do
      @storage.clear!
    end

    it "transforms tus URL to storage id" do
      tus_uid = SecureRandom.hex
      id      = BSON::ObjectId.new

      @storage.bucket.files_collection.insert_one(_id: id, filename: tus_uid)

      data = {
        id:       "http://tus-server.org/files/#{tus_uid}",
        storage:  :cache,
        metadata: { "foo" => "bar" },
      }

      @attacher.assign(data)

      assert_equal id.to_s, @attacher.file.id
      assert_equal "bar",   @attacher.file.metadata["foo"]
      assert_equal :cache,  @attacher.file.storage_key
    end

    it "doesn't transform when file has already been transformed" do
      id   = BSON::ObjectId.new
      data = {
        id:       id.to_s,
        storage:  :cache,
        metadata: { "foo" => "bar" }
      }

      @attacher.assign(data)

      assert_equal id.to_s, @attacher.file.id
      assert_equal "bar",   @attacher.file.metadata["foo"]
      assert_equal :cache,  @attacher.file.storage_key
    end
  end if ENV["MONGO"]

  describe "for S3" do
    before do
      @storage = Shrine::Storage::S3.new(
        access_key_id:     "abc",
        secret_access_key: "xyz",
        region:            "eu-west-1",
        bucket:            "bucket",
      )
      @attacher = attacher(@storage)
    end

    it "transforms tus URL to storage id" do
      tus_uid = SecureRandom.hex
      data    = {
        id:       "http://tus-server.org/files/#{tus_uid}",
        storage:  :cache,
        metadata: { "foo" => "bar" },
      }

      @attacher.assign(data)

      assert_equal tus_uid, @attacher.file.id
      assert_equal "bar",   @attacher.file.metadata["foo"]
      assert_equal :cache,  @attacher.file.storage_key
    end

    it "doesn't transform when file has already been transformed" do
      tus_uid = SecureRandom.hex
      data    = {
        id:       tus_uid,
        storage:  :cache,
        metadata: { "foo" => "bar" },
      }

      @attacher.assign(data)

      assert_equal tus_uid, @attacher.file.id
      assert_equal "bar",   @attacher.file.metadata["foo"]
      assert_equal :cache,  @attacher.file.storage_key
    end
  end
end
