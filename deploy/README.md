## VPS Deploy Notes

Current production domain: `hivra.space`

Current web root on VPS:

```text
/var/www/hivra.space
```

Current nginx vhost tracked in this repo:

```text
deploy/nginx/hivra.space.conf
```

Basic sync command:

```bash
rsync -av --delete -e 'ssh -i ~/.ssh/<your-vps-key>' ./ root@38.180.117.117:/var/www/hivra.space/ --exclude '.git' --exclude '.DS_Store'
```
