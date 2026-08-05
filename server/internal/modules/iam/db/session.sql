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
    s.tenant_hint,
    s.status,
    s.issued_at,
    s.last_seen_at,
    s.idle_expires_at,
    s.absolute_expires_at,
    s.revoked_at,
    s.revoke_reason,
    u.security_version AS current_security_version,
    tm.status AS member_status
FROM sessions s
JOIN users u ON u.id = s.user_id
LEFT JOIN tenant_members tm ON tm.tenant_id = s.tenant_hint AND tm.user_id = s.user_id
WHERE s.token_hash = $1 AND s.status = 'active';

-- name: UpdateSessionLastSeen :exec
UPDATE sessions
SET last_seen_at = $2, ip_last = $3, idle_expires_at = $4
WHERE id = $1;

-- name: SetSessionTenantHint :execrows
UPDATE sessions
SET tenant_hint = $2
WHERE id = $1 AND tenant_hint IS NULL;

-- name: RevokeSession :exec
UPDATE sessions
SET status = 'revoked', revoked_at = now()
WHERE id = $1 AND status = 'active';

-- name: ExpireSession :exec
UPDATE sessions
SET status = 'expired'
WHERE id = $1 AND status = 'active';

-- name: CreateSession :exec
INSERT INTO sessions (
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
    tenant_hint,
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