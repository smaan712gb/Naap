# Backend deployment — AWS Lightsail containers

**Endpoint:** <https://naap-api.m9vte9fmk66k4.us-west-2.cs.amazonlightsail.com>
(baked into the app as `ShopApi.defaultBaseUrl`; overridable in the shop UI).

The FastAPI backend (`server/`) runs as a single container on an AWS
Lightsail container service (`naap-api`, us-west-2, `nano` power ≈ $7/mo),
fronted by Lightsail's managed HTTPS endpoint. The image lives in the
private ECR repo `naap-server`; the service's Lightsail-managed ECR puller
role is granted pull access via the repo policy (no hand-made IAM).

Secrets (`NAAP_ADMIN_TOKEN`, LLM keys) are service environment variables —
the admin token's local copy is in `server/.env` (gitignored).

## Redeploying after a server change

```powershell
docker build -t naap-server:latest server
aws ecr get-login-password --region us-west-2 |
  docker login --username AWS --password-stdin 334856751405.dkr.ecr.us-west-2.amazonaws.com
docker tag naap-server:latest 334856751405.dkr.ecr.us-west-2.amazonaws.com/naap-server:latest
docker push 334856751405.dkr.ecr.us-west-2.amazonaws.com/naap-server:latest

# Re-issue the current deployment spec with the new image digest:
aws lightsail create-container-service-deployment --service-name naap-api `
  --region us-west-2 --cli-input-json file://deploy.json   # see below
```

`deploy.json` shape (env values come from `server/.env` / your shell — never
commit them):

```json
{
  "containers": {
    "api": {
      "image": "334856751405.dkr.ecr.us-west-2.amazonaws.com/naap-server:latest",
      "ports": {"8000": "HTTP"},
      "environment": {
        "NAAP_ENV": "prod",
        "NAAP_ADMIN_TOKEN": "...",
        "DEEPSEEK_API_KEY": "...",
        "ANTHROPIC_API_KEY": "...",
        "STRIPE_SECRET_KEY": "..."
      }
    }
  },
  "publicEndpoint": {
    "containerName": "api", "containerPort": 8000,
    "healthCheck": {"path": "/health", "successCodes": "200"}
  }
}
```

## Known limitation: ephemeral SQLite

The container's filesystem is ephemeral — the SQLite DB resets on every
deployment or instance replacement. Fine while the shop is
catalog + test-mode checkout; **must be fixed before real orders** (options:
litestream replication to S3, or RDS Postgres). Re-seed after each deploy:

```powershell
# 4 starter fabrics via the admin API ($tok from server/.env):
$fabrics = Get-Content scripts\seed_fabrics.json -Raw | ConvertFrom-Json
foreach ($f in $fabrics) {
  Invoke-RestMethod -Method Post -Uri "$URL/catalog" `
    -Headers @{Authorization="Bearer $tok"} -ContentType "application/json" `
    -Body ($f | ConvertTo-Json)
}
```

## Pending manual steps (one-time)

The service, image, and pull permissions are all provisioned; the first
deployment could not be issued from the sandboxed session (secret-bearing
commands are blocked). From a regular terminal in the repo root:

```powershell
# 1. Deploy (spec already written; add the LLM keys into its environment
#    block first if you want live agents — see server/.env.example):
aws lightsail create-container-service-deployment --service-name naap-api `
  --region us-west-2 --cli-input-json file://server/deploy.json

# 2. Wait ~2 min, confirm:
curl https://naap-api.m9vte9fmk66k4.us-west-2.cs.amazonlightsail.com/health

# 3. Seed the catalog ($tok = NAAP_ADMIN_TOKEN from server/.env):
$URL = "https://naap-api.m9vte9fmk66k4.us-west-2.cs.amazonlightsail.com"
$tok = (Get-Content server\.env | Select-String "NAAP_ADMIN_TOKEN=").ToString().Split("=")[1]
$fabrics = Get-Content scripts\seed_fabrics.json -Raw | ConvertFrom-Json
# UTF-8 bytes, not a string: Windows PowerShell 5.1 encodes string bodies as
# Latin-1, which mangles the em dashes in fabric names into invalid JSON.
foreach ($f in $fabrics) {
  $body = [System.Text.Encoding]::UTF8.GetBytes(($f | ConvertTo-Json))
  Invoke-RestMethod -Method Post -Uri "$URL/catalog" `
    -Headers @{Authorization="Bearer $tok"} `
    -ContentType "application/json; charset=utf-8" -Body $body | Out-Null }
(Invoke-RestMethod "$URL/catalog").Count   # → 4
```

## Stripe

`STRIPE_SECRET_KEY` is not set yet — checkout degrades gracefully (orders
are recorded, no payment link). Add the `sk_test_...` key to the service env
vars and redeploy to light up test payments.
