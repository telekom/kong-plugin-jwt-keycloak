#!/bin/bash
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# Test kid-optional JWT validation functionality

# Source environment helpers
if [ -f ./_env.sh ]; then
    . ./_env.sh
fi

echo "🧪 Testing kid-optional JWT validation..."

# Get a valid token from Keycloak (will have kid)
echo "🔑 Getting token from Keycloak..."
TOKEN_ENDPOINT="$KC_URL/auth/realms/$KC_REALM/protocol/openid-connect/token"

ACCESS_TOKEN=$(curl -s -X POST $TOKEN_ENDPOINT \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$KC_CLIENT_ID" \
  -d "client_secret=$KC_CLIENT_SECRET" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "❌ Failed to obtain access token"
  exit 1
fi

echo "✅ Got valid token from Keycloak"

# Decode token to inspect kid
HEADER=$(echo $ACCESS_TOKEN | cut -d. -f1 | base64 -d 2>/dev/null | jq .)
echo "📋 Token header:"
echo "$HEADER"

HAS_KID=$(echo "$HEADER" | jq -r '.kid // "null"')
if [ "$HAS_KID" != "null" ]; then
  echo "✅ Token has kid: $HAS_KID"
else
  echo "⚠️  Token does not have kid"
fi

# Test 1: Normal token with kid should work
echo ""
echo "🔍 Test 1: Token with kid (normal Keycloak token)..."
if ! retry_test_after_plugin_change "Token with kid validation" "200" \
  "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $ACCESS_TOKEN\" -o /dev/null"; then
  echo "❌ Test 1 failed"
  exit 1
fi
echo "✅ Test 1 passed: Token with kid works"

echo "⚠️ The test for kid-optional JWT validation is only covered in unit tests / spec validation"
