#!/bin/bash

# Function to update DNS record
update_dns() {
    local zone_id="$1"
    local domain="$2"
    local record_id="$3"
    local ip_address="$4"
    local proxied="$5"

    update_response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"type":"A","name":"'"$domain"'","content":"'"$ip_address"'","ttl":120,"proxied":'"$proxied"'}')

    if [[ $(echo "$update_response" | jq -r '.success') == "true" ]]; then
        echo -e "✅ Updating DNS record for $domain with IP $ip_address."
        send_gotify_notification "$domain" "$ip_address"
    else
        echo -e "❌ Error updating DNS record for $domain."
    fi
}

# Function to create DNS record
create_dns() {
    local zone_id="$1"
    local domain="$2"
    local ip_address="$3"
    local proxied="$4"

    create_response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"type":"A","name":"'"$domain"'","content":"'"$ip_address"'","ttl":120,"proxied":'"$proxied"',"comment":"Created by Cloudflare-DNS-Update :)"}')

    if [[ $(echo "$create_response" | jq -r '.success') == "true" ]]; then
        echo -e "✅ Creating new DNS record for $domain with IP $ip_address."
        send_gotify_notification "$domain" "$ip_address"
    else
        echo -e "❌ Error creating DNS record for $domain."
    fi
}

# Function to send Gotify notification
send_gotify_notification() {
    local domain="$1"
    local ip_address="$2"

    if [[ -n "$GOTIFY_SERVER" && -n "$GOTIFY_TOKEN" ]]; then
        gotify_response=$(curl -s -X POST "$GOTIFY_SERVER/message" \
            -H "X-Gotify-Key: $GOTIFY_TOKEN" \
            -H "Content-Type: application/json" \
            --data '{"title":"DNS Update","message":"The A record for '"$domain"' has been updated to '"$ip_address"'","priority":5}')
            echo -e "✅ Notification sent to $GOTIFY_SERVER"
        if [[ $(echo "$gotify_response" | jq -r '.error') != "null" ]]; then
            echo -e "❌ Error sending notification to Gotify: $(echo "$gotify_response" | jq -r '.error')"
        fi
    fi
}

# Function to validate the token
validate_token() {
    validate_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type: application/json")

    if [[ $(echo "$validate_response" | jq -r '.success') != "true" ]]; then
        echo "❌ Invalid Cloudflare token. Please verify your token."
        exit 1
    fi
}

# Function to get zone ID
get_zone_id() {
    local base_domain="$1"

    ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$base_domain" \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type: application/json")

    ZONE_ID=$(echo "$ZONE_RESPONSE" | jq -r '.result[0].id')

    if [[ -z "$ZONE_ID" || "$ZONE_ID" == "null" ]]; then
        echo -e "❌ Zone not found for base domain $base_domain. Please ensure the domain is correctly configured in Cloudflare."
        exit 1
    fi

    echo "$ZONE_ID"
}

# Main loop
while true; do
    # Check if enough arguments are provided
    if [[ $# -ne 5 ]]; then
        echo "Usage: $0 <CLOUDFLARE_TOKEN> <domain1,domain2,domain3> <true|false> <GOTIFY_SERVER> <GOTIFY_TOKEN>"
        exit 1
    fi

    # Variables
    CLOUDFLARE_TOKEN="$1"
    DOMAINS="$2"
    PROXIED="$3"
    GOTIFY_SERVER="$4"
    GOTIFY_TOKEN="$5"

    # Validate the proxied variable
    if [[ "$PROXIED" != "true" && "$PROXIED" != "false" ]]; then
        echo "❌ The proxied variable must be 'true' or 'false'."
        exit 1
    fi

    # Validate the token
    validate_token

    # Get the new IP address
    IP_ADDRESS=$(curl -s https://ipv4.icanhazip.com/)
    echo -e "🔍 Detecting IPv4 address: $IP_ADDRESS"

    # Split the domains by commas
    IFS=',' read -r -a domain_array <<< "$DOMAINS"

    # Get the zone ID based on the base domain (first domain in the list)
    base_domain=$(echo "${domain_array[0]}" | awk -F. '{print $(NF-1)"."$NF}')
    echo -e "🔍 Getting zone ID for base domain: $base_domain"
    ZONE_ID=$(get_zone_id "$base_domain")

    # Process each domain
    for domain in "${domain_array[@]}"; do
        # Check if the subdomain belongs to the same zone as the base domain
        domain_base=$(echo "$domain" | awk -F. '{print $(NF-1)"."$NF}')
        if [[ "$domain_base" != "$base_domain" ]]; then
            echo -e "❌ The subdomain $domain does not belong to the zone $base_domain."
            continue
        fi

        echo -e "🔍 Getting DNS record for domain: $domain"

        # Get the A record for the domain
        RECORD_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$domain" \
            -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
            -H "Content-Type: application/json")

        RECORD_ID=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].id')
        CURRENT_IP=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].content')

        # Check if RECORD_ID is found
        if [[ -n "$RECORD_ID" && "$RECORD_ID" != "null" ]]; then
            # Compare the current IP with the obtained IP
            if [[ "$CURRENT_IP" == "$IP_ADDRESS" ]]; then
                echo -e "✅ The A record for \"$domain\" is up to date."
            else
                # Update the DNS record if the IP is different
                update_dns "$ZONE_ID" "$domain" "$RECORD_ID" "$IP_ADDRESS" "$PROXIED"
                 echo -e "✅ El A record for \"$domain\" has been updated."
            fi
        else
            echo -e "⚠️ No A record found for $domain."

            # Create a new DNS record
            create_dns "$ZONE_ID" "$domain" "$IP_ADDRESS" "$PROXIED"
        fi
    done

    echo -e "🔄 Checking IP address again in 5 minutes..."
    echo -e "\033[33m########################################################\033[m"
    sleep 300
done