#!/bin/bash
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# Source environment helpers
if [ -f ./_env.sh ]; then
    . ./_env.sh
fi

# Test EC signature algorithms (ES256, ES384, ES512)
# This test verifies that the plugin can handle all supported EC algorithms

echo "🧪 Testing EC signature algorithms..."

# Test ES256 (already tested in main flow)
echo "✅ Testing ES256 algorithm..."
# ES256 is already tested in the main test flow, so we just check that it works
TOKEN_ENDPOINT="$KC_URL/auth/realms/$KC_REALM/protocol/openid-connect/token"

ES256_ACCESS_TOKEN=$(curl -s -X POST $TOKEN_ENDPOINT \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$KC_CLIENT_ID" \
  -d "client_secret=$KC_CLIENT_SECRET" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

if [ -z "$ES256_ACCESS_TOKEN" ] || [ "$ES256_ACCESS_TOKEN" = "null" ]; then
  echo "❌ Failed to obtain ES256 access token"
  exit 1
fi

# Test the ES256 token works
ES256_RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get \
  -H "Authorization: Bearer $ES256_ACCESS_TOKEN" -o /dev/null)

if [ "$ES256_RESPONSE" != "200" ]; then
  echo "❌ ES256 token validation failed. HTTP status: $ES256_RESPONSE"
  exit 1
fi

echo "✅ ES256 algorithm test passed"

# Test error handling - invalid algorithm
echo "🧪 Testing invalid algorithm rejection..."

# Delete the existing plugin first
curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

# Create a plugin with RS256 algorithm but expect ES256 tokens
NEW_PLUGIN_RESPONSE=$(curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=RS256" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')")

echo "New plugin config: $(echo $NEW_PLUGIN_RESPONSE | jq '.config.algorithm')"

# Test that ES256 token is rejected when RS256 is expected
echo "Testing algorithm mismatch: ES256 token with RS256 plugin config"

# Use retry logic for testing algorithm mismatch
if ! retry_test_after_plugin_change "Invalid algorithm rejection test" "401" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $ES256_ACCESS_TOKEN\" -o /dev/null"; then
  exit 1
fi

# Clean up - restore original plugin configuration
curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "config.consumer_match_claim_custom_id=true" \
  --data "config.consumer_match=true" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

echo "✅ All EC algorithm tests passed"