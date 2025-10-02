#!/bin/bash

# =============================================================================
# API GATEWAY TESTING SCRIPT
# =============================================================================
# This script tests all API Gateway endpoints and demonstrates usage
# Run this after successful deployment to verify everything works

set -e

echo "🧪 API Gateway Testing Script"
echo "============================="

# Get API Gateway information from Terraform outputs
echo "📊 Getting API Gateway information..."

API_GATEWAY_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
CUSTOM_API_URL=$(terraform output -raw api_gateway_custom_domain 2>/dev/null || echo "")
API_KEY=$(terraform output -raw api_key 2>/dev/null || echo "")
ALB_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null || echo "")

if [ -z "$API_GATEWAY_URL" ]; then
    echo "❌ Could not get API Gateway URL from Terraform outputs"
    echo "   Make sure you've deployed the infrastructure with 'terraform apply'"
    exit 1
fi

echo "🌐 API Gateway URL: $API_GATEWAY_URL"
echo "🔗 Custom Domain: $CUSTOM_API_URL"
echo "🔑 API Key: ${API_KEY:0:10}..."
echo "⚖️  ALB DNS: $ALB_DNS"
echo ""

# Function to make API calls with proper error handling
make_api_call() {
    local method=$1
    local endpoint=$2
    local headers=$3
    local data=$4
    local description=$5
    
    echo "🔍 Testing: $description"
    echo "   Method: $method"
    echo "   Endpoint: $endpoint"
    
    if [ -n "$data" ]; then
        echo "   Data: $data"
    fi
    
    echo "   Response:"
    
    # Make the API call
    if [ -n "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$endpoint" $headers -d "$data" 2>/dev/null || echo "000")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$endpoint" $headers 2>/dev/null || echo "000")
    fi
    
    # Extract HTTP status code (last line)
    http_code=$(echo "$response" | tail -n1)
    # Extract response body (all but last line)
    response_body=$(echo "$response" | head -n -1)
    
    # Pretty print JSON if possible
    if echo "$response_body" | jq . >/dev/null 2>&1; then
        echo "$response_body" | jq .
    else
        echo "$response_body"
    fi
    
    # Check status code
    if [[ "$http_code" =~ ^[23] ]]; then
        echo "   ✅ Status: $http_code (Success)"
    else
        echo "   ❌ Status: $http_code (Error)"
    fi
    
    echo ""
}

# =============================================================================
# TEST 1: HEALTH CHECK (No Authentication Required)
# =============================================================================
echo "🏥 TEST 1: Health Check Endpoint"
echo "================================"

make_api_call "GET" "$API_GATEWAY_URL/health" "" "" "Health check via API Gateway"

# Also test direct ALB access for comparison
if [ -n "$ALB_DNS" ]; then
    echo "🔄 Comparing with direct ALB access:"
    make_api_call "GET" "https://$ALB_DNS/health" "" "" "Health check via ALB (direct)"
fi

# =============================================================================
# TEST 2: ROOT ENDPOINT
# =============================================================================
echo "🏠 TEST 2: Root Endpoint"
echo "======================="

make_api_call "GET" "$API_GATEWAY_URL/" "" "" "Root endpoint welcome message"

# =============================================================================
# TEST 3: GET USERS (Requires API Key)
# =============================================================================
echo "👥 TEST 3: Get Users Endpoint"
echo "============================"

if [ -n "$API_KEY" ]; then
    make_api_call "GET" "$API_GATEWAY_URL/v1/users" "-H 'x-api-key: $API_KEY'" "" "Get all users with API key"
    
    # Test with pagination parameters
    make_api_call "GET" "$API_GATEWAY_URL/v1/users?page=0&size=5" "-H 'x-api-key: $API_KEY'" "" "Get users with pagination"
else
    echo "⚠️  Skipping authenticated endpoints - API key not available"
fi

# =============================================================================
# TEST 4: CREATE USER (Requires API Key)
# =============================================================================
echo "➕ TEST 4: Create User Endpoint"
echo "=============================="

if [ -n "$API_KEY" ]; then
    user_data='{
        "name": "John Doe",
        "email": "john.doe@example.com",
        "age": 30
    }'
    
    make_api_call "POST" "$API_GATEWAY_URL/v1/users" \
        "-H 'Content-Type: application/json' -H 'x-api-key: $API_KEY'" \
        "$user_data" \
        "Create new user"
    
    # Test with invalid data
    invalid_data='{"name": "Jane"}'  # Missing required email field
    
    make_api_call "POST" "$API_GATEWAY_URL/v1/users" \
        "-H 'Content-Type: application/json' -H 'x-api-key: $API_KEY'" \
        "$invalid_data" \
        "Create user with invalid data (should fail)"
else
    echo "⚠️  Skipping authenticated endpoints - API key not available"
fi

# =============================================================================
# TEST 5: GET USER BY ID (Requires API Key)
# =============================================================================
echo "🔍 TEST 5: Get User by ID Endpoint"
echo "================================="

if [ -n "$API_KEY" ]; then
    make_api_call "GET" "$API_GATEWAY_URL/v1/users/1" "-H 'x-api-key: $API_KEY'" "" "Get user by ID (valid)"
    
    # Test with invalid ID
    make_api_call "GET" "$API_GATEWAY_URL/v1/users/9999" "-H 'x-api-key: $API_KEY'" "" "Get user by ID (invalid - should return 404)"
else
    echo "⚠️  Skipping authenticated endpoints - API key not available"
fi

# =============================================================================
# TEST 6: AUTHENTICATION TESTS
# =============================================================================
echo "🔐 TEST 6: Authentication Tests"
echo "==============================="

# Test without API key (should fail)
make_api_call "GET" "$API_GATEWAY_URL/v1/users" "" "" "Get users without API key (should fail)"

# Test with invalid API key (should fail)
make_api_call "GET" "$API_GATEWAY_URL/v1/users" "-H 'x-api-key: invalid-key-12345'" "" "Get users with invalid API key (should fail)"

# =============================================================================
# TEST 7: RATE LIMITING TEST
# =============================================================================
echo "⚡ TEST 7: Rate Limiting Test"
echo "============================"

echo "🔄 Making multiple rapid requests to test rate limiting..."
echo "   (API Gateway is configured for 1000 req/sec, so this should succeed)"

for i in {1..5}; do
    echo "   Request $i/5:"
    response=$(curl -s -w "%{http_code}" -X GET "$API_GATEWAY_URL/health" 2>/dev/null)
    http_code="${response: -3}"
    
    if [[ "$http_code" =~ ^[23] ]]; then
        echo "   ✅ Request $i: $http_code"
    else
        echo "   ❌ Request $i: $http_code (Rate limited or error)"
    fi
done

echo ""

# =============================================================================
# TEST 8: CUSTOM DOMAIN TEST (if available)
# =============================================================================
if [ -n "$CUSTOM_API_URL" ] && [ "$CUSTOM_API_URL" != "null" ]; then
    echo "🌐 TEST 8: Custom Domain Test"
    echo "============================"
    
    make_api_call "GET" "$CUSTOM_API_URL/health" "" "" "Health check via custom domain"
else
    echo "⚠️  TEST 8: Custom Domain Test - Skipped (custom domain not configured)"
fi

# =============================================================================
# TEST 9: DIRECT APPLICATION ENDPOINTS (via ALB)
# =============================================================================
if [ -n "$ALB_DNS" ]; then
    echo "🔗 TEST 9: Direct Application Endpoints (via ALB)"
    echo "================================================"
    
    make_api_call "GET" "https://$ALB_DNS/api/system" "" "" "System information endpoint"
    make_api_call "GET" "https://$ALB_DNS/api/metrics" "" "" "Application metrics endpoint"
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo "📊 TEST SUMMARY"
echo "==============="
echo ""
echo "✅ Completed API Gateway testing"
echo ""
echo "🔗 Available Endpoints:"
echo "   • Health Check: $API_GATEWAY_URL/health"
echo "   • Root: $API_GATEWAY_URL/"
echo "   • Users (GET): $API_GATEWAY_URL/v1/users"
echo "   • Users (POST): $API_GATEWAY_URL/v1/users"
echo "   • User by ID: $API_GATEWAY_URL/v1/users/{id}"
echo ""

if [ -n "$CUSTOM_API_URL" ] && [ "$CUSTOM_API_URL" != "null" ]; then
    echo "🌐 Custom Domain: $CUSTOM_API_URL"
fi

if [ -n "$ALB_DNS" ]; then
    echo "⚖️  Direct ALB Access: https://$ALB_DNS"
fi

echo ""
echo "🔑 API Key (for authenticated endpoints): $API_KEY"
echo ""
echo "📚 Usage Examples:"
echo ""
echo "# Health check (no auth required)"
echo "curl -X GET '$API_GATEWAY_URL/health'"
echo ""
echo "# Get users (requires API key)"
echo "curl -X GET '$API_GATEWAY_URL/v1/users' \\"
echo "  -H 'x-api-key: $API_KEY'"
echo ""
echo "# Create user (requires API key)"
echo "curl -X POST '$API_GATEWAY_URL/v1/users' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -H 'x-api-key: $API_KEY' \\"
echo "  -d '{\"name\": \"John Doe\", \"email\": \"john@example.com\", \"age\": 30}'"
echo ""
echo "🎉 Testing completed!"
