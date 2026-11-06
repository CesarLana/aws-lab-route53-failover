#!/bin/bash
# ==============================================================================
# AWS Lab: Route 53 Active-Passive Failover
# Script: scripts/health_check_setup.sh
# Purpose: Create Route 53 HTTP Health Check with 10-second fast interval
#          and link it with CloudWatch Alarms & SNS.
# ==============================================================================

set -euo pipefail

PRIMARY_IP=${1:-""}
SNS_TOPIC_ARN=${2:-""}

if [[ -z "$PRIMARY_IP" ]]; then
  echo "Usage: $0 <PRIMARY_PUBLIC_IP> [SNS_TOPIC_ARN]"
  echo "Example: $0 54.210.10.20 arn:aws:sns:us-east-1:123456789012:route53-failover-alerts"
  exit 1
fi

CALLER_REFERENCE="health-check-primary-$(date +%s)"

echo "[+] Creating Route 53 HTTP Health Check for $PRIMARY_IP..."

HEALTH_CHECK_CONFIG=$(cat <<EOF
{
  "IPAddress": "$PRIMARY_IP",
  "Port": 80,
  "Type": "HTTP",
  "ResourcePath": "/healthz",
  "RequestInterval": 10,
  "FailureThreshold": 3,
  "MeasureLatency": true,
  "Inverted": false,
  "Disabled": false,
  "EnableSNI": false
}
EOF
)

HEALTH_CHECK_RES=$(aws route53 create-health-check \
  --caller-reference "$CALLER_REFERENCE" \
  --health-check-config "$HEALTH_CHECK_CONFIG")

HEALTH_CHECK_ID=$(echo "$HEALTH_CHECK_RES" | grep -o '"Id": "[^"]*' | head -1 | cut -d'"' -f4)

echo "[✓] Health Check Created Successfully!"
echo "    Health Check ID: $HEALTH_CHECK_ID"
echo "    Interval: 10s (Fast Interval)"
echo "    Failure Threshold: 3 consecutive failures (~30s detection window)"

# Tag the health check
aws route53 change-tags-for-resource \
  --resource-type healthcheck \
  --resource-id "$HEALTH_CHECK_ID" \
  --add-tags Key=Name,Value="Primary-Endpoint-HealthCheck"

if [[ -n "$SNS_TOPIC_ARN" ]]; then
  echo "[+] Linking CloudWatch Alarm to Health Check: $HEALTH_CHECK_ID..."

  aws cloudwatch put-metric-alarm \
    --alarm-name "Route53-Primary-Unhealthy-Alarm" \
    --alarm-description "Triggers when Primary Route 53 endpoint fails health checks" \
    --namespace "AWS/Route53" \
    --metric-name "HealthCheckStatus" \
    --dimensions Name=HealthCheckId,Value="$HEALTH_CHECK_ID" \
    --period 60 \
    --evaluation-periods 1 \
    --threshold 1 \
    --comparison-operator LessThanThreshold \
    --statistic Minimum \
    --alarm-actions "$SNS_TOPIC_ARN" \
    --ok-actions "$SNS_TOPIC_ARN"

  echo "[✓] CloudWatch Alarm created and attached to SNS topic!"
fi

echo "=========================================================="
echo "HealthCheck ID to use in Route 53 Record Set: $HEALTH_CHECK_ID"
echo "=========================================================="
