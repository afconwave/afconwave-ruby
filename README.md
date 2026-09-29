# afconwave — Official Ruby SDK

```ruby
require 'afconwave'

afc = AfconWave::Client.new(secret_key: 'afc_sk_test_your_key_here')
```

Use `AfconWave::Client.verify_webhook_signature` (timing-safe + replay window).
Event name may be `type` or `event`.
