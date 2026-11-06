#!/bin/bash
# ==============================================================================
# AWS Lab: Route 53 Active-Passive Failover
# Script: scripts/simulate_failure.sh
# Purpose: Simulate service outage on Primary server or restore service to test failback
# ==============================================================================

ACTION=${1:-"status"}
DOMAIN_OR_IP=${2:-""}

case "$ACTION" in
  down)
    echo "[!] Simulating OUTAGE: Stopping Apache HTTP Server..."
    sudo systemctl stop httpd
    echo "[✓] Apache stopped. Route 53 health check will detect failure in ~30 seconds."
    ;;
  up)
    echo "[+] Simulating RESTORATION: Starting Apache HTTP Server..."
    sudo systemctl start httpd
    echo "[✓] Apache running. Route 53 will detect healthy state and initiate failback."
    ;;
  status)
    echo "[*] Checking local web server status:"
    sudo systemctl status httpd --no-pager
    ;;
  test-dns)
    if [[ -z "$DOMAIN_OR_IP" ]]; then
      echo "Usage: $0 test-dns <DNS_NAME>"
      exit 1
    fi
    echo "[*] Testing DNS resolution and HTTP response for: $DOMAIN_OR_IP"
    for i in {1..10}; do
      echo -n "[$(date +'%T')] "
      RESOLVED_IP=$(dig +short "$DOMAIN_OR_IP" | tail -n1 || nslookup "$DOMAIN_OR_IP" | grep Address | tail -n1 | awk '{print $2}')
      HTTP_TITLE=$(curl -s --connect-timeout 2 "http://$DOMAIN_OR_IP" | grep -o '<title>[^<]*' | cut -d'>' -f2 || echo "TIMEOUT/FAIL")
      echo "IP: $RESOLVED_IP | Title: $HTTP_TITLE"
      sleep 5
    done
    ;;
  *)
    echo "Usage: $0 {down|up|status|test-dns <domain>}"
    exit 1
    ;;
esac
