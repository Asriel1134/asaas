-- name: CreateTenant :exec
INSERT INTO tenants (
    id,
    slug,
    name,
    status,
    created_by,
    created_at
) VALUES (
    $1,
    $2,
    $3,
    'active',
    $4,
    $5
);

-- name: CreateMember :exec
INSERT INTO tenant_members (
    tenant_id,
    user_id,
    joined_at,
    created_at
) VALUES (
    $1,
    $2,
    $3,
    $4
);

-- name: DisableMember :exec
UPDATE tenant_members
SET status = 'disabled', disabled_at = $3, authz_version = authz_version + 1
WHERE tenant_id = $1 AND user_id = $2 AND status = 'active';

-- name: RemoveMember :exec
UPDATE tenant_members
SET status = 'removed', removed_at = $3, authz_version = authz_version + 1
WHERE tenant_id = $1 AND user_id = $2 AND status IN ('active', 'disabled');

-- name: GetUserTenants :many
SELECT
    t.id AS tenant_id,
    t.slug AS tenant_slug,
    t.name AS tenant_name,
    t.status AS tenant_status,
    tm.status AS member_status,
    tm.job_title,
    tm.employee_no
FROM tenant_members tm
LEFT JOIN tenants t ON t.id = tm.tenant_id
WHERE tm.user_id = sqlc.arg(userId)
  AND tm.status != 'removed';
