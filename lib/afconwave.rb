require 'uri'
require 'net/http'
require 'json'
require 'openssl'
require_relative 'afconwave/version'

module AfconWave
  def self.new(secret_key:, **options)
    Client.new(secret_key: secret_key, **options)
  end

  class Error < StandardError
    attr_reader :status_code, :code

    def initialize(message, status_code: nil, code: nil)
      @status_code = status_code
      @code = code
      super(message)
    end
  end

  class AuthError < Error; end

  class Client
    attr_accessor :secret_key, :base_url, :timeout

    def initialize(secret_key:, base_url: nil, timeout: 30, sandbox: false)
      raise AuthError, 'secret_key must be an afcw_test_... or afcw_live_... key' unless secret_key.to_s.start_with?('afcw_')

      @secret_key = secret_key
      @timeout = timeout

      env_url = ENV['AFCONWAVE_BASE_URL']
      @base_url =
        if base_url
          base_url.sub(%r{/+$}, '')
        elsif env_url
          env_url.sub(%r{/+$}, '')
        elsif sandbox
          'https://sandbox.api.afconwave.com/v1'
        else
          'https://api.afconwave.com/v1'
        end
    end

    def self.verify_webhook_signature(payload:, signature:, secret:, tolerance: 300, timestamp_prefixed: false, timestamp: nil)
      return false if signature.nil? || secret.nil?

      message = timestamp_prefixed && timestamp ? "#{timestamp}.#{payload}" : payload
      expected = OpenSSL::HMAC.hexdigest('sha256', secret, message)

      return false unless signature.is_a?(String) && expected.bytesize == signature.bytesize
      return false unless OpenSSL.fixed_length_secure_compare(expected, signature)

      if timestamp
        ts = timestamp.to_f
        webhook_time = ts > 1e12 ? ts / 1000.0 : ts
        return false if (Time.now.to_f - webhook_time).abs > tolerance
      end

      true
    end

    def deposits; @deposits ||= Resource::Deposits.new(self); end
    def withdrawals; @withdrawals ||= Resource::Withdrawals.new(self); end
    def wallets; @wallets ||= Resource::Wallets.new(self); end
    def transactions; @transactions ||= Resource::Transactions.new(self); end
    def refunds; @refunds ||= Resource::Refunds.new(self); end
    def disputes; @disputes ||= Resource::Disputes.new(self); end
    def airtime; @airtime ||= Resource::Airtime.new(self); end
    def data; @data ||= Resource::DataPlans.new(self); end
    def payment_links; @payment_links ||= Resource::PaymentLinks.new(self); end
    def rails; @rails ||= Resource::Rails.new(self); end

    # Back-compat
    def payments; deposits; end
    def payouts; withdrawals; end

    def request(method:, path:, data: nil, params: nil, idempotency_key: nil)
      uri = URI("#{base_url}#{path}")
      uri.query = URI.encode_www_form(params) if params

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      http.read_timeout = @timeout

      req =
        case method.to_s.upcase
        when 'POST'
          r = Net::HTTP::Post.new(uri)
          r.body = data.to_json if data
          r
        when 'GET'
          Net::HTTP::Get.new(uri)
        when 'PUT'
          r = Net::HTTP::Put.new(uri)
          r.body = data.to_json if data
          r
        when 'DELETE'
          Net::HTTP::Delete.new(uri)
        else
          raise Error, "Unsupported method #{method}"
        end

      req['X-API-Key'] = secret_key
      req['Content-Type'] = 'application/json'
      req['Accept'] = 'application/json'
      req['User-Agent'] = "AfconWave-Ruby-SDK/#{VERSION}"
      req['Idempotency-Key'] = idempotency_key if idempotency_key

      response = http.request(req)
      res_data = JSON.parse(response.body) rescue { 'error' => 'Invalid JSON response' }

      unless response.is_a?(Net::HTTPSuccess)
        case response.code.to_i
        when 401 then raise AuthError.new(res_data['error'] || 'Invalid API Key', status_code: 401)
        else raise Error.new(res_data['error'] || response.message, status_code: response.code.to_i, code: res_data['code'])
        end
      end

      res_data
    end

    def get_balances(**params)
      res = wallets.list(**params)
      res['wallets'] || res
    end

    def create_payment(**data); deposits.create(**data); end
    def create_payout(**data); withdrawals.create(**data); end
  end

  module Resource
    class Base
      def initialize(client); @client = client; end
    end

    class Deposits < Base
      def create(**data)
        @client.request(method: 'POST', path: '/deposits', data: data, idempotency_key: data[:idempotency_key] || data['idempotency_key'])
      end
      def retrieve(reference); @client.request(method: 'GET', path: "/deposits/#{reference}"); end
      def list(**params); @client.request(method: 'GET', path: '/deposits', params: params); end
      def sync(reference); @client.request(method: 'POST', path: "/deposits/#{reference}/sync"); end
    end

    class Withdrawals < Base
      def create(**data)
        @client.request(method: 'POST', path: '/withdrawals', data: data, idempotency_key: data[:idempotency_key] || data['idempotency_key'])
      end
      def list(**params); @client.request(method: 'GET', path: '/withdrawals', params: params); end
      def sync(reference); @client.request(method: 'POST', path: "/withdrawals/#{reference}/sync"); end
      def methods(country_code:); @client.request(method: 'GET', path: '/withdrawals/methods', params: { country_code: country_code }); end
      def nigeria_banks; @client.request(method: 'GET', path: '/withdrawals/nigeria-banks'); end
    end

    class Wallets < Base
      def list(**params); @client.request(method: 'GET', path: '/wallets', params: params); end
      def ensure(currency:, business_id: nil)
        body = { currency: currency }
        body[:business_id] = business_id if business_id
        @client.request(method: 'POST', path: '/wallets/ensure', data: body)
      end
      def convert(**data)
        @client.request(method: 'POST', path: '/wallets/convert', data: data, idempotency_key: data[:idempotency_key] || data['idempotency_key'])
      end
      def transfer(**data)
        @client.request(method: 'POST', path: '/wallets/transfer', data: data, idempotency_key: data[:idempotency_key] || data['idempotency_key'])
      end
      def rates; @client.request(method: 'GET', path: '/wallets/rates'); end
    end

    class Transactions < Base
      def list(**params); @client.request(method: 'GET', path: '/transactions', params: params); end
      def retrieve(id_or_ref); @client.request(method: 'GET', path: "/transactions/#{id_or_ref}"); end
      def recent(limit: 4); @client.request(method: 'GET', path: '/transactions/recent', params: { limit: limit }); end
    end

    class Refunds < Base
      def create(**data); @client.request(method: 'POST', path: '/refunds', data: data); end
      def list; @client.request(method: 'GET', path: '/refunds'); end
    end

    class Disputes < Base
      def open(**data); @client.request(method: 'POST', path: '/disputes', data: data); end
      def list; @client.request(method: 'GET', path: '/disputes'); end
    end

    class Airtime < Base
      def purchase(**data); @client.request(method: 'POST', path: '/airtime', data: data); end
    end

    class DataPlans < Base
      def purchase(**data); @client.request(method: 'POST', path: '/data', data: data); end
    end

    class PaymentLinks < Base
      def create(**data); @client.request(method: 'POST', path: '/payment-links', data: data); end
      def list; @client.request(method: 'GET', path: '/payment-links'); end
    end

    class Rails < Base
      def payout_methods(country_code:); @client.request(method: 'GET', path: '/rails/payout-methods', params: { country_code: country_code }); end
    end
  end
end
