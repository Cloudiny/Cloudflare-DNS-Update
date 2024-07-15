# Cloudflare-DNS-Update

This Docker image is designed to manage DNS and send Gotify notifications.


Overview

This Docker image is designed to manage DNS A records in Cloudflare. It checks if the public IP address of your server has changed and updates the DNS A records accordingly. It also provides optional notifications via Gotify. Key Features

Automatic DNS Updates: Periodically checks the public IP address and updates the Cloudflare DNS A records if there's a change.
DNS Record Creation: If a DNS A record doesn't exist for a given domain, the script will create one.
Gotify Notifications: Optional support for sending notifications via Gotify when DNS records are updated.
IP Check Frequency: The script runs in a loop, checking the IP address every 5 minutes.

Environment Variables

The following environment variables can be used to configure the container:

CLOUDFLARE_TOKEN: Your Cloudflare API token with permissions to modify DNS records.
DOMAINS: Comma-separated list of domains/subdomains to manage (e.g., example.com,sub.example.com).
PROXIED: Boolean value (true or false) indicating whether the DNS records should be proxied through Cloudflare.
GOTIFY_SERVER (optional): URL of your Gotify server for notifications.
GOTIFY_TOKEN (optional): Gotify API token for sending notifications.

Usage

To run the container, use the following docker run command:
```bash
docker run -e CLOUDFLARE_TOKEN="your_cloudflare_token"
-e DOMAINS="example.com,sub.example.com"
-e PROXIED="true"
-e GOTIFY_SERVER="https://gotify.example.com⁠"
-e GOTIFY_TOKEN="your_gotify_token"
update-dns-script
```

This will start the container and begin the process of managing your DNS records. The script will check the public IP address every 5 minutes and update the DNS records if necessary. Example

Suppose you have the following setup:

CLOUDFLARE_TOKEN is abc123.
You want to manage the domains example.com and sub.example.com.
You want the DNS records to be proxied.
You have a Gotify server at https://gotify.example.com and an API token def456.

You would run the container with:
```bash
docker run -e CLOUDFLARE_TOKEN="abc123"
-e DOMAINS="example.com,sub.example.com"
-e PROXIED="true"
-e GOTIFY_SERVER="https://gotify.example.com⁠"
-e GOTIFY_TOKEN="def456"
update-dns-script
```

Notes

Make sure the Cloudflare API token has the necessary permissions to read and modify DNS records.
The Gotify server and token are optional. If not provided, notifications will not be sent.
The script assumes all domains belong to the same Cloudflare zone.
