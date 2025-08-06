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