#!/bin/bash
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

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

sleep 5

# Test that request with valid scope passes
SCOPE_VALID_RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get \
  -H "Authorization: Bearer $ACCESS_TOKEN" -o /dev/null)

if [ "$SCOPE_VALID_RESPONSE" != "200" ]; then
  echo "❌ Expected 200 for valid scope, got: $SCOPE_VALID_RESPONSE"
  exit 1
fi
echo "✅ Valid scope test passed"

# Test 2: Scope validation - require non-existing scope
echo "🔍 Testing scope validation with non-existing scope..."

curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "config.scope[]=admin" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

sleep 5

# Test that request with invalid scope is rejected
SCOPE_INVALID_RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get \
  -H "Authorization: Bearer $ACCESS_TOKEN" -o /dev/null)

if [ "$SCOPE_INVALID_RESPONSE" != "403" ]; then
  echo "❌ Expected 403 for invalid scope, got: $SCOPE_INVALID_RESPONSE"
  exit 1
fi
echo "✅ Invalid scope rejection test passed"

# Test 3: Realm role validation - require existing realm role
echo "🔍 Testing realm role validation with existing role..."

curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "config.realm_roles[]=offline_access" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

sleep 5

# Test that request with valid realm role passes
REALM_ROLE_VALID_RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get \
  -H "Authorization: Bearer $ACCESS_TOKEN" -o /dev/null)

if [ "$REALM_ROLE_VALID_RESPONSE" != "200" ]; then
  echo "❌ Expected 200 for valid realm role, got: $REALM_ROLE_VALID_RESPONSE"
  exit 1
fi
echo "✅ Valid realm role test passed"

# Test 4: Realm role validation - require non-existing realm role
echo "🔍 Testing realm role validation with non-existing role..."

curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "config.realm_roles[]=super-admin" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

sleep 5

# Test that request with invalid realm role is rejected
REALM_ROLE_INVALID_RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get \
  -H "Authorization: Bearer $ACCESS_TOKEN" -o /dev/null)

if [ "$REALM_ROLE_INVALID_RESPONSE" != "403" ]; then
  echo "❌ Expected 403 for invalid realm role, got: $REALM_ROLE_INVALID_RESPONSE"
  exit 1
fi
echo "✅ Invalid realm role rejection test passed"

# Test 5: Client role validation - require existing client role
echo "🔍 Testing client role validation with existing role..."

curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "config.client_roles[]=account:manage-account" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

sleep 5

# Test that request with valid client role passes
CLIENT_ROLE_VALID_RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get \
  -H "Authorization: Bearer $ACCESS_TOKEN" -o /dev/null)

if [ "$CLIENT_ROLE_VALID_RESPONSE" != "200" ]; then
  echo "❌ Expected 200 for valid client role, got: $CLIENT_ROLE_VALID_RESPONSE"
  exit 1
fi
echo "✅ Valid client role test passed"

# Test 6: Client role validation - require non-existing client role
echo "🔍 Testing client role validation with non-existing role..."

curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.algorithm=$KC_SIGNING_KEY_ALGORITHM" \
  --data "config.client_roles[]=account:super-admin" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')" > /dev/null

sleep 5

# Test that request with invalid client role is rejected
CLIENT_ROLE_INVALID_RESPONSE=$(curl -s -w "%{http_code}" -X GET $KONG_PROXY_URL/example/get \
  -H "Authorization: Bearer $ACCESS_TOKEN" -o /dev/null)

if [ "$CLIENT_ROLE_INVALID_RESPONSE" != "403" ]; then
  echo "❌ Expected 403 for invalid client role, got: $CLIENT_ROLE_INVALID_RESPONSE"
  exit 1
fi
echo "✅ Invalid client role rejection test passed"

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