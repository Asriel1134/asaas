-- name: GetSessionByTokenHash :one
SELECT
    s.id,
    s.user_id,
    s.token_hash,
    s.security_version,
    s.authn_level,
    s.device_id,
    s.device_name,
    s.ip_created,
    s.ip_last,
    s.user_agent_hash,
    s.context_tenant_id,
    s.context_type,
    s.status,
    s.issued_at,
    s.last_seen_at,
    s.idle_expires_at,
    s.absolute_expires_at,
    s.revoked_at,
    s.revoke_reason,
    u.security_version AS current_security_version,
    COALESCE(pu.authz_version, 0)::bigint AS platform_user_authz_version,
    tm.status AS member_status,
    tm.default_workspace_id,
    t.status AS tenant_status,
    COALESCE(t.authz_version, 0)::bigint AS tenant_authz_version,
    COALESCE(tm.authz_version, 0)::bigint AS member_authz_version,
    ags.permission_catalog_version,
    ags.platform_authz_version AS platform_global_authz_version,
    EXISTS (
        SELECT 1
        FROM platform_users active_pu
        WHERE active_pu.user_id = s.user_id
          AND active_pu.status = 'active'
    ) AS is_platform_user
FROM user_sessions s
JOIN users u ON u.id = s.user_id
CROSS JOIN global_authz_versions ags
LEFT JOIN platform_users pu ON pu.user_id = s.user_id
LEFT JOIN tenant_members tm ON tm.tenant_id = s.context_tenant_id AND tm.user_id = s.user_id
LEFT JOIN tenants t ON t.id = s.context_tenant_id
WHERE s.token_hash = $1 AND s.status = 'active';

-- name: GetSessionAuthorizationState :one
SELECT
    s.user_id,
    s.context_type,
    s.context_tenant_id,
    tm.default_workspace_id,
    COALESCE(t.authz_version, 0)::bigint AS tenant_authz_version,
    COALESCE(tm.authz_version, 0)::bigint AS member_authz_version,
    COALESCE(pu.authz_version, 0)::bigint AS platform_user_authz_version,
    ags.permission_catalog_version,
    ags.platform_authz_version AS platform_global_authz_version
FROM user_sessions s
JOIN users u ON u.id = s.user_id
CROSS JOIN global_authz_versions ags
LEFT JOIN platform_users pu ON pu.user_id = s.user_id
LEFT JOIN tenant_members tm ON tm.tenant_id = s.context_tenant_id AND tm.user_id = s.user_id
LEFT JOIN tenants t ON t.id = s.context_tenant_id
WHERE s.id = sqlc.arg(sessionID)
  AND s.status = 'active';

-- name: UpdateSessionLastSeen :exec
UPDATE user_sessions
SET last_seen_at = $2, ip_last = $3, idle_expires_at = $4
WHERE id = $1;

-- name: SelectTenantContext :execrows
UPDATE user_sessions s
SET context_type = 'tenant', context_tenant_id = sqlc.arg(tenantID)
WHERE s.id = sqlc.arg(sessionID)
  AND s.context_type = 'pending'
  AND EXISTS (
      SELECT 1
      FROM tenant_members tm
      INNER JOIN tenants t ON t.id = tm.tenant_id
      WHERE tm.tenant_id = sqlc.arg(tenantID)
        AND tm.user_id = s.user_id
        AND tm.status = 'active'
        AND t.status IN ('active', 'readonly')
  );

-- name: SelectPlatformContext :execrows
UPDATE user_sessions s
SET context_type = 'platform', context_tenant_id = NULL
WHERE s.id = sqlc.arg(sessionID)
  AND s.context_type = 'pending'
  AND EXISTS (
      SELECT 1
      FROM platform_users pu
      WHERE pu.user_id = s.user_id
        AND pu.status = 'active'
  );

-- name: RevokeSession :exec
UPDATE user_sessions
SET status = 'revoked', revoked_at = now()
WHERE id = $1 AND status = 'active';

-- name: ExpireSession :exec
UPDATE user_sessions
SET status = 'expired'
WHERE id = $1 AND status = 'active';

-- name: CreateSession :exec
INSERT INTO user_sessions (
    id,
    user_id,
    token_hash,
    security_version,
    authn_level,
    device_id,
    device_name,
    ip_created,
    ip_last,
    user_agent_hash,
    context_tenant_id,
    status,
    issued_at,
    last_seen_at,
    idle_expires_at,
    absolute_expires_at
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6,
    $7,
    $8,
    $9,
    $10,
    $11,
    $12,
    $13,
    $14,
    $15,
    $16
);
