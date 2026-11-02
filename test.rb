require_relative 'lib/afconwave'

begin
  client = AfconWave::Client.new(secret_key: 'afcw_test_smoke_only')
  puts 'Ruby SDK Instantiated Successfully!'
rescue => e
  puts "Failed: #{e.message}"
  exit 1
end
