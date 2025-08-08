#!/bin/bash
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# Source environment helpers
if [ -f ./_env.sh ]; then
    . ./_env.sh
fi

# Test error conditions and edge cases
echo "🧪 Testing error conditions and edge cases..."

# Test 1: Request without token should return 401
echo "🔍 Testing request without token..."
if ! retry_test_after_plugin_change "Request without token test" "401" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -o /dev/null"; then
  exit 1
fi

# Test 2: Request with invalid token should return 401
echo "🔍 Testing request with invalid token..."
if ! retry_test_after_plugin_change "Request with invalid token test" "401" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer invalid.token.here\" -o /dev/null"; then
  exit 1
fi

# Test 3: Request with malformed token should return 401
echo "🔍 Testing request with malformed token..."
if ! retry_test_after_plugin_change "Request with malformed token test" "401" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer not-a-jwt-token\" -o /dev/null"; then
  exit 1
fi

# Test 4: Test with wrong issuer
echo "🔍 Testing wrong issuer rejection..."

# Create a temporary plugin with different allowed issuer
curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=https://wrong-issuer.example.com/auth/realms/test" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

# Get a token from the real issuer
REAL_TOKEN=$(curl -s -X POST "$KC_URL/auth/realms/$KC_REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$KC_CLIENT_ID" \
  -d "client_secret=$KC_CLIENT_SECRET" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

# Test that the token is rejected due to wrong issuer (401 or 403 are both valid)
if ! retry_test_after_plugin_change "Wrong issuer rejection test" "401|403" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $REAL_TOKEN\" -o /dev/null"; then
  exit 1
fi

# Test 5: Test OPTIONS request (should be allowed by default)
echo "🔍 Testing OPTIONS preflight request..."

# First restore the correct plugin configuration
curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "config.run_on_preflight=false" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

# Test OPTIONS request (should be allowed without authentication)
if ! retry_test_after_plugin_change "OPTIONS preflight request test" "200|204" "curl -s -w \"%{http_code}\" -X OPTIONS $KONG_PROXY_URL/example/get -o /dev/null"; then
  exit 1
fi

# Restore original plugin configuration
curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "config.consumer_match_claim_custom_id=true" \
  --data "config.consumer_match=true" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

echo "✅ All error condition tests passed"