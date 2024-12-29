#!/bin/bash

# Cloudflare API credentials
CF_EMAIL="you@email.com" # Account email
CF_AUTH_TOKEN="1a2b3c4d" # Authorisation token

# Cloudflare zone
CF_DOMAIN_1="domain.com"
CF_DOMAIN_1_ID="1234abcd"
CF_SUBDOMAIN_1="sub.domain.com"
# Optional: if you want to manipulate multiple DNS records
# CF_DOMAIN_2=""
# CF_DOMAIN_2_ID=""
# CF_SUBDOMAIN_2=""

# Associative array for zone IDs
declare -A zones
zones[CF_DOMAIN_1]=CF_DOMAIN_1_ID
# zones[CF_DOMAIN_2]=CF_DOMAIN_2_ID

# DNS record names
declare -A dns_names
dns_names[CF_DOMAIN_1]=CF_SUBDOMAIN_1
# dns_names[CF_DOMAIN_2]=CF_SUBDOMAIN_2

# Get current public IP address
CURRENT_IP=$(curl -s https://checkip.amazonaws.com)

# Cloudflare API base URL
CF_API_URL="https://api.cloudflare.com/client/v4"

# Function to get the DNS record ID for a domain
get_dns_record_id() {
  local zone_id="$1"
  local dns_name="$2"
  
  curl -v -X GET "$CF_API_URL/zones/$zone_id/dns_records?type=A&name=$dns_name" \
       -H "Authorization: Bearer $CF_AUTH_TOKEN" \
       -H "Content-Type: application/json" | jq -r '.result[0].id'
}

# Function to get the current DNS record IP address
get_current_dns_ip() {
  local zone_id="$1"
  local dns_name="$2"

  curl -v -X GET "$CF_API_URL/zones/$zone_id/dns_records?type=A&name=$dns_name" \
       -H "Authorization: Bearer $CF_AUTH_TOKEN" \
       -H "Content-Type: application/json" | jq -r '.result[0].content'
}

# Function to update the DNS record with the new IP address
update_dns_record() {
  local zone_id="$1"
  local dns_name="$2"
  local dns_record_id="$3"
  local new_ip="$4"

  curl -v -X PUT "$CF_API_URL/zones/$zone_id/dns_records/$dns_record_id" \
       -H "Authorization: Bearer $CF_AUTH_TOKEN" \
       -H "Content-Type: application/json" \
       --data '{"type":"A","name":"'"$dns_name"'","content":"'"$new_ip"'","ttl":120,"proxied":false}'
}

# Loop over each zone to update the DNS records if needed
for zone in "${!zones[@]}"; do
  ZONE_ID="${zones[$zone]}"
  DNS_NAME="${dns_names[$zone]}"

  # Get current DNS record IP address
  CURRENT_DNS_IP=$(get_current_dns_ip "$ZONE_ID" "$DNS_NAME")

  echo "Checking DNS record for $DNS_NAME (Current: $CURRENT_DNS_IP, Server: $CURRENT_IP)"

  # Check if the current DNS record IP matches the current public IP
  if [ "$CURRENT_DNS_IP" == "$CURRENT_IP" ]; then
    echo "No update needed for $DNS_NAME"
  else
    echo "Updating $DNS_NAME from $CURRENT_DNS_IP to $CURRENT_IP"

    # Get DNS record ID
    DNS_RECORD_ID=$(get_dns_record_id "$ZONE_ID" "$DNS_NAME")

    # Update the DNS record
    update_dns_record "$ZONE_ID" "$DNS_NAME" "$DNS_RECORD_ID" "$CURRENT_IP"

    echo "Updated DNS record for $DNS_NAME"
  fi
done
