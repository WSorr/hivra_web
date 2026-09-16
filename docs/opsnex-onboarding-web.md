# Opxnex Website Contribution Boundary

## Purpose

Opxnex maintains an independent, public-consumer view of the Hivra website.
The role covers source smoke checks, public availability, internal links,
static assets, and TLS health.

It does not include Hivra product semantics, architecture ownership, VPS
administration, production deployment, or access to infrastructure secrets.

## Contribution Flow

1. Clone the website with the contributor's own GitHub identity.
2. Create a focused `opsnex/*` branch.
3. Run `./scripts/ci-site.sh` before opening a pull request.
4. Describe the observable problem, the bounded correction, and the evidence.
5. Submit the branch through a pull request. Do not push directly to `main`.

Repository owners review and merge changes. Production deployment remains a
separate owner action after merge.

## Verification

The canonical command is:

```sh
./scripts/ci-site.sh
```

It starts a local server and verifies:

- required public pages;
- internal page links;
- referenced stylesheets and image assets;
- `robots.txt` and `sitemap.xml`.

GitHub Actions also runs:

```sh
./scripts/ci-site.sh https://hivra.space/
```

This is a credential-free external health check. It verifies the same public
surface and rejects an invalid or near-expiry TLS certificate.

## Security Boundary

- Never commit server addresses, account names, keys, credentials, VPN
  inventory, container details, or recovery instructions.
- Do not request VPS access for source or public health checks.
- Do not run deployment commands as part of contributor verification.
- Do not change Hivra architecture claims without a corresponding accepted
  change in the canonical application documentation.
