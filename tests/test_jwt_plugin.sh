#!/bin/bash

KONG_PROXY_URL="http://kong:8000"
KC_ISSUER_URL="http://kc:8080/auth/realms/default"
KC_CLIENT_ID="test-user"
TOKEN_ENDPOINT="$KC_ISSUER_URL/protocol/openid-connect/token"
CLIENT_ID="test-user"
CLIENT_SECRET=""

ACCESS_TOKEN=$(curl -s -X POST $TOKEN_ENDPOINT \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

# Make a request to the service with the access token
RESPONSE=$(curl -s -v -X GET $KONG_PROXY_URL/example/get \
  -H "Authorization: Bearer $ACCESS_TOKEN")

echo "Response:"
echo "$RESPONSE"
