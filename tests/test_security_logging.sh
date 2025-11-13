#!/bin/bash
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# Source environment helpers
if [ -f ./_env.sh ]; then
    . ./_env.sh
fi

# Test security logging functionality
echo "🧪 Testing security logging functionality..."

# Get a valid token for testing
TOKEN_ENDPOINT="$KC_URL/auth/realms/$KC_REALM/protocol/openid-connect/token"
ACCESS_TOKEN=$(curl -s -X POST $TOKEN_ENDPOINT \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$KC_CLIENT_ID" \
  -d "client_secret=$KC_CLIENT_SECRET" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "❌ Failed to obtain access token for security logging testing"
  exit 1
fi

# Test 1: Security event logging for missing token (ua200)
echo "🔍 Testing security event logging for missing token..."

# Test that request without token triggers security event and returns 401
if ! retry_test_after_plugin_change "Missing token security event test" "401" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -o /dev/null"; then
  exit 1
fi

# Test 2: Security event logging for malformed token (ua201)
echo "🔍 Testing security event logging for malformed token..."

# Test that request with malformed token triggers security event and returns 401
if ! retry_test_after_plugin_change "Malformed token security event test" "401" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer malformed-token\" -o /dev/null"; then
  exit 1
fi

# Test 3: Valid token should work with existing plugin configuration
echo "🔍 Testing security logging with valid token..."

# Test that request with valid token passes and triggers gateway consumer collection
if ! retry_test_after_plugin_change "Valid token security logging test" "200" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $ACCESS_TOKEN\" -o /dev/null"; then
  exit 1
fi

# Test 4: Security event logging for wrong issuer (ua222)
echo "🔍 Testing security event logging for wrong issuer..."

# Create temporary plugin with wrong issuer
PLUGIN_ID=$(curl -s "$KONG_ADMIN_URL/plugins" | jq -r '.data[] | select(.name=="jwt-keycloak") | .id')
if [ -n "$PLUGIN_ID" ] && [ "$PLUGIN_ID" != "null" ]; then
  curl -s -X DELETE "$KONG_ADMIN_URL/plugins/$PLUGIN_ID" > /dev/null
fi

ROUTE_ID=$(curl -s "$KONG_ADMIN_URL/routes/example-route" | jq -r '.id')
curl -s -X POST "$KONG_ADMIN_URL/plugins" \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=https://wrong-issuer.example.com/auth/realms/test" \
  --data "route.id=$ROUTE_ID" > /dev/null

# Test that token is rejected due to wrong issuer
if ! retry_test_after_plugin_change "Wrong issuer security event test" "401|403" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $ACCESS_TOKEN\" -o /dev/null"; then
  exit 1
fi

# Restore original plugin configuration
echo "🔄 Restoring original plugin configuration..."
PLUGIN_ID=$(curl -s "$KONG_ADMIN_URL/plugins" | jq -r '.data[] | select(.name=="jwt-keycloak") | .id')
if [ -n "$PLUGIN_ID" ] && [ "$PLUGIN_ID" != "null" ]; then
  curl -s -X DELETE "$KONG_ADMIN_URL/plugins/$PLUGIN_ID" > /dev/null
fi

ROUTE_ID=$(curl -s "$KONG_ADMIN_URL/routes/example-route" | jq -r '.id')
curl -s -X POST "$KONG_ADMIN_URL/plugins" \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.consumer_match_claim_custom_id=true" \
  --data "config.consumer_match=true" \
  --data "route.id=$ROUTE_ID" > /dev/null

echo "✅ All security logging tests passed"