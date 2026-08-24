-- name: GetUserList :many
SELECT * FROM users;

-- name: GetUser :one
SELECT * FROM users WHERE id = sqlc.arg(id);

-- name: GetLoginIdentifier :one
SELECT
    u.id AS user_id,
    u.display_name,
    u.locale,
    u.timezone,
    u.status,
    u.security_version,
    ui.kind AS identifier_kind,
    ui.normalized_value AS identifier_value,
    ui.is_primary AS identifier_is_primary,
    uc.password_hash,
    uc.password_algorithm,
    uc.password_changed_at,
    uc.failed_attempts,
    uc.locked_until,
    uc.must_change_password
FROM user_identifiers ui
INNER JOIN users u ON ui.user_id = u.id
INNER JOIN user_credentials uc ON uc.user_id = u.id
WHERE ui.kind = sqlc.arg(kind) AND ui.normalized_value = sqlc.arg(value);

-- name: ExistingIdentifier :one
SELECT
    id
FROM user_identifiers
WHERE kind = $1 AND normalized_value = $2;

-- name: CreateUser :one
INSERT INTO users (
    id,
    display_name,
    locale,
    timezone,
    created_at
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5
) RETURNING id;

-- name: CreateIdentifier :exec
INSERT INTO user_identifiers (
    id,
    user_id,
    kind,
    value,
    normalized_value,
    verified_at,
    is_primary,
    created_at
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6,
    $7,
    $8
);

-- name: CreateCredential :exec
INSERT INTO user_credentials (
    user_id,
    password_hash,
    password_algorithm,
    password_changed_at,
    updated_at
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5
);

-- name: IncrementFailedAttempts :one
UPDATE user_credentials
SET
    failed_attempts = failed_attempts + 1,
    locked_until = CASE
                       WHEN failed_attempts + 1 >= sqlc.arg(threshold) THEN sqlc.arg(lock_until)
                       ELSE locked_until
        END,
    updated_at = sqlc.arg(updated_at)
WHERE user_id = sqlc.arg(user_id)
    RETURNING failed_attempts, locked_until;

-- name: ResetFailedAttempts :exec
UPDATE user_credentials
SET
    failed_attempts = 0,
    locked_until = NULL,
    updated_at = sqlc.arg(updated_at)
WHERE user_id = sqlc.arg(user_id);
