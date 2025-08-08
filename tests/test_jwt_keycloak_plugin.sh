#!/bin/bash
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG

# SPDX-License-Identifier: Apache-2.0

# Source environment helpers
if [ -f ./_env.sh ]; then
    . ./_env.sh
fi

TOKEN_ENDPOINT="$KC_URL/auth/realms/$KC_REALM/protocol/openid-connect/token"

ACCESS_TOKEN=$(curl -s -X POST $TOKEN_ENDPOINT \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$KC_CLIENT_ID" \
  -d "client_secret=$KC_CLIENT_SECRET" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

# Make a request to the service with the access token
if [ -z "$ACCESS_TOKEN" ]; then
  echo "Failed to obtain access token"
  exit 1
fi

# Test the JWT token with retry mechanism
echo "🧪 Testing JWT token validation..."
if ! retry_test_after_plugin_change "JWT token validation test" "200" "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $ACCESS_TOKEN\" -o /dev/null"; then
  exit 1
fi

# Get the full response for debugging/verification
RESPONSE=$(curl -s -X GET $KONG_PROXY_URL/example/get \
  -H "Authorization: Bearer $ACCESS_TOKEN")

echo "Response:"
echo "$RESPONSE"
