#!/bin/sh
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0


# Set the environment variables for the tests
prepare_environment() {
  export KONG_ADMIN_URL=http://kong:8001
  export KONG_PROXY_URL=http://kong:8000
  export KC_URL=http://kc:8080
  export KC_CLIENT_ID=test-user
  export KC_CLIENT_SECRET=$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32)
  export KC_SIGNING_KEY_ALGORITHM=ES256
  export KC_REALM=default
}

# wait for kong to be ready or timeout
wait_for_kong() {
  echo "Waiting for Kong to be ready..."
  for i in $(seq 1 30); do
    if curl -s -o /dev/null $KONG_ADMIN_URL; then
      echo "Kong is ready!"
      return 0
    fi
    sleep 1
  done
  echo "Kong is not ready after 30 seconds, exiting..."
  exit 1
}

# wait for Keycloak to be ready or timeout
wait_for_keycloak() {
  echo "Waiting for Keycloak to be ready..."
  for i in $(seq 1 30); do
    if test $(curl -s -o /dev/null -w '%{http_code}' $KC_URL/auth/realms/master/.well-known/openid-configuration) -eq 200; then
      echo "Keycloak endpoint is ready!"
      return 0
    fi
    sleep 1
  done
  echo "Keycloak is not ready after 30 seconds, exiting..."
  exit 1
}

# Helper function to retry tests after plugin reconfiguration
# Usage: retry_test_after_plugin_change "test description" "expected_status" "curl_command"
# Usage: retry_test_after_plugin_change "test description" "expected_status1|expected_status2" "curl_command"
retry_test_after_plugin_change() {
  local test_description="$1"
  local expected_statuses="$2"
  local curl_command="$3"
  local retries=3
  local wait_time=3
  local attempt=1
  
  # Initial waiting period before test runs
  echo "⏳ Initial waiting period before test (${wait_time}s)..."
  sleep $wait_time
  
  echo "🔄 Testing: $test_description"
  
  while [ $attempt -le $retries ]; do
    echo "   Attempt $attempt/$retries..."
    
    local actual_status=$(eval "$curl_command")
    
    # Check if actual status matches any of the expected statuses
    if echo "$expected_statuses" | grep -q "$actual_status"; then
      echo "✅ $test_description passed (HTTP $actual_status)"
      return 0
    fi
    
    if [ $attempt -lt $retries ]; then
      echo "⚠️  Expected one of [$expected_statuses], got $actual_status. Waiting ${wait_time}s before retry..."
      sleep $wait_time
      attempt=$((attempt + 1))
    else
      echo "❌ $test_description failed after $retries attempts. Expected one of [$expected_statuses], got $actual_status"
      return 1
    fi
  done
}