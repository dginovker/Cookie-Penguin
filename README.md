### Screenshots from the journey...

<img width="1755" height="715" alt="image" src="https://github.com/user-attachments/assets/30c4b12f-4112-474a-af17-0abecf646e16" />

<img width="1412" height="995" alt="image" src="https://github.com/user-attachments/assets/4d35c1a9-dbd5-4cd2-8827-a9f8510e5155" />

<img width="1144" height="596" alt="image" src="https://github.com/user-attachments/assets/faa7496d-a7cd-4af8-aba0-eca14d25598f" />

### Running locally

* Game is designed for ez dev; if you run as a server, you also spawn a player. Modify ServerConnection.gd to have `is_server = ... || true` and click play. Will work out of the box.
* If you want to have multiple players, compile a server, then change that line to `|| false` for each client. Use scripts to make life happy.

### Design Details

Networking:
* The Server is also a player.
* NPCs (AKA mobs) have their movements all batched into one RPC for efficiency.
* NPC movement is interpolated with Netfox for smoothness
* Player movement uses Netfox rollback synchronizers for instant client feedback and anti-cheat
* The game runs on WebRTC with UDP packets
* To prevent Buffer Full errors on client browsers, network/limits/webrtc/max_channel_in_buffer_kb is boosted massively from 64KB to 2MB
* To prevent DoSing the client, server should never send more than 56 KiB/s; this includes all spawn info, player movement, NPC snapshots, etc
* To prevent the browser client from falling behind, the server checks outbound buffer on the Snapshot (NPC movement) channel, and will skip sending the next update if it's non-empty 

### Setting up for Hosting

Nginx config:
```
# Redirect all HTTP traffic to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name duck.openredsoftware.com;

    return 301 https://$host$request_uri;
}

# Main HTTPS reverse proxy for Godot WebSocket server
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name duck.openredsoftware.com;

    # SSL settings
    ssl_certificate /etc/letsencrypt/live/duck.openredsoftware.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/duck.openredsoftware.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # WebSocket endpoint for signaling (used to start WebRTC connection)
    location /pinkdragon {
        proxy_pass http://localhost:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}

```
