
Deployment Guide

Server Configuration

· VPS: 38.180.117.117
· SSH Key: ~/.ssh/root_hivra_key
· Web Root: /var/www/hivra.space/
· Nginx Config: /etc/nginx/nginx.conf

Manual Deployment

```bash
# Copy files to server
scp -i ~/.ssh/root_hivra_key *.html *.css root@38.180.117.117:/var/www/hivra.space/

# Copy images
scp -i ~/.ssh/root_hivra_key -r pictures root@38.180.117.117:/var/www/hivra.space/

# Fix permissions
ssh -i ~/.ssh/root_hivra_key root@38.180.117.117 "chown -R www-data:www-data /var/www/hivra.space/ && chmod -R 755 /var/www/hivra.space/"

# Reload nginx
ssh -i ~/.ssh/root_hivra_key root@38.180.117.117 "systemctl reload nginx"
```

Backup System

Backups are stored in ~/hivra-backups/ with versioned directories:

```
hivra-backups/
├── v20251228_215033/
├── v20251228_204254/
└── v[timestamp]/
```

To restore from backup:

```bash
cp -r ~/hivra-backups/v[timestamp]/* ~/hivra.space/
```

