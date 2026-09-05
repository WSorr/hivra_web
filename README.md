# Hivra Website

Public website for the Hivra Person-First Runtime project.

- Production: <https://hivra.space/>
- Application repository: <https://github.com/WSorr/Hivra-App>
- Releases: <https://github.com/WSorr/Hivra-App/releases>

The website explains the product publicly. It is not the normative protocol
specification. Current architecture and implementation claims must remain
aligned with the canonical documentation in the application repository.

## Pages

- `index.html` — product axis and capability lifecycle
- `about.html` — architecture boundaries and effect lifecycle
- `network-v2.html` — conceptual Capsule and Starter illustration, not live data
- `support.html` — direct contribution addresses and network warnings
- `style.css` — shared layout, navigation, responsive behavior, and reveal motion

## Local Preview

```sh
python3 -m http.server 8765
```

Open <http://127.0.0.1:8765/>. Check desktop and mobile widths, keyboard
navigation, reduced-motion behavior, internal links, and browser console errors.

## Deployment

Deployment is an operator action. Server identity and SSH configuration stay
outside Git in `scripts/deploy.local.env` or equivalent environment variables:

```sh
HIVRA_WEB_VPS_HOST=example.invalid
HIVRA_WEB_VPS_USER=deploy-user
HIVRA_WEB_VPS_KEY="$HOME/.ssh/example_key"
```

Always inspect the exact file set before deployment:

```sh
./scripts/run.sh vps deploy-preview
./scripts/run.sh vps deploy CONFIRM
```

The deploy command synchronizes only public website files. It excludes Git,
local operator configuration, scripts, and deployment working directories.

## Security

Do not commit server addresses, account names, private paths, credentials,
private keys, VPN inventory, container names, listener details, or operational
recovery instructions. The repository contains public static assets only.
