#!/bin/bash
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# Test error conditions and edge cases
echo "🧪 Testing error conditions and edge cases..."

# Test 1: Request without token should return 401
echo "🔍 Testing request without token..."
NO_TOKEN_RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get -o /dev/null)

if [ "$NO_TOKEN_RESPONSE" != "401" ]; then
  echo "❌ Expected 401 for request without token, got: $NO_TOKEN_RESPONSE"
  exit 1
fi
echo "✅ Request without token correctly returns 401"

# Test 2: Request with invalid token should return 401
echo "🔍 Testing request with invalid token..."
INVALID_TOKEN_RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get \
  -H "Authorization: Bearer invalid.token.here" -o /dev/null)

if [ "$INVALID_TOKEN_RESPONSE" != "401" ]; then
  echo "❌ Expected 401 for invalid token, got: $INVALID_TOKEN_RESPONSE"
  exit 1
fi
echo "✅ Request with invalid token correctly returns 401"

# Test 3: Request with expired token
echo "🔍 Testing request with malformed token..."
MALFORMED_TOKEN_RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get \
  -H "Authorization: Bearer not-a-jwt-token" -o /dev/null)

if [ "$MALFORMED_TOKEN_RESPONSE" != "401" ]; then
  echo "❌ Expected 401 for malformed token, got: $MALFORMED_TOKEN_RESPONSE"
  exit 1
fi
echo "✅ Request with malformed token correctly returns 401"

# Test 4: Test with wrong issuer
echo "🔍 Testing wrong issuer rejection..."

# Create a temporary plugin with different allowed issuer
curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=https://wrong-issuer.example.com/auth/realms/test" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

# Wait for Kong cache to update
sleep 5

# Get a token from the real issuer
REAL_TOKEN=$(curl -s -X POST "$KC_URL/auth/realms/$KC_REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$KC_CLIENT_ID" \
  -d "client_secret=$KC_CLIENT_SECRET" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

# Test that the token is rejected due to wrong issuer
WRONG_ISSUER_RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get \
  -H "Authorization: Bearer $REAL_TOKEN" -o /dev/null)

# 401 or 403 are both valid for wrong issuer (depends on where validation fails)
if [ "$WRONG_ISSUER_RESPONSE" != "401" ] && [ "$WRONG_ISSUER_RESPONSE" != "403" ]; then
  echo "❌ Expected 401 or 403 for wrong issuer, got: $WRONG_ISSUER_RESPONSE"
  exit 1
fi
echo "✅ Wrong issuer correctly rejected (HTTP $WRONG_ISSUER_RESPONSE)"

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

sleep 5

OPTIONS_RESPONSE=$(curl -s -w "%{http_code}" -X OPTIONS $KONG_PROXY_URL/example/get -o /dev/null)

if [ "$OPTIONS_RESPONSE" = "200" ] || [ "$OPTIONS_RESPONSE" = "204" ]; then
  echo "✅ OPTIONS preflight request correctly allowed (HTTP $OPTIONS_RESPONSE)"
else
  echo "❌ Expected 200/204 for OPTIONS request, got: $OPTIONS_RESPONSE"
  echo "❌ OPTIONS requests should be allowed without authentication by default"
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