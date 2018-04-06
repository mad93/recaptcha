require 'recaptcha/configuration'
require 'recaptcha/client_helper'
require 'recaptcha/verify'
require 'uri'
require 'net/http'
require 'net/https'

module Recaptcha
  CONFIG = {
    'server_url' => 'https://www.google.com/recaptcha/api.js',
    'verify_url' => 'https://www.google.com/recaptcha/api/siteverify'
  }.freeze

  USE_SSL_BY_DEFAULT              = false
  HANDLE_TIMEOUTS_GRACEFULLY      = true
  DEFAULT_TIMEOUT = 3

  # Gives access to the current Configuration.
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Allows easy setting of multiple configuration options. See Configuration
  # for all available options.
  #--
  # The temp assignment is only used to get a nicer rdoc. Feel free to remove
  # this hack.
  #++
  def self.configure
    config = configuration
    yield(config)
  end

  def self.with_configuration(config)
    original_config = {}

    config.each do |key, value|
      original_config[key] = configuration.send(key)
      configuration.send("#{key}=", value)
    end

    yield if block_given?
  ensure
    original_config.each { |key, value| configuration.send("#{key}=", value) }
  end

  def self.get(verify_hash, options)
    begin
        recaptcha = nil
        http = if Recaptcha.configuration.proxy
          proxy_server = URI.parse(Recaptcha.configuration.proxy)
          Net::HTTPS::Proxy(proxy_server.host, proxy_server.port, proxy_server.user, proxy_server.password)
        else
          Net::HTTPS
        end

        Timeout::timeout(options[:timeout] || 3) do
            recaptcha = http.post_form(URI.parse(Recaptcha.configuration.verify_url), {
                "secret" => verify_hash["secret"],
                "response" => verify_hash["response"],
                "remoteip" => verify_hash["remoteip"]
            })
        end

        return recaptcha.body
    rescue Exception => e
        puts e.message
        raise RecaptchaError, e.message, e.backtrace
    end
  end

  def self.i18n(key, default)
    if defined?(I18n)
      I18n.translate(key, default => :default)
    else
      default
    end
  end

  class RecaptchaError < StandardError
  end

  class VerifyError < RecaptchaError
  end
end
