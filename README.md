# Vaultwarden (Raspberry Pi, SSO via Authentik)

> Bitwarden-compatible password manager on the Raspberry Pi, reachable through the
> WireGuard + Caddy proxy. Admin page protected by an argon2 token, optional SSO
> through Authentik (OIDC + PKCE).

## Architecture

```
Browser / Bitwarden apps → VPS → WireGuard → RPi Caddy (TLS) → vaultwarden (127.0.0.1:9003)
                                                                 └→ Authentik (localhost, OIDC)
```

- Single container, bound to `127.0.0.1`. Data (SQLite, attachments) lives in `./data`.
- Caddy sends `X-Forwarded-For`, so `IP_HEADER` is set to it. Logs show the real client IP.
- Authentik is resolved on the host via `extra_hosts`, so OIDC calls don't hairpin through the VPS.

## Security choices

- **Admin token**: stored as an argon2id hash (OWASP preset), never in plain text.
  The plaintext token is kept in the vault itself.
- **Signups**: open for the first account only, then closed.
- **SSO**: PKCE enabled, accounts matched by email, unverified emails refused.
- SSO handles login only. The master password is still required to decrypt the vault.

## Phase 1: first boot (no SSO)

```bash
./generate-secrets.sh    # creates .env and prints a plaintext admin token
docker run --rm -it vaultwarden/server:1.37.5 /vaultwarden hash --preset owasp
# enter the token twice, copy the $argon2id$... output
vim .env                 # ADMIN_TOKEN='$argon2id$...'  (single quotes)
                         # also set DOMAIN and AUTH_HOST
docker compose up -d
docker compose ps        # wait for (healthy)
```

Create your account at `https://vault.example.com`, then close signups:

```bash
sed -i 's/^SIGNUPS_ALLOWED=true/SIGNUPS_ALLOWED=false/' .env
docker compose up -d --force-recreate
```

Caddy on the Pi:

```
vault.example.com {
    reverse_proxy 127.0.0.1:9003
}
```

## Phase 2: SSO (Authentik)

In Authentik, create an OAuth2/OpenID provider (confidential client):

| Field        | Value                                                     |
|--------------|-----------------------------------------------------------|
| Slug         | `vaultwarden`                                             |
| Redirect URI | `https://vault.example.com/identity/connect/oidc-signin`  |
| Scopes       | `openid`, `profile`, `email`, `offline_access`            |

Then in `.env`:

```
SSO_ENABLED=true
SSO_CLIENT_ID=...
SSO_CLIENT_SECRET=...
```

```bash
docker compose up -d --force-recreate
```

Keep `SSO_ONLY=false` until SSO login works, so you can't lock yourself out.
