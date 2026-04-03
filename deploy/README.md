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

## GitHub Actions Autodeploy

Workflow file:

```text
.github/workflows/deploy-vps.yml
```

The workflow deploys on push to `main` (and can be run manually via `workflow_dispatch`).

Required repository secrets:

```text
VPS_HOST        example: 38.180.117.117
VPS_USER        example: root
VPS_PORT        example: 22
VPS_TARGET_DIR  example: /var/www/hivra.space/
VPS_SSH_KEY     private key contents (multiline), e.g. ~/.ssh/hivra_vps_ed25519
VPS_DOMAIN      optional, default: hivra.space
VPS_CERTBOT_EMAIL optional, default: support@hivra.space
```

Recommended:

- keep a dedicated deploy key for this repo
- if using root deploy, restrict SSH by key and disable password auth when possible
