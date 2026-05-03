# Ruby SDK Deployment & Publishing Guide

This guide explains how to publish the `afconwave` gem to RubyGems.org.

## Prerequisites
1. You must have an account on [RubyGems.org](https://rubygems.org).
2. You must have the `gem` CLI tool configured with your credentials.

### Authentication Setup (One-Time)
Login to your RubyGems account via the CLI:
```bash
gem signin
```
Provide your email and password when prompted.

## Pre-Flight Checklist
- [ ] Ensure `test.rb` executes successfully (`ruby test.rb`).
- [ ] Update the `.gemspec` file (or `VERSION` constant) with the new semantic version (e.g., `1.0.1`).

## Publishing Steps

1. **Build the Gem**
   Run the gem build command against your gemspec file (ensure you have created an `afconwave.gemspec` file):
   ```bash
   gem build afconwave.gemspec
   ```
   This will output a binary gem file, e.g., `afconwave-1.0.0.gem`.

2. **Publish the Gem**
   Push the built gem directly to RubyGems:
   ```bash
   gem push afconwave-1.0.0.gem
   ```

3. **Verify**
   Visit `https://rubygems.org/gems/afconwave` to verify the new version is available.
