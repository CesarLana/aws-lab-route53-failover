#!/bin/bash
# ==============================================================================
# AWS Lab: Route 53 Active-Passive Failover
# Script: scripts/secondary_web_setup.sh
# Purpose: Initialize Secondary Apache Web Server (DR / Standby)
# ==============================================================================

set -euo pipefail

dnf update -y
dnf install -y httpd
systemctl start httpd
systemctl enable httpd

# Retrieve metadata via IMDSv2
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id || echo "Unknown")
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone || echo "Unknown")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 || echo "Unknown")

cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>SECONDARY STANDBY | Route 53 Failover</title>
  <style>
    body {
      background-color: #1a0f0a;
      color: #f1f5f9;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
    }
    .box {
      background: #2b1810;
      border: 2px solid #f97316;
      border-radius: 16px;
      padding: 3rem;
      max-width: 580px;
      width: 100%;
      box-shadow: 0 10px 30px rgba(249, 115, 22, 0.25);
      text-align: center;
    }
    .badge {
      background: rgba(249, 115, 22, 0.2);
      color: #f97316;
      display: inline-block;
      padding: 6px 16px;
      border-radius: 9999px;
      font-weight: 700;
      letter-spacing: 1px;
      margin-bottom: 1.5rem;
    }
    h1 { margin-bottom: 0.5rem; font-size: 2rem; color: #ffffff; }
    p.desc { color: #fed7aa; margin-bottom: 2rem; font-size: 0.95rem; }
    .data-table {
      text-align: left;
      background: rgba(15, 8, 5, 0.7);
      border-radius: 8px;
      padding: 1rem 1.5rem;
      margin-bottom: 1.5rem;
    }
    .data-row {
      display: flex;
      justify-content: space-between;
      padding: 0.5rem 0;
      border-bottom: 1px solid rgba(255,255,255,0.06);
    }
    .data-row:last-child { border-bottom: none; }
    .label { color: #fed7aa; font-size: 0.85rem; }
    .val { font-family: monospace; font-weight: 600; color: #fb923c; }
  </style>
</head>
<body>
  <div class="box">
    <span class="badge">⚠️ FAILOVER ACTIVATED: SECONDARY STANDBY</span>
    <h1>Servidor de Disaster Recovery</h1>
    <p class="desc">O endpoint primário falhou no Health Check. O Route 53 redirecionou o tráfego com sucesso para este servidor de contingência.</p>

    <div class="data-table">
      <div class="data-row">
        <span class="label">Função no Cluster</span>
        <span class="val" style="color: #f97316;">SECONDARY / DR STANDBY</span>
      </div>
      <div class="data-row">
        <span class="label">Availability Zone</span>
        <span class="val">$AZ</span>
      </div>
      <div class="data-row">
        <span class="label">Instance ID</span>
        <span class="val">$INSTANCE_ID</span>
      </div>
      <div class="data-row">
        <span class="label">Public IPv4</span>
        <span class="val">$PUBLIC_IP</span>
      </div>
    </div>
  </div>
</body>
</html>
EOF

echo "OK" > /var/www/html/healthz
chmod 644 /var/www/html/index.html /var/www/html/healthz
