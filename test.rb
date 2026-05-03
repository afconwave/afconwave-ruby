require_relative 'lib/afconwave'

begin
  # Test the new shortcut
  client = AfconWave.new(secret_key: 'sk_test_123')
  puts "✅ AfconWave shortcut working"
  
  # Test instantiation
  if client.is_a?(AfconWave::Client)
    puts "✅ Ruby SDK Instantiated Successfully!"
  end

  # Test Webhook Verification
  payload = '{"event":"payment.success","data":{"id":"123"}}'
  secret = 'test_secret'
  signature = OpenSSL::HMAC.hexdigest('sha256', secret, payload)
  
  is_valid = AfconWave::Client.verify_webhook_signature(
    payload: payload,
    signature: signature,
    secret: secret
  )
  
  if is_valid
    puts "✅ Webhook signature verification working"
  else
    puts "❌ Webhook signature verification FAILED"
    exit 1
  end

  puts "\n🚀 All Ruby SDK local tests PASSED!"

rescue => e
  puts "❌ Test failed: #{e.message}"
  puts e.backtrace
  exit 1
end

