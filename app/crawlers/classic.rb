require "tempfile"

module HTTPRequestInResponse
  refine HTTP::Response do
    attr_accessor :req
  end

  refine HTTP::Client do
    alias_method :__perform__, :perform

    def perform(req, options)
      __perform__(req, options).tap { |res| res.req = req }
    end
  end
end

using HTTPRequestInResponse

Request = Struct.new(:uri, :method, :headers, keyword_init: true) do
end

Response = Struct.new(:status, :headers, :body, keyword_init: true) do
end

class Document
  extend Forwardable

  attr_accessor :uri, :request, :response, :content_type, :parent, :dependencies

  def initialize uri
    @uri = uri
  end

  def dependencies
    @dependencies ||= {}
  end

  def add_dependency dep
    binding.pry unless dep.is_a? Document
    fail "dependency must be a Document, got `#{ dep.class }`" unless dep.is_a? Document

    dep.parent = self
    dependencies[dep.uri] = dep
  end

  def inspect
    "#<Document:TODO content-type=#{ content_type } uri=#{ uri }>"
  end
end

class DependencyResolver
  def initialize doc
    @doc = doc
  end

  # TODO: how
  def resolve
    return resolve_html if @doc.content_type == "text/html"

    []
  end

  protected

  def resolve_html
    root_uri = Addressable::URI.parse @doc.uri

    nokogiri = Nokogiri::HTML(@doc.response.body)

    [
      "//link[@rel='stylesheet']/@href",
      "//script/@src",
      "//img/@src"
    ].flat_map(&nokogiri.method(:xpath))
      .map(&:to_s)
      .uniq
      .compact
      .reject { |src| src.start_with? "data:" } # TODO: should this reject all non http/https instead?
      .map(&Addressable::URI.method(:parse))
      .map { |link| (root_uri + link).to_s }
  end
end

class Classic
  class Client
    extend Forwardable

    def config
      @config ||= ActiveSupport::OrderedOptions.new.tap do |opts|
        opts.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.12; rv:57.0) Gecko/20100101 Firefox/57.0"

        opts.headers = {
          accept_language: "en-US,en;q=0.5",
          accept: "text/html;q=0.9,*/*;q=0.8; charset=utf-8"
        }

        opts.follow_redirects = true
      end
    end

    def_delegators :base, *HTTP::Request::METHODS

    private

    def base
      @base ||= HTTP.headers({ user_agent: config.user_agent }.merge(config.headers))
        .yield_self { |client| config.follow_redirects ? client.follow : client }
    end
  end

  def crawl site
    crawl_deps(site).tap(&method(:fetch_favicon_for))
  end

  private

  def crawl_deps site
    request(site).tap(&method(:fetch_assets_for))
  end

  def client
    @client ||= Client.new
  end

  def fetch_favicon_for root
    root_address = Addressable::URI.parse root.uri

    res = root_address
      .yield_self { |uri| uri.join "/favicon.ico" }
      .yield_self(&:to_s)
      .yield_self(&method(:request))

    root.add_dependency res
    return if (200...299).include? res.response.status

    root.xpath('//link[@rel="shortcut icon"]').find do |possible_favicon|
      res = possible_favicon.attr("href")
        .yield_self { |href| root_address.join href } # Ensures that a relative URI is converted to absolute
        .yield_self(&:to_s)
        .yield_self(&method(:request))

      root.add_dependency res

      (200..299).include? res.response.status
    end
  end

  def fetch_assets_for root
    DependencyResolver.new(root).resolve.each do |link|
      root.add_dependency crawl_deps link
    end
  end

  def request uri
    return if uri.start_with? "data:"

    Document.new(uri).tap do |document|
      puts "Fetching uri: '#{ uri }'"

      res = client.get uri

      body, content_type = with_temp_file do |temp_file|
        write_body response: res, to: temp_file
        content_type = get_content_type response: res, io: temp_file

        [temp_file.read, content_type]
      end

      # TODO: There is a lot more info to capture from the request and
      # response.
      document.request = Request.new uri: uri, method: "GET", headers: {} #res.req.headers
      document.response = Response.new status: res.code, headers: res.headers, body: body

      document.content_type = content_type
    rescue HTTP::ConnectionError => e
      debugger
    end
  end

  # TODO: Could these three methods live else where?
  def with_temp_file
    Tempfile.create do |temp_file|
      temp_file.binmode

      yield temp_file
    end
  end

  # Streams the response body into the temp file to hopefully avoid some
  # memory issues if this is a large document
  def write_body response:, to:
    io_handle = to

    response.body.each do |partial|
      io_handle.write partial
    end

    io_handle.rewind
  end

  def get_content_type response:, io:
    return response.content_type.mime_type if response.content_type.mime_type

    io_handle = io
    io_handle.rewind

    # some websites *cough*offline.pink*cough* don't return a content type
    # header, so we'll first see if the html doctype string is present and
    # guess this is text/html or we'll fallback to assuming its binary
    # https://en.wikipedia.org/wiki/Content_sniffing
    content_type ||= MimeMagic.by_magic(io_handle)
    content_type ||= "application/octet-stream"

    io_handle.rewind

    content_type
  end
end
