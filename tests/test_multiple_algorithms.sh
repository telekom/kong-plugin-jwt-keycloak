#!/bin/bash
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# Source environment helpers
if [ -f ./_env.sh ]; then
    . ./_env.sh
fi

# Test multiple algorithm support
# This test verifies that the plugin can accept tokens signed with different algorithms
# when multiple algorithms are configured

echo "🧪 Testing multiple algorithm support..."

# Get tokens from Keycloak (currently configured with ES256)
TOKEN_ENDPOINT="$KC_URL/auth/realms/$KC_REALM/protocol/openid-connect/token"

ES256_TOKEN=$(curl -s -X POST $TOKEN_ENDPOINT \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$KC_CLIENT_ID" \
  -d "client_secret=$KC_CLIENT_SECRET" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

if [ -z "$ES256_TOKEN" ] || [ "$ES256_TOKEN" = "null" ]; then
  echo "❌ Failed to obtain ES256 access token"
  exit 1
fi

echo "✅ Obtained ES256 token from Keycloak"

# Test 1: Configure plugin with multiple algorithms including ES256
echo ""
echo "📝 Test 1: Plugin accepts token when algorithm is in the allowed list"
echo "----------------------------------------------------------------------"

# Delete existing plugin
curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

# Create plugin with multiple algorithms
MULTI_ALG_PLUGIN=$(curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm[]=RS256" \
  --data "config.algorithm[]=RS384" \
  --data "config.algorithm[]=ES256" \
  --data "config.algorithm[]=ES384" \
  --data "config.consumer_match_claim_custom_id=true" \
  --data "config.consumer_match=true" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')")

echo "Plugin configured with algorithms: $(echo $MULTI_ALG_PLUGIN | jq '.config.algorithm')"

# Test that ES256 token is accepted
if ! retry_test_after_plugin_change "ES256 token with multiple algorithms" "200" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $ES256_TOKEN\" -o /dev/null"; then
  exit 1
fi

echo "✅ Token accepted when its algorithm (ES256) is in the allowed list"

# Test 2: Configure plugin WITHOUT ES256 to verify rejection
echo ""
echo "📝 Test 2: Plugin rejects token when algorithm is NOT in the allowed list"
echo "--------------------------------------------------------------------------"

# Delete existing plugin
curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

# Create plugin with only RS algorithms (not ES256)
RS_ONLY_PLUGIN=$(curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm[]=RS256" \
  --data "config.algorithm[]=RS384" \
  --data "config.algorithm[]=RS512" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')")

echo "Plugin configured with algorithms: $(echo $RS_ONLY_PLUGIN | jq '.config.algorithm')"

# Test that ES256 token is rejected
if ! retry_test_after_plugin_change "ES256 token rejection with RS-only config" "401" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $ES256_TOKEN\" -o /dev/null"; then
  exit 1
fi

echo "✅ Token rejected when its algorithm (ES256) is not in the allowed list"

# Test 3: Single algorithm (backward compatibility)
echo ""
echo "📝 Test 3: Single algorithm configuration (backward compatibility)"
echo "------------------------------------------------------------------"

# Delete existing plugin
curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

# Create plugin with single algorithm (old style)
SINGLE_ALG_PLUGIN=$(curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=ES256" \
  --data "config.consumer_match_claim_custom_id=true" \
  --data "config.consumer_match=true" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')")

echo "Plugin configured with algorithm: $(echo $SINGLE_ALG_PLUGIN | jq '.config.algorithm')"

# Test that ES256 token is accepted with single algorithm config
if ! retry_test_after_plugin_change "ES256 token with single algorithm config" "200" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $ES256_TOKEN\" -o /dev/null"; then
  exit 1
fi

echo "✅ Single algorithm configuration works (backward compatible)"

# Test 4: Default algorithm (no algorithm specified)
echo ""
echo "📝 Test 4: Default algorithm configuration"
echo "-------------------------------------------"

# Delete existing plugin
curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

# Create plugin without specifying algorithm (should default to RS256)
DEFAULT_ALG_PLUGIN=$(curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')")

echo "Plugin configured with default algorithm: $(echo $DEFAULT_ALG_PLUGIN | jq '.config.algorithm')"

# Test that ES256 token is rejected (default is RS256)
if ! retry_test_after_plugin_change "ES256 token rejection with default RS256 config" "401" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $ES256_TOKEN\" -o /dev/null"; then
  exit 1
fi

echo "✅ Default algorithm (RS256) works correctly"

# Restore original plugin configuration
echo ""
echo "🔄 Restoring original plugin configuration..."
curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "config.consumer_match_claim_custom_id=true" \
  --data "config.consumer_match=true" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

echo ""
echo "✅ All multiple algorithm tests passed!"
