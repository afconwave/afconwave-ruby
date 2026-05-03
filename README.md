# afconwave — Official Ruby SDK

> The official Ruby client library for the AfconWave Payments API.

[![Gem Version](https://badge.fury.io/rb/afconwave.svg)](https://badge.fury.io/rb/afconwave)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Features

- ✅ Simple, clean Ruby API
- 🌍 Payments, Payouts, and Refunds
- 🔒 Secure HMAC-SHA256 signature verification
- 🧪 Sandbox-ready with test keys
- 📦 Lightweight, zero external dependencies (uses `net/http`)

---

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'afconwave'
```

And then execute:

```bash
bundle install
```

Or install it directly:

```bash
gem install afconwave
```

---

## Quick Start

```ruby
require 'afconwave'

afw = AfconWave::Client.new(secret_key: 'sk_test_your_key_here')
```

---

## Usage Guide

### Create a Payment

```ruby
payment = afw.create_payment(
  amount: 5000,            # Amount in minor units (5000 = 50 XAF)
  currency: 'XAF',
  description: 'Order #1234',
  callback_url: 'https://yoursite.com/payment/callback',
  customer: {
    name: 'Jean Dupont',
    email: 'jean@example.com'
  }
)

puts payment['checkout_url'] # Redirect user here
puts payment['id']           # e.g., pay_507f191e8180f
```

### Retrieve a Payment

```ruby
payment = afw.retrieve_payment('pay_507f191e8180f')

puts payment['status']   # "pending" | "success" | "failed"
puts payment['amount']
```

### List Payments

```ruby
result = afw.list_payments(limit: 20, status: 'success')

result['data'].each do |payment|
  puts "#{payment['id']} - #{payment['amount']} #{payment['currency']}"
end
```

### Webhook Verification

```ruby
# In a Rails controller
def webhook
  payload = request.raw_post
  signature = request.headers['X-AfconWave-Signature']
  secret = ENV['AFCONWAVE_WEBHOOK_SECRET']

  is_valid = AfconWave::Client.verify_webhook_signature(
    payload: payload,
    signature: signature,
    secret: secret
  )

  if is_valid
    event = JSON.parse(payload)
    # Handle event...
    render json: { status: 'ok' }, status: 200
  else
    render json: { error: 'Invalid signature' }, status: 400
  end
end
```

---

## Error Handling

```ruby
begin
  payment = afw.create_payment(...)
rescue AfconWave::AuthError => e
  puts "Invalid API Key: #{e.message}"
rescue AfconWave::Error => e
  puts "API Error #{e.status_code}: #{e.message}"
end
```

---

## Configuration

| Parameter | Type | Default | Description |
|---|---|---|---|
| `secret_key` | `String` | **required** | Your AfconWave secret API key |
| `base_url` | `String` | `https://api.afconwave.com/v1` | API base URL |
| `timeout` | `Integer` | `30` | Request timeout in seconds |

---

## License

MIT © AfconWave
