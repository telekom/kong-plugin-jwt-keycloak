#!/bin/bash
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# configure Kong consumers and group with the same name
curl -i -X POST $KONG_ADMIN_URL/consumers \
  --data "username=test-user" \
  --data "custom_id=test-user" \

# Configure example service to httpbin.org, route and acl with jwt-keycloak plugin
curl -i -X POST $KONG_ADMIN_URL/services \
  --data "name=example-service" \
  --data "url=http://httpbin:8080" \

curl -i -X POST $KONG_ADMIN_URL/routes \
  --data "paths[]=/example" \
  --data "service.id=$(curl -s $KONG_ADMIN_URL/services/example-service | jq -r '.id')" \
  --data "name=example-route" \
  --data "protocols[]=http" \
  --data "protocols[]=https"

curl -i -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="acl") | .id')

curl -i -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id')

curl -i -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.consumer_match_claim_custom_id=true" \
  --data "config.consumer_match=true" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')"
