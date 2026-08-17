-- name: IsPlatformUser :one
SELECT EXISTS(
    SELECT 1
    FROM platform_user_role_bindings purb
    INNER JOIN platform_roles pr ON pr.id = purb.platform_role_id
    WHERE purb.user_id = sqlc.arg(userID)
      AND (purb.valid_from IS NULL OR purb.valid_from <= now())
      AND (purb.valid_until IS NULL OR purb.valid_until > now())
      AND pr.status = 'active'
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
INNER JOIN platform_roles pr ON pr.id = purb.platform_role_id
INNER JOIN platform_role_permissions prp ON prp.platform_role_id = pr.id
INNER JOIN permission_definitions pd ON prp.permission_code = pd.code
WHERE purb.user_id = sqlc.arg(userID)
  AND (purb.valid_from IS NULL OR purb.valid_from <= now())
  AND (purb.valid_until IS NULL OR purb.valid_until > now())
  AND pd.realm = 'platform'
  AND pd.status = 'active'
  AND pr.status = 'active';

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
FROM member_role_bindings mrb
INNER JOIN roles r ON r.id = mrb.role_id
INNER JOIN role_permissions rp ON r.id = rp.role_id
INNER JOIN permission_definitions pd ON rp.permission_code = pd.code
INNER JOIN tenants t ON t.id = mrb.tenant_id
INNER JOIN tenant_members tm ON tm.user_id = mrb.user_id AND tm.tenant_id = mrb.tenant_id
LEFT JOIN member_org_units mou ON mou.user_id = mrb.user_id
    AND mou.tenant_id = mrb.tenant_id
    AND mou.org_unit_id = mrb.org_unit_id
WHERE mrb.user_id = sqlc.arg(userID)
  AND mrb.tenant_id = sqlc.arg(tenantID)
  AND (mrb.valid_from IS NULL OR mrb.valid_from <= now())
  AND (mrb.valid_until IS NULL OR mrb.valid_until > now())
  AND pd.realm = 'tenant'
  AND pd.status = 'active'
  AND (
      mrb.binding_scope = 'tenant'
      OR (mrb.binding_scope = 'workspace' AND mrb.workspace_id = sqlc.narg(workspaceID))
      OR (mrb.binding_scope = 'org_unit'  AND mou.org_unit_id IS NOT NULL)
  );