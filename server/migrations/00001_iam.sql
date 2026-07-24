CREATE TYPE user_status AS ENUM ('active', 'locked', 'deleted');
CREATE TABLE IF NOT EXISTS users (
    id uuid NOT NULL PRIMARY KEY,
    display_name varchar(64) NOT NULL,
    avatar_url text,
    locale varchar(64),
    timezone varchar(64),
    status user_status,
    security_version bigint,
    locked_at timestamptz,
    created_at timestamptz NOT NULL,
    updated_at timestamptz,
    deleted_at timestamptz
);
COMMENT ON TABLE users IS '用户';
COMMENT ON COLUMN users.id IS '用户ID';
COMMENT ON COLUMN users.display_name IS '显示名称';
COMMENT ON COLUMN users.avatar_url IS '头像地址';
COMMENT ON COLUMN users.locale IS '默认语言';
COMMENT ON COLUMN users.timezone IS '默认时区';
COMMENT ON COLUMN users.status IS '用户状态';
COMMENT ON COLUMN users.security_version IS '安全版本';
COMMENT ON COLUMN users.locked_at IS '锁定时间';
COMMENT ON COLUMN users.created_at IS '创建时间';
COMMENT ON COLUMN users.updated_at IS '更新时间';
COMMENT ON COLUMN users.deleted_at IS '删除时间';



CREATE TYPE identifier_kind AS ENUM('email', 'phone', 'username');
CREATE TABLE IF NOT EXISTS user_identifiers (
    id uuid NOT NULL PRIMARY KEY,
    user_id uuid NOT NULL,
    kind identifier_kind NOT NULL,
    value varchar(256) NOT NULL,
    normalized_value varchar(256) NOT NULL,
    verified_at timestamptz,
    is_primary boolean NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT uk_user_identifiers UNIQUE(kind, normalized_value),
    CONSTRAINT fk_user_identifiers_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE user_identifiers IS '登录标识';
COMMENT ON COLUMN user_identifiers.id IS '标识ID';
COMMENT ON COLUMN user_identifiers.user_id IS '所属用户';
COMMENT ON COLUMN user_identifiers.kind IS '标识类型';
COMMENT ON COLUMN user_identifiers.value IS '原始值';
COMMENT ON COLUMN user_identifiers.normalized_value IS '标准值';
COMMENT ON COLUMN user_identifiers.verified_at IS '验证时间';
COMMENT ON COLUMN user_identifiers.is_primary IS '是否主标识';
COMMENT ON COLUMN user_identifiers.created_at IS '创建时间';



CREATE TABLE IF NOT EXISTS user_credentials (
    user_id uuid NOT NULL PRIMARY KEY,
    password_hash text NOT NULL,
    password_algorithm varchar NOT NULL,
    password_changed_at timestamptz NOT NULL,
    failed_attempts integer DEFAULT 0,
    locked_until timestamptz,
    must_change_password boolean NOT NULL DEFAULT false,
    updated_at timestamptz NOT NULL,
    CONSTRAINT fk_user_credentials_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE user_credentials IS '密码凭据';
COMMENT ON COLUMN user_credentials.user_id IS '用户ID';
COMMENT ON COLUMN user_credentials.password_hash IS '密码哈希';
COMMENT ON COLUMN user_credentials.password_algorithm IS '加密算法及版本';
COMMENT ON COLUMN user_credentials.password_changed_at IS '最近修改时间';
COMMENT ON COLUMN user_credentials.failed_attempts IS '连续失败次数';
COMMENT ON COLUMN user_credentials.locked_until IS '锁定截止时间';
COMMENT ON COLUMN user_credentials.must_change_password IS '是否强制修改密码';
COMMENT ON COLUMN user_credentials.updated_at IS '更新时间';



-- TODO: identity_providers



-- TODO: user_identities



-- TODO: mfa_methods



CREATE TYPE authn_level AS ENUM ('password', 'mfa', 'sso');
CREATE TYPE session_status AS ENUM ('active', 'revoked', 'expired');
CREATE TABLE IF NOT EXISTS sessions (
    id uuid NOT NULL PRIMARY KEY,
    user_id uuid NOT NULL,
    token_hash bytea NOT NULL,
    security_version bigint NOT NULL,
    authn_level authn_level NOT NULL,
    device_id varchar,
    device_name varchar,
    ip_created inet,
    ip_last inet,
    user_agent_hash varchar,
    tenant_hint uuid,
    status session_status NOT NULL DEFAULT 'active',
    issued_at timestamptz NOT NULL,
    last_seen_at timestamptz NOT NULL,
    idle_expires_at timestamptz NOT NULL,
    absolute_expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    revoke_reason varchar,
    CONSTRAINT uk_sessions_token_hash UNIQUE(token_hash),
    CONSTRAINT fk_sessions_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE sessions IS '登录会话';
COMMENT ON COLUMN sessions.id IS '会话ID';
COMMENT ON COLUMN sessions.user_id IS '用户ID';
COMMENT ON COLUMN sessions.token_hash IS '令牌哈希';
COMMENT ON COLUMN sessions.security_version IS '创建时用户安全版本';
COMMENT ON COLUMN sessions.authn_level IS '认证级别';
COMMENT ON COLUMN sessions.device_id IS '设备标识';
COMMENT ON COLUMN sessions.device_name IS '设备名称';
COMMENT ON COLUMN sessions.ip_created IS '登录IP';
COMMENT ON COLUMN sessions.ip_last IS '最近活动IP';
COMMENT ON COLUMN sessions.user_agent_hash IS 'User-Agent摘要';
COMMENT ON COLUMN sessions.tenant_hint IS '最近租户提示';
COMMENT ON COLUMN sessions.status IS '会话状态';
COMMENT ON COLUMN sessions.issued_at IS '签发时间';
COMMENT ON COLUMN sessions.last_seen_at IS '最近使用时间';
COMMENT ON COLUMN sessions.idle_expires_at IS '空闲过期时间';
COMMENT ON COLUMN sessions.absolute_expires_at IS '绝对过期时间';
COMMENT ON COLUMN sessions.revoked_at IS '吊销时间';
COMMENT ON COLUMN sessions.revoke_reason IS '吊销原因';

CREATE INDEX idx_sessions_token_hash ON sessions(token_hash);
CREATE INDEX idx_sessions_user_id ON sessions(user_id);

-- ALTER TABLE users ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE users FORCE ROW LEVEL SECURITY;
--
-- CREATE POLICY tenant_isolation ON users
-- USING (
--     tenant_id = current_setting('app.tenant_id')::uuid
-- )
-- WITH CHECK (
--     tenant_id = current_setting('app.tenant_id')::uuid
-- );