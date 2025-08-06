#!/bin/sh
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# include _env.sh
. _env.sh
prepare_environment

# Wait for all services to be ready
wait_for_kong
wait_for_keycloak

# Configure Keycloak for JWT authentication
echo "🔧 Configuring Keycloak for JWT authentication..."
. configure_keycloak.sh

# Configure JWT-Keycloak plugin
echo "🔧 Configuring JWT-Keycloak plugin..."
. configure_jwt_plugin.sh

# Test 1: Test JWT-Keycloak plugin
echo "🧪 Phase 1: Testing JWT-Keycloak plugin..."
. test_jwt_keycloak_plugin.sh
