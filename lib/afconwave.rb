require 'uri'
require 'net/http'
require 'json'
require 'openssl'
require_relative 'afconwave/version'

module AfconWave
  # Shortcut to create a new client
  def self.new(secret_key:, **options)
    Client.new(secret_key: secret_key, **options)
  end
  # ─── Exceptions ──────────────────────────────────────────────────────────────

  class Error < StandardError
    attr_reader :status_code, :code

    def initialize(message, status_code: nil, code: nil)
      @status_code = status_code
      @code = code
      super(message)
    end
  end

  class AuthError < Error; end
  class PaymentError < Error; end

  # ─── Main Client ──────────────────────────────────────────────────────────────

  class Client
    attr_accessor :secret_key, :base_url, :timeout

    def initialize(secret_key:, base_url: 'https://api.afconwave.com/api/v1', timeout: 30)
      @secret_key = secret_key
      @base_url = base_url
      @timeout = timeout
    end

    def self.verify_webhook_signature(payload:, signature:, secret:, tolerance: 300)
      # 1. Verify Signature (timing-safe compare via OpenSSL stdlib)
      expected = OpenSSL::HMAC.hexdigest('sha256', secret, payload)

      # OpenSSL.fixed_length_secure_compare requires equal-length inputs.
      return false unless signature.is_a?(String) && expected.bytesize == signature.bytesize
      return false unless OpenSSL.fixed_length_secure_compare(expected, signature)

      # 2. Verify Timestamp (Replay Protection)
      begin
        data = JSON.parse(payload)
        if data['timestamp']
          current_time = Time.now.to_i # seconds
          webhook_time = data['timestamp'] / 1000 # convert ms to seconds
          age = (current_time - webhook_time).abs

          return false if age > tolerance
        end
      rescue JSON::ParserError
        # Non-JSON payload, signature is valid but can't check timestamp
      end

      true
    end

    def payments; @payments ||= Resource::Payments.new(self); end
    def payouts; @payouts ||= Resource::Payouts.new(self); end
    def crypto; @crypto ||= Resource::Crypto.new(self); end
    def refunds; @refunds ||= Resource::Refunds.new(self); end
    def disputes; @disputes ||= Resource::Disputes.new(self); end

    def request(method:, path:, data: nil, params: nil)
      uri = URI("#{base_url}#{path}")
      uri.query = URI.encode_www_form(params) if params

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      http.read_timeout = @timeout

      req = case method.upcase
            when 'POST'
              request = Net::HTTP::Post.new(uri)
              request.body = data.to_json if data
              request
            when 'GET'
              Net::HTTP::Get.new(uri)
            else
              raise Error.new("Unsupported method #{method}")
            end

      req['Authorization'] = "Bearer #{secret_key}"
      req['Content-Type'] = 'application/json'
      req['Accept'] = 'application/json'

      response = http.request(req)
      res_data = JSON.parse(response.body) rescue { 'error' => 'Invalid JSON response' }

      unless response.is_a?(Net::HTTPSuccess)
        case response.code.to_i
        when 401 then raise AuthError.new(res_data['error'] || 'Invalid API Key', status_code: 401)
        else raise Error.new(res_data['error'] || response.message, status_code: response.code.to_i, code: res_data['code'])
        end
      end

      res_data['data'] || res_data
    end

    # ─── Top-level Convenience Methods (Matches README) ─────────────────────

    def create_payment(**data); payments.create(**data); end
    def retrieve_payment(id); payments.retrieve(id); end
    def list_payments(**params); payments.list(**params); end
    def create_payout(**data); payouts.create(**data); end
  end

  module Resource
    class Base
      def initialize(client); @client = client; end
    end

    class Payments < Base
      def create(**data); @client.request(method: 'POST', path: '/payments', data: data); end
      def retrieve(id); @client.request(method: 'GET', path: "/payments/#{id}"); end
      def list(**params); @client.request(method: 'GET', path: '/payments', params: params); end
    end

    class Payouts < Base
      def create(**data); @client.request(method: 'POST', path: '/payouts', data: data); end
      def retrieve(id); @client.request(method: 'GET', path: "/payouts/#{id}"); end
    end

    class Crypto < Base
      def buy(**data); @client.request(method: 'POST', path: '/crypto/buy', data: data); end
    end

    class Refunds < Base
      def create(payment_id:, amount:, reason: nil)
        @client.request(method: 'POST', path: '/refunds', data: { paymentId: payment_id, amount: amount, reason: reason })
      end
      def list; @client.request(method: 'GET', path: '/refunds'); end
    end

    class Disputes < Base
      def open(transaction_id:, reason:, description:)
        @client.request(method: 'POST', path: '/disputes', data: { transactionId: transaction_id, reason: reason, description: description })
      end
      def list; @client.request(method: 'GET', path: '/disputes'); end
      def resolve(dispute_id:, resolution:, resolution_details: nil)
        @client.request(method: 'POST', path: "/disputes/#{dispute_id}/resolve", data: { resolution: resolution, resolutionDetails: resolution_details })
      end
    end
  end
end
