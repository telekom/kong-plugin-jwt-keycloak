#!/bin/bash
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# Test network connectivity to services

echo "🔍 Testing network connectivity..."

# Source environment helpers
if [ -f ./_env.sh ]; then
    . ./_env.sh
fi

# Test DNS resolution
echo "📡 Testing DNS resolution..."

echo -n "  - Resolving 'kong': "
if nslookup kong > /dev/null 2>&1 || getent hosts kong > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ FAILED"
    echo "    Error: Cannot resolve hostname 'kong'"
fi

echo -n "  - Resolving 'kc': "
if nslookup kc > /dev/null 2>&1 || getent hosts kc > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ FAILED"
    echo "    Error: Cannot resolve hostname 'kc'"
fi

echo -n "  - Resolving 'httpbin': "
if nslookup httpbin > /dev/null 2>&1 || getent hosts httpbin > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ FAILED"
    echo "    Error: Cannot resolve hostname 'httpbin'"
fi

echo ""
echo "✅ Network connectivity check complete"
