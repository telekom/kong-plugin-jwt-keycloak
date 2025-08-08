#!/bin/bash
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# Source environment helpers
if [ -f ./_env.sh ]; then
    . ./_env.sh
fi

# Test role and scope validation
echo "🧪 Testing role and scope validation..."

# Get a valid token for testing
TOKEN_ENDPOINT="$KC_URL/auth/realms/$KC_REALM/protocol/openid-connect/token"
ACCESS_TOKEN=$(curl -s -X POST $TOKEN_ENDPOINT \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$KC_CLIENT_ID" \
  -d "client_secret=$KC_CLIENT_SECRET" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "❌ Failed to obtain access token for role/scope testing"
  exit 1
fi

# Test 1: Scope validation - require existing scope
echo "🔍 Testing scope validation with existing scope..."

# Create plugin with scope requirement
curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "config.scope[]=profile" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

# Test that request with valid scope passes
if ! retry_test_after_plugin_change "Valid scope test" "200" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $ACCESS_TOKEN\" -o /dev/null"; then
  exit 1
fi

# Test 2: Scope validation - require non-existing scope
echo "🔍 Testing scope validation with non-existing scope..."

curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "config.scope[]=admin" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

# Test that request with invalid scope is rejected
if ! retry_test_after_plugin_change "Invalid scope rejection test" "403" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $ACCESS_TOKEN\" -o /dev/null"; then
  exit 1
fi

# Test 3: Realm role validation - require existing realm role
echo "🔍 Testing realm role validation with existing role..."

curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "config.realm_roles[]=offline_access" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

# Test that request with valid realm role passes
if ! retry_test_after_plugin_change "Valid realm role test" "200" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $ACCESS_TOKEN\" -o /dev/null"; then
  exit 1
fi

# Test 4: Realm role validation - require non-existing realm role
echo "🔍 Testing realm role validation with non-existing role..."

curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "config.realm_roles[]=super-admin" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

# Test that request with invalid realm role is rejected
if ! retry_test_after_plugin_change "Invalid realm role rejection test" "403" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $ACCESS_TOKEN\" -o /dev/null"; then
  exit 1
fi

# Test 5: Client role validation - require existing client role
echo "🔍 Testing client role validation with existing role..."

curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "config.client_roles[]=account:manage-account" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

# Test that request with valid client role passes
if ! retry_test_after_plugin_change "Valid client role test" "200" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $ACCESS_TOKEN\" -o /dev/null"; then
  exit 1
fi

# Test 6: Client role validation - require non-existing client role
echo "🔍 Testing client role validation with non-existing role..."

curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "config.client_roles[]=account:super-admin" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

# Test that request with invalid client role is rejected
if ! retry_test_after_plugin_change "Invalid client role rejection test" "403" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $ACCESS_TOKEN\" -o /dev/null"; then
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

echo "✅ All role and scope tests passed"