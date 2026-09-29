require_relative 'lib/afconwave'

begin
  client = AfconWave.new(secret_key: 'afcw_sk_test_123')
  puts "Ruby SDK Instantiated Successfully!" if client.is_a?(AfconWave::Client)
rescue => e
  puts "Test failed: #{e.message}"
  exit 1
end
