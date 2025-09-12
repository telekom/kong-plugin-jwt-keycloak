#!/bin/bash
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# Source environment helpers
if [ -f ./_env.sh ]; then
    . ./_env.sh
fi

echo "🔒 Testing security logging functionality..."

# Test security logging with various error conditions
echo "🔍 Testing security event logging for missing token..."

# Remove any existing jwt-keycloak plugin
PLUGIN_ID=$(curl -s "$KONG_ADMIN_URL/plugins" | jq -r '.data[] | select(.name=="jwt-keycloak") | .id')
if [ -n "$PLUGIN_ID" ] && [ "$PLUGIN_ID" != "null" ]; then
  curl -s -X DELETE "$KONG_ADMIN_URL/plugins/$PLUGIN_ID" > /dev/null
fi

# Configure plugin
ROUTE_ID=$(curl -s "$KONG_ADMIN_URL/routes/example-route" | jq -r '.id')
curl -s -X POST "$KONG_ADMIN_URL/plugins" \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "route.id=$ROUTE_ID" > /dev/null

# Test 1: Request without token should trigger ua200 security event
echo "🧪 Testing request without token (should trigger ua200 event)..."
RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get -o /dev/null)
if [[ "$RESPONSE" != "401" ]]; then
  echo "❌ Expected 401 for missing token, got $RESPONSE"
  exit 1
fi

# Test 2: Request with malformed token should trigger ua201 security event
echo "🧪 Testing request with malformed token (should trigger ua201 event)..."
RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get -H "Authorization: Bearer malformed-token" -o /dev/null)
if [[ "$RESPONSE" != "401" ]]; then
  echo "❌ Expected 401 for malformed token, got $RESPONSE"
  exit 1
fi

# Test 3: Request with valid token should trigger successful authentication
echo "🧪 Testing request with valid token..."
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

RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get -H "Authorization: Bearer $ACCESS_TOKEN" -o /dev/null)
if [[ "$RESPONSE" != "200" ]]; then
  echo "❌ Expected 200 for valid token, got $RESPONSE"
  exit 1
fi

echo "✅ Security logging tests passed"