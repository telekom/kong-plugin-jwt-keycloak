#!/bin/sh
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# This script configures Keycloak for JWT authentication with Kong
# Every config call is made to the Keycloak admin API with the admin user (admin) and password (admin)

# Create a default realm if it doesn't exist
# Authenticate as admin-cli to get an access token
KC_TOKEN=$(curl -s -X POST "$KC_URL/auth/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r .access_token)

if ! curl -s -o /dev/null -w '%{http_code}' -X GET "$KC_URL/auth/admin/realms/$KC_REALM" \
  -H "Authorization: Bearer $KC_TOKEN" | grep -q "200"; then
  echo "Creating realm: $KC_REALM"
  curl -s -X POST "$KC_URL/auth/admin/realms" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $KC_TOKEN" \
    -d "{\"realm\":\"$KC_REALM\",\"enabled\":true, \"defaultSignatureAlgorithm\": \"$KC_SIGNING_KEY_ALGORITHM\"}"
else
  echo "Realm $KC_REALM already exists."
fi

# Display realm information and the configured signing algorithm
curl -s -X GET "$KC_URL/auth/admin/realms/$KC_REALM" \
  -H "Authorization: Bearer $KC_TOKEN" | jq '. | {realm: .realm, enabled: .enabled, defaultSignatureAlgorithm: .defaultSignatureAlgorithm}'


# Create a test user if it doesn't exist with OAuth2 client credentials flow enabled and now frontend login
if [ -z "$KC_CLIENT_ID" ]; then
  echo "KC_CLIENT_ID is not set. Please set it to the desired client ID."
  exit 1
fi

# Check if the test user exists
if ! curl -s -o /dev/null -w '%{http_code}' -X GET -H "Authorization: Bearer $KC_TOKEN" "$KC_URL/auth/admin/realms/$KC_REALM/users?username=$KC_CLIENT_ID" | grep -q "200"; then
  echo "Creating test user: $KC_CLIENT_ID"
  curl -s -X POST "$KC_URL/auth/admin/realms/$KC_REALM/users" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $KC_TOKEN" \
    -d "{\"username\":\"$KC_CLIENT_ID\",\"enabled\":true}"
fi

# Create a client for the test user if it doesn't exist (i.e., returned array is empty)
if curl -s -o /dev/null -X GET -H "Authorization: Bearer $KC_TOKEN" "$KC_URL/auth/admin/realms/$KC_REALM/clients?clientId=$KC_CLIENT_ID" | jq 'length > 0' ; then
  # delete the client if it exists to avoid conflicts
  echo "Client $KC_CLIENT_ID already exists, deleting it first."

  KC_CLIENT_UUID=$(curl -s -X GET -H "Authorization: Bearer $KC_TOKEN" "$KC_URL/auth/admin/realms/$KC_REALM/clients?clientId=$KC_CLIENT_ID" | jq -r '.[0].id')

  curl -s -X DELETE "$KC_URL/auth/admin/realms/$KC_REALM/clients/$KC_CLIENT_UUID" \
    -H "Authorization: Bearer $KC_TOKEN" \
    -H "Content-Type: application/json"
fi

# Create a new client for the test user
echo "Creating client: $KC_CLIENT_ID in realm: $KC_REALM"

# Create the client with the specified attributes
curl -s -X POST "$KC_URL/auth/admin/realms/$KC_REALM/clients" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KC_TOKEN" \
  -d "{\"clientId\":\"$KC_CLIENT_ID\",\"enabled\":true,\"publicClient\":false,\"secret\":\"$KC_CLIENT_SECRET\",\"redirectUris\":[\"http://localhost:8000/*\"],\"protocol\":\"openid-connect\",\"serviceAccountsEnabled\":true,\"attributes\":{\"access.token.signed.response.alg\":\"$KC_SIGNING_KEY_ALGORITHM\",\"access.token.jwt.claims\":\"true\"}}"

# Display the client information
curl -s -X GET "$KC_URL/auth/admin/realms/$KC_REALM/clients?clientId=$KC_CLIENT_ID" \
  -H "Authorization: Bearer $KC_TOKEN" | jq '.[] | {clientId: .clientId, id: .id, secret: .secret, attributes: .attributes}'
