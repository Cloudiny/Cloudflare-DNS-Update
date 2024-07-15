FROM alpine:latest

# Install the necesary tools (bash, curl, jq)
RUN apk --no-cache add bash curl jq

# Copy the script to the container
COPY Cloudflare-DNS-Update.sh /usr/local/bin/Cloudflare-DNS-Update.sh

# Set exec permissions to the script
RUN chmod +x /usr/local/bin/Cloudflare-DNS-Update.sh

# Set working directory
WORKDIR /usr/local/bin

# Define variables to Clodflare
ENV CLOUDFLARE_TOKEN=""
ENV DOMAINS=""
ENV PROXIED=""

# Execute script when the container starts
CMD ["bash", "-c", "./Cloudflare-DNS-Update.sh \"$CLOUDFLARE_TOKEN\" \"$DOMAINS\" \"$PROXIED\" \"$GOTIFY_SERVER\" \"$GOTIFY_TOKEN\""]
