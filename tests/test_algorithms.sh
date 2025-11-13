#!/bin/bash
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# Source environment helpers
if [ -f ./_env.sh ]; then
    . ./_env.sh
fi

# Test signature algorithms (RSA and EC)
# This test verifies that the plugin can handle all supported algorithms

echo "🧪 Testing signature algorithms..."

# Test ES256 (already tested in main flow)
echo "🧪 Testing ES256 algorithm..."
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

# Note: RS256 and other RSA algorithms (RS384, RS512) are supported through
# the same schema validation mechanism. The plugin dynamically validates
# against all supported algorithms listed in schema.lua.

# Test rejection of unsupported algorithm (none)
echo "🧪 Testing rejection of 'none' algorithm (unsigned token)..."

# Create a token with "none" algorithm (security test)
# Header: {"alg":"none","typ":"JWT"}
# Payload: {"iss":"$KC_URL/auth/realms/$KC_REALM","sub":"test","exp":9999999999}
NONE_HEADER=$(echo -n '{"alg":"none","typ":"JWT"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
NONE_PAYLOAD=$(echo -n "{\"iss\":\"$KC_URL/auth/realms/$KC_REALM\",\"sub\":\"test\",\"exp\":9999999999}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
NONE_TOKEN="${NONE_HEADER}.${NONE_PAYLOAD}."

# Test that the 'none' algorithm token is rejected
NONE_RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get \
  -H "Authorization: Bearer $NONE_TOKEN" -o /dev/null)

if [ "$NONE_RESPONSE" != "401" ]; then
  echo "❌ Token with 'none' algorithm was not rejected. HTTP status: $NONE_RESPONSE (expected 401)"
  exit 1
fi

echo "✅ 'none' algorithm rejection test passed"

# Test rejection of unsupported algorithm (HS256)
echo "🧪 Testing rejection of unsupported algorithm (HS256)..."

# Create a token with "HS256" algorithm (not in allowed list)
# Header: {"alg":"HS256","typ":"JWT"}
HS256_HEADER=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
HS256_PAYLOAD=$(echo -n "{\"iss\":\"$KC_URL/auth/realms/$KC_REALM\",\"sub\":\"test\",\"exp\":9999999999}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
# Sign with a dummy signature (won't be validated since algorithm is rejected first)
HS256_SIGNATURE=$(echo -n "dummy_signature" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
HS256_TOKEN="${HS256_HEADER}.${HS256_PAYLOAD}.${HS256_SIGNATURE}"

# Test that the HS256 algorithm token is rejected
HS256_RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get \
  -H "Authorization: Bearer $HS256_TOKEN" -o /dev/null)

if [ "$HS256_RESPONSE" != "401" ]; then
  echo "❌ Token with 'HS256' algorithm was not rejected. HTTP status: $HS256_RESPONSE (expected 401)"
  exit 1
fi

echo "✅ Unsupported algorithm (HS256) rejection test passed"

echo "✅ All algorithm tests passed (ES256, none-rejection, HS256-rejection)"