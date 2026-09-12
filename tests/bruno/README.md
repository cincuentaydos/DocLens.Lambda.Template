# DocLens API — Bruno collection

Open this folder directly in [Bruno](https://www.usebruno.com/) (File → Open Collection).

## Setup

1. Select the **sbx** environment (top-right dropdown).
2. Click the environment, open **Configure**, and fill in `testPassword` under
   the secret variables — value is in the team's password manager, not
   committed here on purpose (see `environments/sbx.bru`).

## Running the smoke test

1. **Auth / Get Token** — logs in as the `test@doclens.org` Cognito test user
   (`custom:tenantId=test-tenant`) and stores the returned `IdToken` as an
   environment variable the other requests reuse.
2. **Smoke / Swagger Health** — unauthenticated reachability check.
3. **Smoke / Process Document** — authenticated call to the one real endpoint
   (`POST /documents/process`). The `s3Key` in the request body doesn't point
   at a real object yet, so this won't return `200` until one is uploaded to
   the document bucket — that's expected. What it proves at this stage: the
   JWT authorizer, `TenantMiddleware`, and the Lambda handler itself are all
   wired correctly (i.e. failures here are business-logic failures, not
   auth/routing failures).

Run **Auth / Get Token** before **Smoke / Process Document** — the latter
depends on `{{idToken}}` being set.
