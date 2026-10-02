# K7.3.2 — Auto Apply master-read contract

## Root cause

Store Management persisted `auto_apply`, but the shared `get_store_catalog()`
RPC used by the kiosk did not include the field in its product-option JSON.
The kiosk therefore decoded the missing field using its backward-compatible
default `false`.

## Fix

The migration updates `get_store_catalog()` to return:

```json
{
  "optionId": "paper_straw",
  "autoApply": true
}
```

Apply the migration in the shared Supabase project before testing kiosk sync.
