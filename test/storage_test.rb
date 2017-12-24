require "test_helper"
require "shrine/storage/tus"

require "tus/storage/filesystem"
require "webmock/minitest"

require "ostruct"
require "tmpdir"
require "stringio"

describe Shrine::Storage::Tus do
  before do
    @storage = Shrine::Storage::Tus.new
  end

  describe "#upload" do
    it "replaces the id with an URL" do
      io = OpenStruct.new(url: "http://tus-server.org/files/8c295d6c83")
      @storage.upload(io, id = "foo")
      assert_equal "http://tus-server.org/files/8c295d6c83", id
    end
  end

  describe "#download" do
    it "downloads the remote file into a Tempfile" do
      stub_request(:get, "http://tus-server.org/files/8c295d6c83").to_return(body: "file")
      tempfile = @storage.download("http://tus-server.org/files/8c295d6c83")
      assert_instance_of Tempfile, tempfile
      assert_equal "file", tempfile.read
    end

    it "downloads directly from tus storage" do
      tus_storage = Tus::Storage::Filesystem.new("#{Dir.tmpdir}/shrine")
      @storage = Shrine::Storage::Tus.new(tus_storage: tus_storage)

      tus_storage.create_file("8c295d6c83")
      tus_storage.patch_file("8c295d6c83", StringIO.new("file"))
      tempfile = @storage.download("http://tus-server.org/files/8c295d6c83")

      assert_instance_of Tempfile, tempfile
      assert_equal "file", tempfile.read
    end
  end

  describe "#open" do
    it "opens the remote file" do
      stub_request(:get, "http://tus-server.org/files/8c295d6c83").to_return(body: "file")
      io = @storage.open("http://tus-server.org/files/8c295d6c83")
      assert_instance_of Down::ChunkedIO, io
      assert_equal "file", io.read
    end

    it "opens directly from tus storage" do
      tus_storage = Tus::Storage::Filesystem.new("#{Dir.tmpdir}/shrine")
      @storage = Shrine::Storage::Tus.new(tus_storage: tus_storage)

      tus_storage.create_file("8c295d6c83")
      tus_storage.update_info("8c295d6c83", { "Upload-Length" => "4" })
      tus_storage.patch_file("8c295d6c83", StringIO.new("file"))
      io = @storage.open("http://tus-server.org/files/8c295d6c83")

      assert_instance_of Down::ChunkedIO, io
      assert_equal 4,      io.size
      assert_equal "file", io.read
    end
  end

  describe "#exists?" do
    it "checks whether the remote file exists" do
      stub_request(:head, "http://tus-server.org/files/8c295d6c83")
        .with(headers: {"Tus-Resumable" => "1.0.0"})
        .to_return(status: 200)

      assert_equal true, @storage.exists?("http://tus-server.org/files/8c295d6c83")

      assert_requested(:head, "http://tus-server.org/files/8c295d6c83",
        headers: {"Tus-Resumable" => "1.0.0"})
    end
  end

  describe "#url" do
    it "returns the given URL" do
      assert_equal "http://tus-server.org/files/8c295d6c83",
                   @storage.url("http://tus-server.org/files/8c295d6c83")
    end
  end

  describe "#delete" do
    it "issues a delete request" do
      stub_request(:delete, "http://tus-server.org/files/8c295d6c83")
        .with(headers: {"Tus-Resumable" => "1.0.0"})

      @storage.delete("http://tus-server.org/files/8c295d6c83")

      assert_requested(:delete, "http://tus-server.org/files/8c295d6c83",
        headers: {"Tus-Resumable" => "1.0.0"})
    end
  end
end
