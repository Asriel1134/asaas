-- name: IsPlatformUser :one
SELECT EXISTS(
    SELECT 1
    FROM platform_users pu
    WHERE pu.user_id = sqlc.arg(userID)
      AND pu.status = 'active'
);

-- name: GetPlatformPermissions :many
SELECT
    pd.code,
    pd.module,
    pd.resource,
    pd.action,
    pd.name,
    pd.risk_level,
    pd.supports_data_scope
FROM platform_user_role_bindings purb
INNER JOIN platform_users pu ON pu.user_id = purb.user_id
INNER JOIN platform_roles pr ON pr.id = purb.platform_role_id
INNER JOIN platform_role_permissions prp ON prp.platform_role_id = pr.id
INNER JOIN permission_definitions pd ON prp.permission_code = pd.code
WHERE purb.user_id = sqlc.arg(userID)
  AND pu.status = 'active'
  AND purb.valid_from <= now()
  AND (purb.valid_until IS NULL OR purb.valid_until > now())
  AND pd.realm = 'platform'
  AND pd.status = 'active'
  AND pr.status = 'active';

-- name: GetPlatformPermissionDeadline :one
SELECT COALESCE(MIN(boundary_at), now() + interval '30 minutes')::timestamptz AS next_change_at
FROM (
    SELECT purb.valid_from AS boundary_at
    FROM platform_user_role_bindings purb
    WHERE purb.user_id = sqlc.arg(userID)
      AND purb.valid_from > now()
    UNION ALL
    SELECT purb.valid_until AS boundary_at
    FROM platform_user_role_bindings purb
    WHERE purb.user_id = sqlc.arg(userID)
      AND purb.valid_until > now()
) boundaries;

-- name: GetTenantPermissions :many
SELECT
    pd.code,
    pd.module,
    pd.resource,
    pd.action,
    pd.name,
    pd.risk_level,
    pd.supports_data_scope,
    mrb.binding_scope,
    mrb.workspace_id,
    mrb.org_unit_id,
    t.authz_version AS tenant_authz_version,
    tm.authz_version AS member_authz_version
FROM tenant_member_role_bindings mrb
INNER JOIN tenant_roles r ON r.tenant_id = mrb.tenant_id AND r.id = mrb.role_id
INNER JOIN tenant_role_permissions rp ON rp.tenant_id = r.tenant_id AND rp.role_id = r.id
INNER JOIN permission_definitions pd ON rp.permission_code = pd.code
INNER JOIN tenants t ON t.id = mrb.tenant_id
INNER JOIN tenant_members tm ON tm.user_id = mrb.user_id AND tm.tenant_id = mrb.tenant_id
LEFT JOIN tenant_member_org_units mou ON mou.user_id = mrb.user_id
    AND mou.tenant_id = mrb.tenant_id
    AND mou.org_unit_id = mrb.org_unit_id
WHERE mrb.user_id = sqlc.arg(userID)
  AND mrb.tenant_id = sqlc.arg(tenantID)
  AND mrb.valid_from <= now()
  AND (mrb.valid_until IS NULL OR mrb.valid_until > now())
  AND pd.realm = 'tenant'
  AND pd.status = 'active'
  AND r.status = 'active'
  AND (
      mrb.binding_scope = 'tenant'
      OR (mrb.binding_scope = 'workspace' AND mrb.workspace_id = COALESCE(sqlc.narg(workspaceID), tm.default_workspace_id))
      OR (mrb.binding_scope = 'org_unit'  AND mou.org_unit_id IS NOT NULL)
  );

-- name: GetTenantPermissionDeadline :one
SELECT COALESCE(MIN(boundary_at), now() + interval '30 minutes')::timestamptz AS next_change_at
FROM (
    SELECT mrb.valid_from AS boundary_at
    FROM tenant_member_role_bindings mrb
    WHERE mrb.user_id = sqlc.arg(userID)
      AND mrb.tenant_id = sqlc.arg(tenantID)
      AND mrb.valid_from > now()
    UNION ALL
    SELECT mrb.valid_until AS boundary_at
    FROM tenant_member_role_bindings mrb
    WHERE mrb.user_id = sqlc.arg(userID)
      AND mrb.tenant_id = sqlc.arg(tenantID)
      AND mrb.valid_until > now()
) boundaries;

-- name: BumpTenantAuthzVersion :exec
UPDATE tenants
SET authz_version = authz_version + 1
WHERE id = sqlc.arg(tenantID);

-- name: BumpMemberAuthzVersion :exec
UPDATE tenant_members
SET authz_version = authz_version + 1
WHERE tenant_id = sqlc.arg(tenantID)
  AND user_id = sqlc.arg(userID);

-- name: BumpPlatformAuthzVersion :exec
UPDATE global_authz_versions
SET platform_authz_version = platform_authz_version + 1
WHERE id = 1;

-- name: BumpPermissionCatalogVersion :exec
UPDATE global_authz_versions
SET permission_catalog_version = permission_catalog_version + 1
WHERE id = 1;

-- name: BumpPlatformUserAuthzVersion :exec
UPDATE platform_users
SET authz_version = authz_version + 1
WHERE user_id = sqlc.arg(userID);

-- name: BumpServiceAccountAuthzVersion :exec
UPDATE tenant_service_accounts
SET authz_version = authz_version + 1
WHERE tenant_id = sqlc.arg(tenantID)
  AND id = sqlc.arg(serviceAccountID);
