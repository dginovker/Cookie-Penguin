### Screenshots from the journey...

<img width="1412" height="995" alt="image" src="https://github.com/user-attachments/assets/4d35c1a9-dbd5-4cd2-8827-a9f8510e5155" />

<img width="1144" height="596" alt="image" src="https://github.com/user-attachments/assets/faa7496d-a7cd-4af8-aba0-eca14d25598f" />

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
    location /pinkdragon_signal {
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
