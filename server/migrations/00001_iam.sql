CREATE TYPE user_status AS ENUM ('active', 'locked', 'deleted');
CREATE TABLE IF NOT EXISTS users (
    id uuid NOT NULL PRIMARY KEY,
    display_name varchar(64) NOT NULL,
    avatar_url text,
    locale varchar(64),
    timezone varchar(64),
    status user_status NOT NULL DEFAULT 'active',
    security_version bigint NOT NULL DEFAULT 1,
    locked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
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
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_identifiers__kind_normalized_value UNIQUE(kind, normalized_value),
    CONSTRAINT fk_user_identifiers__users FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
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

CREATE INDEX ix_user_identifiers__user_id ON user_identifiers(user_id);
CREATE UNIQUE INDEX uq_user_identifiers__primary
    ON user_identifiers(user_id, kind)
    WHERE is_primary = true;



CREATE TABLE IF NOT EXISTS user_credentials (
    user_id uuid NOT NULL PRIMARY KEY,
    password_hash text NOT NULL,
    password_algorithm varchar NOT NULL,
    password_changed_at timestamptz NOT NULL,
    failed_attempts integer NOT NULL DEFAULT 0,
    locked_until timestamptz,
    must_change_password boolean NOT NULL DEFAULT false,
    updated_at timestamptz NOT NULL,
    CONSTRAINT fk_user_credentials__users FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
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



CREATE TYPE provider_type AS ENUM('oidc', 'wecom', 'feishu', 'dingtalk', 'github', 'google');
CREATE TYPE provider_status AS ENUM('active', 'disabled');
CREATE TABLE IF NOT EXISTS identity_providers (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid,
    provider_type provider_type NOT NULL,
    name varchar(64) NOT NULL,
    issuer varchar(256),
    client_id varchar(256),
    secret_ref varchar(256),
    config jsonb,
    status provider_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);
COMMENT ON TABLE identity_providers IS '身份提供商';
COMMENT ON COLUMN identity_providers.id IS '身份源ID';
COMMENT ON COLUMN identity_providers.tenant_id IS '租户ID';
COMMENT ON COLUMN identity_providers.provider_type IS '身份源类型';
COMMENT ON COLUMN identity_providers.name IS '显示名称';
COMMENT ON COLUMN identity_providers.issuer IS '签发者';
COMMENT ON COLUMN identity_providers.client_id IS '客户端ID';
COMMENT ON COLUMN identity_providers.secret_ref IS '密码引用';
COMMENT ON COLUMN identity_providers.config IS '配置';
COMMENT ON COLUMN identity_providers.status IS '身份源状态';
COMMENT ON COLUMN identity_providers.created_at IS '创建时间';
COMMENT ON COLUMN identity_providers.updated_at IS '更新时间';

ALTER TABLE identity_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE identity_providers FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON identity_providers
USING (
    tenant_id IS NULL
    OR tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid
)
WITH CHECK (
    tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid
);



CREATE TABLE IF NOT EXISTS user_identities (
    id uuid NOT NULL PRIMARY KEY,
    user_id uuid NOT NULL,
    provider_id uuid NOT NULL,
    provider_subject varchar(256) NOT NULL,
    email_snapshot varchar(256),
    profile_snapshot jsonb,
    bound_at timestamptz NOT NULL,
    last_login_at timestamptz,
    CONSTRAINT uq_user_identities__provider_subject UNIQUE(provider_id, provider_subject),
    CONSTRAINT fk_user_identities__users FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_user_identities__provider FOREIGN KEY (provider_id) REFERENCES identity_providers(id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE user_identities IS '第三方身份绑定';
COMMENT ON COLUMN user_identities.id IS '绑定ID';
COMMENT ON COLUMN user_identities.user_id IS '用户ID';
COMMENT ON COLUMN user_identities.provider_id IS '身份源ID';
COMMENT ON COLUMN user_identities.provider_subject IS '第三方唯一用户ID';
COMMENT ON COLUMN user_identities.email_snapshot IS '邮箱快照';
COMMENT ON COLUMN user_identities.profile_snapshot IS '用户资料';
COMMENT ON COLUMN user_identities.bound_at IS '绑定时间';
COMMENT ON COLUMN user_identities.last_login_at IS '最后登录时间';

CREATE INDEX ix_user_identities__user_id ON user_identities(user_id);
CREATE INDEX ix_user_identities__provider_id ON user_identities(provider_id);



CREATE TYPE mfa_method_type AS ENUM('totp', 'webauthn', 'recovery_code');
CREATE TYPE mfa_method_status AS ENUM('active', 'revoked');
CREATE TABLE IF NOT EXISTS user_mfa_methods (
    id uuid NOT NULL PRIMARY KEY,
    user_id uuid NOT NULL,
    method_type mfa_method_type NOT NULL,
    name varchar(64) NOT NULL,
    secret_ref varchar(256) NOT NULL,
    credential_data jsonb,
    status mfa_method_status NOT NULL DEFAULT 'active',
    verified_at timestamptz,
    last_used_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT fk_user_mfa_methods__users FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE user_mfa_methods IS '多因素认证';
COMMENT ON COLUMN user_mfa_methods.id IS 'MFA方法ID';
COMMENT ON COLUMN user_mfa_methods.user_id IS '用户ID';
COMMENT ON COLUMN user_mfa_methods.method_type IS '方法类型';
COMMENT ON COLUMN user_mfa_methods.name IS '设备名称';
COMMENT ON COLUMN user_mfa_methods.secret_ref IS '密钥引用';
COMMENT ON COLUMN user_mfa_methods.credential_data IS '认证信息';
COMMENT ON COLUMN user_mfa_methods.status IS 'MFA方法状态';
COMMENT ON COLUMN user_mfa_methods.verified_at IS '验证时间';
COMMENT ON COLUMN user_mfa_methods.last_used_at IS '最近使用时间';
COMMENT ON COLUMN user_mfa_methods.created_at IS '创建时间';
COMMENT ON COLUMN user_mfa_methods.updated_at IS '更新时间';

CREATE INDEX ix_user_mfa_methods__user_id ON user_mfa_methods(user_id);



CREATE TYPE authn_level AS ENUM ('password', 'mfa', 'sso');
CREATE TYPE session_status AS ENUM ('active', 'revoked', 'expired');
CREATE TYPE session_context_type AS ENUM ('pending', 'tenant', 'platform');
CREATE TABLE IF NOT EXISTS user_sessions (
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
    context_type session_context_type NOT NULL DEFAULT 'pending',
    context_tenant_id uuid,
    status session_status NOT NULL DEFAULT 'active',
    issued_at timestamptz NOT NULL,
    last_seen_at timestamptz NOT NULL,
    idle_expires_at timestamptz NOT NULL,
    absolute_expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    revoke_reason varchar,
    CONSTRAINT uq_user_sessions__token_hash UNIQUE(token_hash),
    CONSTRAINT fk_user_sessions__users FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_user_sessions__context CHECK (
        (context_type = 'tenant' AND context_tenant_id IS NOT NULL)
        OR (context_type IN ('pending', 'platform') AND context_tenant_id IS NULL)
    )
);
COMMENT ON TABLE user_sessions IS '登录会话';
COMMENT ON COLUMN user_sessions.id IS '会话ID';
COMMENT ON COLUMN user_sessions.user_id IS '用户ID';
COMMENT ON COLUMN user_sessions.token_hash IS '令牌哈希';
COMMENT ON COLUMN user_sessions.security_version IS '创建时用户安全版本';
COMMENT ON COLUMN user_sessions.authn_level IS '认证级别';
COMMENT ON COLUMN user_sessions.device_id IS '设备标识';
COMMENT ON COLUMN user_sessions.device_name IS '设备名称';
COMMENT ON COLUMN user_sessions.ip_created IS '登录IP';
COMMENT ON COLUMN user_sessions.ip_last IS '最近活动IP';
COMMENT ON COLUMN user_sessions.user_agent_hash IS 'User-Agent摘要';
COMMENT ON COLUMN user_sessions.context_type IS '会话当前上下文：待选择、租户或管理平台';
COMMENT ON COLUMN user_sessions.context_tenant_id IS '租户上下文中的租户ID';
COMMENT ON COLUMN user_sessions.status IS '会话状态';
COMMENT ON COLUMN user_sessions.issued_at IS '签发时间';
COMMENT ON COLUMN user_sessions.last_seen_at IS '最近使用时间';
COMMENT ON COLUMN user_sessions.idle_expires_at IS '空闲过期时间';
COMMENT ON COLUMN user_sessions.absolute_expires_at IS '绝对过期时间';
COMMENT ON COLUMN user_sessions.revoked_at IS '吊销时间';
COMMENT ON COLUMN user_sessions.revoke_reason IS '吊销原因';

CREATE INDEX ix_user_sessions__user_id ON user_sessions(user_id);
CREATE INDEX ix_user_sessions__status ON user_sessions(status);
CREATE INDEX ix_user_sessions__active_expiry ON user_sessions(absolute_expires_at) WHERE status = 'active';



CREATE TYPE tenant_status AS ENUM('pending', 'active', 'suspended', 'readonly', 'deleted');
CREATE TABLE IF NOT EXISTS tenants (
    id uuid NOT NULL PRIMARY KEY,
    slug varchar(256) NOT NULL,
    name varchar(64) NOT NULL,
    status tenant_status NOT NULL DEFAULT 'pending',
    authz_version bigint NOT NULL DEFAULT 1,
    created_by uuid NOT NULL,
    activated_at timestamptz,
    suspended_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT uq_tenants__slug UNIQUE(slug),
    CONSTRAINT fk_tenants__created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE tenants IS '租户';
COMMENT ON COLUMN tenants.id IS '租户ID';
COMMENT ON COLUMN tenants.slug IS '租户标识';
COMMENT ON COLUMN tenants.name IS '租户名称';
COMMENT ON COLUMN tenants.status IS '租户状态';
COMMENT ON COLUMN tenants.authz_version IS '租户权限版本';
COMMENT ON COLUMN tenants.created_by IS '创建人';
COMMENT ON COLUMN tenants.activated_at IS '激活时间';
COMMENT ON COLUMN tenants.suspended_at IS '暂停时间';
COMMENT ON COLUMN tenants.created_at IS '创建时间';
COMMENT ON COLUMN tenants.updated_at IS '更新时间';

CREATE INDEX ix_tenants__status ON tenants(status);

ALTER TABLE identity_providers
    ADD CONSTRAINT fk_identity_providers__tenants
    FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE user_sessions
    ADD CONSTRAINT fk_user_sessions__context_tenant
    FOREIGN KEY (context_tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE;



CREATE TYPE tenant_member_status AS ENUM('active', 'disabled', 'removed');
CREATE TABLE IF NOT EXISTS tenant_members (
    tenant_id uuid NOT NULL,
    user_id uuid NOT NULL,
    status tenant_member_status NOT NULL DEFAULT 'active',
    job_title varchar(64),
    employee_no varchar(64),
    default_workspace_id uuid,
    authz_version bigint NOT NULL DEFAULT 1,
    joined_at timestamptz NOT NULL,
    disabled_at timestamptz,
    removed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    PRIMARY KEY (tenant_id, user_id),
    CONSTRAINT fk_tenant_members__tenants FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_members__users FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE tenant_members IS '租户成员';
COMMENT ON COLUMN tenant_members.tenant_id IS '租户ID';
COMMENT ON COLUMN tenant_members.user_id IS '用户ID';
COMMENT ON COLUMN tenant_members.status IS '成员状态';
COMMENT ON COLUMN tenant_members.job_title IS '职位';
COMMENT ON COLUMN tenant_members.employee_no IS '工号';
COMMENT ON COLUMN tenant_members.default_workspace_id IS '默认工作区';
COMMENT ON COLUMN tenant_members.authz_version IS '权限版本';
COMMENT ON COLUMN tenant_members.joined_at IS '加入时间';
COMMENT ON COLUMN tenant_members.disabled_at IS '禁用时间';
COMMENT ON COLUMN tenant_members.removed_at IS '移除时间';
COMMENT ON COLUMN tenant_members.created_at IS '创建时间';
COMMENT ON COLUMN tenant_members.updated_at IS '更新时间';

ALTER TABLE tenant_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_members FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_members
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);


CREATE TYPE tenant_member_invitation_status AS ENUM ('pending', 'accepted', 'expired', 'revoked');
CREATE TABLE IF NOT EXISTS tenant_member_invitations (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    identifier_type identifier_kind NOT NULL,
    identifier_value varchar(256) NOT NULL,
    token_hash bytea NOT NULL,
    invited_by uuid NOT NULL,
    status tenant_member_invitation_status NOT NULL DEFAULT 'pending',
    expires_at timestamptz NOT NULL,
    accepted_by uuid,
    accepted_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_tenant_member_invitations__token_hash UNIQUE(token_hash),
    CONSTRAINT fk_tenant_member_invitations__tenants FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_member_invitations__invited_by FOREIGN KEY (tenant_id, invited_by) REFERENCES tenant_members(tenant_id, user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_member_invitations__accepted_by FOREIGN KEY (accepted_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE
);
COMMENT ON TABLE tenant_member_invitations IS '成员邀请';
COMMENT ON COLUMN tenant_member_invitations.id IS '邀请ID';
COMMENT ON COLUMN tenant_member_invitations.tenant_id IS '租户ID';
COMMENT ON COLUMN tenant_member_invitations.identifier_type IS '标识类型';
COMMENT ON COLUMN tenant_member_invitations.identifier_value IS '被邀请邮箱/手机号';
COMMENT ON COLUMN tenant_member_invitations.token_hash IS '一次性令牌哈希';
COMMENT ON COLUMN tenant_member_invitations.invited_by IS '邀请人';
COMMENT ON COLUMN tenant_member_invitations.status IS '邀请状态';
COMMENT ON COLUMN tenant_member_invitations.expires_at IS '过期时间';
COMMENT ON COLUMN tenant_member_invitations.accepted_by IS '接受人';
COMMENT ON COLUMN tenant_member_invitations.accepted_at IS '接受时间';
COMMENT ON COLUMN tenant_member_invitations.created_at IS '创建时间';

ALTER TABLE tenant_member_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_member_invitations FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_member_invitations
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);

CREATE INDEX ix_tenant_member_invitations__tenant_status ON tenant_member_invitations(tenant_id, status);
CREATE INDEX ix_tenant_member_invitations__identifier ON tenant_member_invitations(tenant_id, identifier_type, identifier_value);


CREATE TYPE tenant_workspace_status AS ENUM ('active', 'archived');
CREATE TABLE IF NOT EXISTS tenant_workspaces (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    code varchar(64) NOT NULL,
    name varchar(128) NOT NULL,
    workspace_type varchar(64),
    status tenant_workspace_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_tenant_workspaces__tenant_code UNIQUE (tenant_id, code),
    CONSTRAINT uq_tenant_workspaces__tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_tenant_workspaces__tenants FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE tenant_workspaces IS '工作区';
COMMENT ON COLUMN tenant_workspaces.id IS '工作区ID';
COMMENT ON COLUMN tenant_workspaces.tenant_id IS '所属租户';
COMMENT ON COLUMN tenant_workspaces.code IS '租户内编码';
COMMENT ON COLUMN tenant_workspaces.name IS '名称';
COMMENT ON COLUMN tenant_workspaces.workspace_type IS '工作区类型';
COMMENT ON COLUMN tenant_workspaces.status IS '工作区状态';
COMMENT ON COLUMN tenant_workspaces.created_at IS '创建时间';

ALTER TABLE tenant_workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_workspaces FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_workspaces
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_tenant_workspaces__tenant_status ON tenant_workspaces(tenant_id, status);
CREATE INDEX ix_tenant_workspaces__tenant_created_at ON tenant_workspaces(tenant_id, created_at);

ALTER TABLE tenant_members
    ADD CONSTRAINT fk_tenant_members__default_workspace
    FOREIGN KEY (tenant_id, default_workspace_id)
    REFERENCES tenant_workspaces(tenant_id, id) ON DELETE SET NULL (default_workspace_id) ON UPDATE CASCADE;



CREATE TYPE tenant_workspace_membership_status AS ENUM ('active', 'removed');
CREATE TABLE IF NOT EXISTS tenant_workspace_memberships (
    tenant_id uuid NOT NULL,
    workspace_id uuid NOT NULL,
    user_id uuid NOT NULL,
    status tenant_workspace_membership_status NOT NULL DEFAULT 'active',
    joined_at timestamptz NOT NULL,
    PRIMARY KEY (workspace_id, user_id),
    CONSTRAINT fk_tenant_workspace_memberships__workspace FOREIGN KEY (tenant_id, workspace_id) REFERENCES tenant_workspaces(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_workspace_memberships__member FOREIGN KEY (tenant_id, user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE tenant_workspace_memberships IS '成员工作区关系';
COMMENT ON COLUMN tenant_workspace_memberships.tenant_id IS '租户ID（冗余用于同租户约束）';
COMMENT ON COLUMN tenant_workspace_memberships.workspace_id IS '工作区ID';
COMMENT ON COLUMN tenant_workspace_memberships.user_id IS '用户ID';
COMMENT ON COLUMN tenant_workspace_memberships.status IS '成员状态';
COMMENT ON COLUMN tenant_workspace_memberships.joined_at IS '加入时间';

ALTER TABLE tenant_workspace_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_workspace_memberships FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_workspace_memberships
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_tenant_workspace_memberships__workspace ON tenant_workspace_memberships(tenant_id, workspace_id);
CREATE INDEX ix_tenant_workspace_memberships__member ON tenant_workspace_memberships(tenant_id, user_id);
CREATE INDEX ix_tenant_workspace_memberships__status ON tenant_workspace_memberships(tenant_id, status);



CREATE TYPE tenant_org_unit_type AS ENUM ('organization', 'division', 'department', 'team');
CREATE TYPE tenant_org_unit_status AS ENUM ('active', 'disabled');
CREATE TABLE IF NOT EXISTS tenant_org_units (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    parent_id uuid,
    unit_type tenant_org_unit_type NOT NULL,
    code varchar(64) NOT NULL,
    name varchar(128) NOT NULL,
    status tenant_org_unit_status NOT NULL DEFAULT 'active',
    manager_user_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_tenant_org_units__tenant_code UNIQUE (tenant_id, code),
    CONSTRAINT uq_tenant_org_units__tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_tenant_org_units__tenants FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_org_units__parent FOREIGN KEY (tenant_id, parent_id) REFERENCES tenant_org_units(tenant_id, id) ON DELETE SET NULL (parent_id) ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_org_units__manager FOREIGN KEY (tenant_id, manager_user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE SET NULL (manager_user_id) ON UPDATE CASCADE
);
COMMENT ON TABLE tenant_org_units IS '组织单元';
COMMENT ON COLUMN tenant_org_units.id IS '组织单元ID';
COMMENT ON COLUMN tenant_org_units.tenant_id IS '租户ID';
COMMENT ON COLUMN tenant_org_units.parent_id IS '父节点';
COMMENT ON COLUMN tenant_org_units.unit_type IS '组织类型';
COMMENT ON COLUMN tenant_org_units.code IS '编码';
COMMENT ON COLUMN tenant_org_units.name IS '名称';
COMMENT ON COLUMN tenant_org_units.status IS '组织状态';
COMMENT ON COLUMN tenant_org_units.manager_user_id IS '负责人';
COMMENT ON COLUMN tenant_org_units.created_at IS '创建时间';

ALTER TABLE tenant_org_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_org_units FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_org_units
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_tenant_org_units__parent ON tenant_org_units(tenant_id, parent_id);
CREATE INDEX ix_tenant_org_units__status ON tenant_org_units(tenant_id, status);
CREATE INDEX ix_tenant_org_units__created_at ON tenant_org_units(tenant_id, created_at);



CREATE TABLE IF NOT EXISTS tenant_org_unit_closures (
    tenant_id uuid NOT NULL,
    ancestor_id uuid NOT NULL,
    descendant_id uuid NOT NULL,
    depth integer NOT NULL,
    PRIMARY KEY (tenant_id, ancestor_id, descendant_id),
    CONSTRAINT ck_tenant_org_unit_closures__depth CHECK (depth >= 0),
    CONSTRAINT fk_tenant_org_unit_closures__ancestor FOREIGN KEY (tenant_id, ancestor_id) REFERENCES tenant_org_units(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_org_unit_closures__descendant FOREIGN KEY (tenant_id, descendant_id) REFERENCES tenant_org_units(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE tenant_org_unit_closures IS '组织树闭包表';
COMMENT ON COLUMN tenant_org_unit_closures.tenant_id IS '租户ID';
COMMENT ON COLUMN tenant_org_unit_closures.ancestor_id IS '祖先节点';
COMMENT ON COLUMN tenant_org_unit_closures.descendant_id IS '后代节点';
COMMENT ON COLUMN tenant_org_unit_closures.depth IS '相对深度';

ALTER TABLE tenant_org_unit_closures ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_org_unit_closures FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_org_unit_closures
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_tenant_org_unit_closures__descendant ON tenant_org_unit_closures(tenant_id, descendant_id);
CREATE INDEX ix_tenant_org_unit_closures__ancestor ON tenant_org_unit_closures(tenant_id, ancestor_id);



CREATE TYPE tenant_member_org_unit_relation_type AS ENUM ('member', 'manager');
CREATE TABLE IF NOT EXISTS tenant_member_org_units (
    tenant_id uuid NOT NULL,
    user_id uuid NOT NULL,
    org_unit_id uuid NOT NULL,
    relation_type tenant_member_org_unit_relation_type NOT NULL DEFAULT 'member',
    is_primary boolean NOT NULL DEFAULT false,
    joined_at timestamptz NOT NULL,
    PRIMARY KEY (tenant_id, user_id, org_unit_id),
    CONSTRAINT fk_tenant_member_org_units__member FOREIGN KEY (tenant_id, user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_member_org_units__org_unit FOREIGN KEY (tenant_id, org_unit_id) REFERENCES tenant_org_units(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE UNIQUE INDEX uq_tenant_member_org_units__primary
    ON tenant_member_org_units(tenant_id, user_id)
    WHERE is_primary = true;
COMMENT ON TABLE tenant_member_org_units IS '成员组织归属';
COMMENT ON COLUMN tenant_member_org_units.tenant_id IS '租户ID';
COMMENT ON COLUMN tenant_member_org_units.user_id IS '用户ID';
COMMENT ON COLUMN tenant_member_org_units.org_unit_id IS '组织单元ID';
COMMENT ON COLUMN tenant_member_org_units.relation_type IS '关系类型';
COMMENT ON COLUMN tenant_member_org_units.is_primary IS '是否主组织';
COMMENT ON COLUMN tenant_member_org_units.joined_at IS '加入时间';

ALTER TABLE tenant_member_org_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_member_org_units FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_member_org_units
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_tenant_member_org_units__org_unit ON tenant_member_org_units(tenant_id, org_unit_id);
CREATE INDEX ix_tenant_member_org_units__relation_type ON tenant_member_org_units(tenant_id, relation_type);



CREATE TYPE permission_realm AS ENUM ('tenant', 'platform');
CREATE TYPE permission_risk_level AS ENUM ('normal', 'sensitive', 'critical');
CREATE TYPE permission_status AS ENUM ('active', 'deprecated');
CREATE TYPE tenant_role_template_status AS ENUM ('active', 'deprecated');
CREATE TYPE tenant_role_status AS ENUM ('active', 'disabled');
CREATE TYPE tenant_policy_rule_status AS ENUM ('active', 'disabled');

CREATE TABLE IF NOT EXISTS global_authz_versions (
    id smallint NOT NULL PRIMARY KEY,
    permission_catalog_version bigint NOT NULL DEFAULT 1,
    platform_authz_version bigint NOT NULL DEFAULT 1,
    CONSTRAINT ck_global_authz_versions__singleton CHECK (id = 1)
);
COMMENT ON TABLE global_authz_versions IS '全局权限版本状态';
COMMENT ON COLUMN global_authz_versions.permission_catalog_version IS '权限定义目录版本';
COMMENT ON COLUMN global_authz_versions.platform_authz_version IS '平台角色权限全局版本';

INSERT INTO global_authz_versions (id, permission_catalog_version, platform_authz_version)
VALUES (1, 1, 1);

CREATE TABLE IF NOT EXISTS permission_definitions (
    code varchar(128) NOT NULL PRIMARY KEY,
    realm permission_realm NOT NULL,
    module varchar(64) NOT NULL,
    resource varchar(64) NOT NULL,
    action varchar(64) NOT NULL,
    name varchar(128) NOT NULL,
    description text,
    risk_level permission_risk_level NOT NULL DEFAULT 'normal',
    supports_data_scope boolean NOT NULL DEFAULT false,
    status permission_status NOT NULL DEFAULT 'active',
    registered_version varchar(32),
    created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE permission_definitions IS '原子权限定义';
COMMENT ON COLUMN permission_definitions.code IS '权限编码';
COMMENT ON COLUMN permission_definitions.realm IS '权限域';
COMMENT ON COLUMN permission_definitions.module IS '模块';
COMMENT ON COLUMN permission_definitions.resource IS '资源';
COMMENT ON COLUMN permission_definitions.action IS '操作';
COMMENT ON COLUMN permission_definitions.name IS '展示名称';
COMMENT ON COLUMN permission_definitions.description IS '描述';
COMMENT ON COLUMN permission_definitions.risk_level IS '风险等级';
COMMENT ON COLUMN permission_definitions.supports_data_scope IS '是否支持数据范围';
COMMENT ON COLUMN permission_definitions.status IS '状态';
COMMENT ON COLUMN permission_definitions.registered_version IS '注册版本';
COMMENT ON COLUMN permission_definitions.created_at IS '创建时间';

CREATE INDEX ix_permission_definitions__module_resource ON permission_definitions(module, resource);
CREATE INDEX ix_permission_definitions__realm ON permission_definitions(realm);



CREATE TABLE IF NOT EXISTS tenant_role_templates (
    id uuid NOT NULL PRIMARY KEY,
    code varchar(64) NOT NULL,
    name varchar(128) NOT NULL,
    description text,
    is_system boolean NOT NULL DEFAULT false,
    version bigint NOT NULL DEFAULT 1,
    status tenant_role_template_status NOT NULL DEFAULT 'active',
    CONSTRAINT uq_tenant_role_templates__code UNIQUE (code)
);
COMMENT ON TABLE tenant_role_templates IS '租户角色模板';
COMMENT ON COLUMN tenant_role_templates.id IS '模板ID';
COMMENT ON COLUMN tenant_role_templates.code IS '模板编码';
COMMENT ON COLUMN tenant_role_templates.name IS '模板名称';
COMMENT ON COLUMN tenant_role_templates.description IS '描述';
COMMENT ON COLUMN tenant_role_templates.is_system IS '是否系统模板';
COMMENT ON COLUMN tenant_role_templates.version IS '模板版本';
COMMENT ON COLUMN tenant_role_templates.status IS '状态';

CREATE TABLE IF NOT EXISTS tenant_role_template_permissions (
    role_template_id uuid NOT NULL,
    permission_code varchar(128) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (role_template_id, permission_code),
    CONSTRAINT fk_tenant_role_template_permissions__template FOREIGN KEY (role_template_id) REFERENCES tenant_role_templates(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_role_template_permissions__permission FOREIGN KEY (permission_code) REFERENCES permission_definitions(code) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE tenant_role_template_permissions IS '角色模板权限';
COMMENT ON COLUMN tenant_role_template_permissions.role_template_id IS '角色模板ID';
COMMENT ON COLUMN tenant_role_template_permissions.permission_code IS '权限编码';
COMMENT ON COLUMN tenant_role_template_permissions.created_at IS '创建时间';



CREATE TYPE role_type AS ENUM ('system', 'custom');
CREATE TABLE IF NOT EXISTS tenant_roles (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    source_template_id uuid,
    code varchar(64) NOT NULL,
    name varchar(128) NOT NULL,
    description text,
    role_type role_type NOT NULL,
    status tenant_role_status NOT NULL DEFAULT 'active',
    version bigint NOT NULL DEFAULT 1,
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT uq_tenant_roles__tenant_code UNIQUE (tenant_id, code),
    CONSTRAINT uq_tenant_roles__tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_tenant_roles__tenants FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_roles__source_template FOREIGN KEY (source_template_id) REFERENCES tenant_role_templates(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_roles__created_by FOREIGN KEY (tenant_id, created_by) REFERENCES tenant_members(tenant_id, user_id) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE tenant_roles IS '租户角色';
COMMENT ON COLUMN tenant_roles.id IS '角色ID';
COMMENT ON COLUMN tenant_roles.tenant_id IS '所属租户';
COMMENT ON COLUMN tenant_roles.source_template_id IS '来源模板';
COMMENT ON COLUMN tenant_roles.code IS '租户内角色编码';
COMMENT ON COLUMN tenant_roles.name IS '角色名称';
COMMENT ON COLUMN tenant_roles.description IS '描述';
COMMENT ON COLUMN tenant_roles.role_type IS '角色类型';
COMMENT ON COLUMN tenant_roles.status IS '状态';
COMMENT ON COLUMN tenant_roles.version IS '乐观锁版本';
COMMENT ON COLUMN tenant_roles.created_by IS '创建人';
COMMENT ON COLUMN tenant_roles.created_at IS '创建时间';
COMMENT ON COLUMN tenant_roles.updated_at IS '更新时间';

ALTER TABLE tenant_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_roles FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_roles
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_tenant_roles__tenant_status ON tenant_roles(tenant_id, status);
CREATE INDEX ix_tenant_roles__tenant_role_type ON tenant_roles(tenant_id, role_type);
CREATE INDEX ix_tenant_roles__tenant_created_at ON tenant_roles(tenant_id, created_at);



CREATE TABLE IF NOT EXISTS tenant_role_permissions (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    role_id uuid NOT NULL,
    permission_code varchar(128) NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_tenant_role_permissions__role_permission UNIQUE (role_id, permission_code),
    CONSTRAINT uq_tenant_role_permissions__tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_tenant_role_permissions__role FOREIGN KEY (tenant_id, role_id) REFERENCES tenant_roles(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_role_permissions__permission FOREIGN KEY (permission_code) REFERENCES permission_definitions(code) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_role_permissions__created_by FOREIGN KEY (tenant_id, created_by) REFERENCES tenant_members(tenant_id, user_id) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE tenant_role_permissions IS '角色权限授权';
COMMENT ON COLUMN tenant_role_permissions.id IS '授权ID';
COMMENT ON COLUMN tenant_role_permissions.tenant_id IS '租户ID';
COMMENT ON COLUMN tenant_role_permissions.role_id IS '角色ID';
COMMENT ON COLUMN tenant_role_permissions.permission_code IS '原子权限编码';
COMMENT ON COLUMN tenant_role_permissions.created_by IS '授权人';
COMMENT ON COLUMN tenant_role_permissions.created_at IS '授权时间';

ALTER TABLE tenant_role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_role_permissions FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_role_permissions
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_tenant_role_permissions__role ON tenant_role_permissions(tenant_id, role_id);



CREATE TYPE permission_scope_type AS ENUM ('self', 'department', 'department_and_children', 'workspace', 'tenant', 'custom');
CREATE TABLE IF NOT EXISTS tenant_permission_scopes (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    role_permission_id uuid NOT NULL,
    scope_type permission_scope_type NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_tenant_permission_scopes__tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_tenant_permission_scopes__role_permission FOREIGN KEY (tenant_id, role_permission_id) REFERENCES tenant_role_permissions(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE tenant_permission_scopes IS '权限的数据范围';
COMMENT ON COLUMN tenant_permission_scopes.id IS '范围ID';
COMMENT ON COLUMN tenant_permission_scopes.tenant_id IS '租户ID';
COMMENT ON COLUMN tenant_permission_scopes.role_permission_id IS '所属角色权限ID';
COMMENT ON COLUMN tenant_permission_scopes.scope_type IS '数据范围类型';
COMMENT ON COLUMN tenant_permission_scopes.created_at IS '创建时间';

ALTER TABLE tenant_permission_scopes ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_permission_scopes FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_permission_scopes
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_tenant_permission_scopes__role_permission ON tenant_permission_scopes(tenant_id, role_permission_id);



CREATE TYPE permission_scope_target_type AS ENUM ('member', 'org_unit', 'workspace');
CREATE TABLE IF NOT EXISTS tenant_permission_scope_targets (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    scope_id uuid NOT NULL,
    target_type permission_scope_target_type NOT NULL,
    target_user_id uuid,
    target_org_unit_id uuid,
    target_workspace_id uuid,
    CONSTRAINT uq_tenant_permission_scope_targets__tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_tenant_permission_scope_targets__scope FOREIGN KEY (tenant_id, scope_id) REFERENCES tenant_permission_scopes(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_permission_scope_targets__member FOREIGN KEY (tenant_id, target_user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_permission_scope_targets__org_unit FOREIGN KEY (tenant_id, target_org_unit_id) REFERENCES tenant_org_units(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_permission_scope_targets__workspace FOREIGN KEY (tenant_id, target_workspace_id) REFERENCES tenant_workspaces(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_tenant_permission_scope_targets__target CHECK (
        CASE target_type
            WHEN 'member'    THEN target_user_id IS NOT NULL AND target_org_unit_id IS NULL AND target_workspace_id IS NULL
            WHEN 'org_unit'  THEN target_user_id IS NULL AND target_org_unit_id IS NOT NULL AND target_workspace_id IS NULL
            WHEN 'workspace' THEN target_user_id IS NULL AND target_org_unit_id IS NULL AND target_workspace_id IS NOT NULL
        END
    )
);
COMMENT ON TABLE tenant_permission_scope_targets IS '自定义范围目标';
COMMENT ON COLUMN tenant_permission_scope_targets.id IS '目标ID';
COMMENT ON COLUMN tenant_permission_scope_targets.tenant_id IS '租户ID';
COMMENT ON COLUMN tenant_permission_scope_targets.scope_id IS '所属数据范围ID';
COMMENT ON COLUMN tenant_permission_scope_targets.target_type IS '目标类型';
COMMENT ON COLUMN tenant_permission_scope_targets.target_user_id IS '指定用户';
COMMENT ON COLUMN tenant_permission_scope_targets.target_org_unit_id IS '指定组织';
COMMENT ON COLUMN tenant_permission_scope_targets.target_workspace_id IS '指定工作区';

ALTER TABLE tenant_permission_scope_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_permission_scope_targets FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_permission_scope_targets
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_tenant_permission_scope_targets__scope ON tenant_permission_scope_targets(tenant_id, scope_id);



CREATE TYPE role_binding_scope_type AS ENUM ('tenant', 'workspace', 'org_unit');
CREATE TABLE IF NOT EXISTS tenant_member_role_bindings (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role_id uuid NOT NULL,
    binding_scope role_binding_scope_type NOT NULL,
    workspace_id uuid,
    org_unit_id uuid,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    granted_by uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_tenant_member_role_bindings__tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_tenant_member_role_bindings__member FOREIGN KEY (tenant_id, user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_member_role_bindings__role FOREIGN KEY (tenant_id, role_id) REFERENCES tenant_roles(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_member_role_bindings__workspace FOREIGN KEY (tenant_id, workspace_id) REFERENCES tenant_workspaces(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_member_role_bindings__org_unit FOREIGN KEY (tenant_id, org_unit_id) REFERENCES tenant_org_units(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_member_role_bindings__granted_by FOREIGN KEY (tenant_id, granted_by) REFERENCES tenant_members(tenant_id, user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_tenant_member_role_bindings__scope CHECK (
        CASE binding_scope
            WHEN 'tenant'    THEN workspace_id IS NULL AND org_unit_id IS NULL
            WHEN 'workspace' THEN workspace_id IS NOT NULL AND org_unit_id IS NULL
            WHEN 'org_unit'  THEN workspace_id IS NULL AND org_unit_id IS NOT NULL
        END
    ),
    CONSTRAINT ck_tenant_member_role_bindings__period CHECK (valid_until IS NULL OR valid_until > valid_from)
);
COMMENT ON TABLE tenant_member_role_bindings IS '成员角色绑定';
COMMENT ON COLUMN tenant_member_role_bindings.id IS '绑定ID';
COMMENT ON COLUMN tenant_member_role_bindings.tenant_id IS '租户ID';
COMMENT ON COLUMN tenant_member_role_bindings.user_id IS '用户ID';
COMMENT ON COLUMN tenant_member_role_bindings.role_id IS '角色ID';
COMMENT ON COLUMN tenant_member_role_bindings.binding_scope IS '绑定范围';
COMMENT ON COLUMN tenant_member_role_bindings.workspace_id IS '工作区范围';
COMMENT ON COLUMN tenant_member_role_bindings.org_unit_id IS '组织范围';
COMMENT ON COLUMN tenant_member_role_bindings.valid_from IS '生效时间';
COMMENT ON COLUMN tenant_member_role_bindings.valid_until IS '失效时间';
COMMENT ON COLUMN tenant_member_role_bindings.granted_by IS '授权人';
COMMENT ON COLUMN tenant_member_role_bindings.created_at IS '创建时间';

ALTER TABLE tenant_member_role_bindings ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_member_role_bindings FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_member_role_bindings
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_tenant_member_role_bindings__member ON tenant_member_role_bindings(tenant_id, user_id);
CREATE INDEX ix_tenant_member_role_bindings__role ON tenant_member_role_bindings(tenant_id, role_id);
CREATE INDEX ix_tenant_member_role_bindings__valid_period ON tenant_member_role_bindings(tenant_id, valid_from, valid_until) WHERE valid_until IS NOT NULL;
CREATE INDEX ix_tenant_member_role_bindings__scope ON tenant_member_role_bindings(tenant_id, binding_scope);



CREATE TYPE policy_subject_type AS ENUM ('role', 'member');
CREATE TYPE policy_effect AS ENUM ('deny', 'constrain');
CREATE TABLE IF NOT EXISTS tenant_policy_rules (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    subject_type policy_subject_type NOT NULL,
    role_id uuid,
    subject_user_id uuid,
    resource varchar(128) NOT NULL,
    action varchar(64) NOT NULL,
    effect policy_effect NOT NULL,
    condition jsonb,
    priority integer NOT NULL DEFAULT 0,
    status tenant_policy_rule_status NOT NULL DEFAULT 'active',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    CONSTRAINT fk_tenant_policy_rules__tenants FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_policy_rules__role FOREIGN KEY (tenant_id, role_id) REFERENCES tenant_roles(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_policy_rules__member FOREIGN KEY (tenant_id, subject_user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_tenant_policy_rules__subject CHECK (
        CASE subject_type
            WHEN 'role'   THEN role_id IS NOT NULL AND subject_user_id IS NULL
            WHEN 'member' THEN role_id IS NULL AND subject_user_id IS NOT NULL
        END
    )
);
COMMENT ON TABLE tenant_policy_rules IS '受控ABAC策略';
COMMENT ON COLUMN tenant_policy_rules.id IS '策略ID';
COMMENT ON COLUMN tenant_policy_rules.tenant_id IS '租户ID';
COMMENT ON COLUMN tenant_policy_rules.subject_type IS '主体类型';
COMMENT ON COLUMN tenant_policy_rules.role_id IS '角色主体';
COMMENT ON COLUMN tenant_policy_rules.subject_user_id IS '成员主体用户ID';
COMMENT ON COLUMN tenant_policy_rules.resource IS '资源';
COMMENT ON COLUMN tenant_policy_rules.action IS '操作';
COMMENT ON COLUMN tenant_policy_rules.effect IS '效果';
COMMENT ON COLUMN tenant_policy_rules.condition IS '受控条件';
COMMENT ON COLUMN tenant_policy_rules.priority IS '优先级';
COMMENT ON COLUMN tenant_policy_rules.status IS '状态';
COMMENT ON COLUMN tenant_policy_rules.valid_from IS '生效时间';
COMMENT ON COLUMN tenant_policy_rules.valid_until IS '失效时间';

ALTER TABLE tenant_policy_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_policy_rules FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_policy_rules
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_tenant_policy_rules__status ON tenant_policy_rules(tenant_id, status);
CREATE INDEX ix_tenant_policy_rules__resource_action ON tenant_policy_rules(tenant_id, resource, action);
CREATE INDEX ix_tenant_policy_rules__priority ON tenant_policy_rules(tenant_id, priority DESC);



CREATE TYPE platform_user_status AS ENUM ('active', 'disabled');
CREATE TYPE platform_role_status AS ENUM ('active', 'disabled');
CREATE TABLE IF NOT EXISTS platform_users (
    user_id uuid NOT NULL PRIMARY KEY,
    status platform_user_status NOT NULL DEFAULT 'active',
    authz_version bigint NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    disabled_at timestamptz,
    CONSTRAINT fk_platform_users__users FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE platform_users IS '管理平台用户';
COMMENT ON COLUMN platform_users.user_id IS '平台用户ID';
COMMENT ON COLUMN platform_users.status IS '平台用户状态';
COMMENT ON COLUMN platform_users.authz_version IS '平台用户权限版本';
COMMENT ON COLUMN platform_users.created_at IS '创建时间';
COMMENT ON COLUMN platform_users.updated_at IS '更新时间';
COMMENT ON COLUMN platform_users.disabled_at IS '禁用时间';

CREATE INDEX ix_platform_users__status ON platform_users(status);



CREATE TABLE IF NOT EXISTS platform_roles (
    id uuid NOT NULL PRIMARY KEY,
    code varchar(64) NOT NULL,
    name varchar(128) NOT NULL,
    description text,
    role_type role_type NOT NULL DEFAULT 'custom',
    status platform_role_status NOT NULL DEFAULT 'active',
    version bigint NOT NULL DEFAULT 1,
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT uq_platform_roles__code UNIQUE (code),
    CONSTRAINT fk_platform_roles__created_by FOREIGN KEY (created_by) REFERENCES platform_users(user_id) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE platform_roles IS '平台角色';
COMMENT ON COLUMN platform_roles.id IS '平台角色ID';
COMMENT ON COLUMN platform_roles.code IS '角色编码';
COMMENT ON COLUMN platform_roles.name IS '角色名称';
COMMENT ON COLUMN platform_roles.description IS '描述';
COMMENT ON COLUMN platform_roles.role_type IS '角色类型';
COMMENT ON COLUMN platform_roles.status IS '状态';
COMMENT ON COLUMN platform_roles.version IS '乐观锁版本';
COMMENT ON COLUMN platform_roles.created_by IS '创建人';
COMMENT ON COLUMN platform_roles.created_at IS '创建时间';
COMMENT ON COLUMN platform_roles.updated_at IS '更新时间';



CREATE TABLE IF NOT EXISTS platform_role_permissions (
    id uuid NOT NULL PRIMARY KEY,
    platform_role_id uuid NOT NULL,
    permission_code varchar(128) NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_platform_role_permissions__role_permission UNIQUE (platform_role_id, permission_code),
    CONSTRAINT fk_platform_role_permissions__role FOREIGN KEY (platform_role_id) REFERENCES platform_roles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_platform_role_permissions__permission FOREIGN KEY (permission_code) REFERENCES permission_definitions(code) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_platform_role_permissions__created_by FOREIGN KEY (created_by) REFERENCES platform_users(user_id) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE platform_role_permissions IS '平台角色权限';
COMMENT ON COLUMN platform_role_permissions.id IS '授权ID';
COMMENT ON COLUMN platform_role_permissions.platform_role_id IS '平台角色ID';
COMMENT ON COLUMN platform_role_permissions.permission_code IS '权限编码';
COMMENT ON COLUMN platform_role_permissions.created_by IS '授权人';
COMMENT ON COLUMN platform_role_permissions.created_at IS '授权时间';

CREATE INDEX ix_platform_role_permissions__role ON platform_role_permissions(platform_role_id);



CREATE TABLE IF NOT EXISTS platform_user_role_bindings (
    id uuid NOT NULL PRIMARY KEY,
    user_id uuid NOT NULL,
    platform_role_id uuid NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    granted_by uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_platform_user_role_bindings__user FOREIGN KEY (user_id) REFERENCES platform_users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_platform_user_role_bindings__role FOREIGN KEY (platform_role_id) REFERENCES platform_roles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_platform_user_role_bindings__granted_by FOREIGN KEY (granted_by) REFERENCES platform_users(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_platform_user_role_bindings__valid_period CHECK (valid_until IS NULL OR valid_until > valid_from)
);
COMMENT ON TABLE platform_user_role_bindings IS '平台用户角色绑定';
COMMENT ON COLUMN platform_user_role_bindings.id IS '绑定ID';
COMMENT ON COLUMN platform_user_role_bindings.user_id IS '平台人员';
COMMENT ON COLUMN platform_user_role_bindings.platform_role_id IS '平台角色ID';
COMMENT ON COLUMN platform_user_role_bindings.valid_from IS '生效时间';
COMMENT ON COLUMN platform_user_role_bindings.valid_until IS '失效时间';
COMMENT ON COLUMN platform_user_role_bindings.granted_by IS '授权人';
COMMENT ON COLUMN platform_user_role_bindings.created_at IS '创建时间';

CREATE INDEX ix_platform_user_role_bindings__user ON platform_user_role_bindings(user_id);
CREATE INDEX ix_platform_user_role_bindings__role ON platform_user_role_bindings(platform_role_id);
CREATE INDEX ix_platform_user_role_bindings__valid_period ON platform_user_role_bindings(user_id, valid_from, valid_until) WHERE valid_until IS NOT NULL;



CREATE TYPE access_mode AS ENUM ('readonly', 'limited');
CREATE TABLE IF NOT EXISTS platform_support_access_sessions (
    id uuid NOT NULL PRIMARY KEY,
    platform_user_id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    reason text NOT NULL,
    ticket_no varchar(64),
    access_mode access_mode NOT NULL DEFAULT 'readonly',
    allowed_permissions jsonb,
    approved_by uuid,
    started_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    CONSTRAINT fk_platform_support_access_sessions__platform_user FOREIGN KEY (platform_user_id) REFERENCES platform_users(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_platform_support_access_sessions__tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_platform_support_access_sessions__approved_by FOREIGN KEY (approved_by) REFERENCES platform_users(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_platform_support_access_sessions__period CHECK (expires_at > started_at)
);
COMMENT ON TABLE platform_support_access_sessions IS '租户代操作会话';
COMMENT ON COLUMN platform_support_access_sessions.id IS '代操作会话ID';
COMMENT ON COLUMN platform_support_access_sessions.platform_user_id IS '平台操作人';
COMMENT ON COLUMN platform_support_access_sessions.tenant_id IS '目标租户';
COMMENT ON COLUMN platform_support_access_sessions.reason IS '访问原因';
COMMENT ON COLUMN platform_support_access_sessions.ticket_no IS '工单号';
COMMENT ON COLUMN platform_support_access_sessions.access_mode IS '访问模式';
COMMENT ON COLUMN platform_support_access_sessions.allowed_permissions IS '临时权限上限';
COMMENT ON COLUMN platform_support_access_sessions.approved_by IS '审批人';
COMMENT ON COLUMN platform_support_access_sessions.started_at IS '开始时间';
COMMENT ON COLUMN platform_support_access_sessions.expires_at IS '过期时间';
COMMENT ON COLUMN platform_support_access_sessions.revoked_at IS '撤销时间';

CREATE INDEX ix_platform_support_access_sessions__platform_user ON platform_support_access_sessions(platform_user_id);
CREATE INDEX ix_platform_support_access_sessions__tenant ON platform_support_access_sessions(tenant_id);



CREATE TYPE tenant_service_account_status AS ENUM ('active', 'disabled');
CREATE TABLE IF NOT EXISTS tenant_service_accounts (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    name varchar(128) NOT NULL,
    description text,
    status tenant_service_account_status NOT NULL DEFAULT 'active',
    authz_version bigint NOT NULL DEFAULT 1,
    created_by uuid NOT NULL,
    last_used_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_tenant_service_accounts__tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_tenant_service_accounts__tenants FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_service_accounts__created_by FOREIGN KEY (tenant_id, created_by) REFERENCES tenant_members(tenant_id, user_id) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE tenant_service_accounts IS '服务账号';
COMMENT ON COLUMN tenant_service_accounts.id IS '服务账号ID';
COMMENT ON COLUMN tenant_service_accounts.tenant_id IS '所属租户';
COMMENT ON COLUMN tenant_service_accounts.name IS '名称';
COMMENT ON COLUMN tenant_service_accounts.description IS '用途';
COMMENT ON COLUMN tenant_service_accounts.status IS '状态';
COMMENT ON COLUMN tenant_service_accounts.authz_version IS '权限版本';
COMMENT ON COLUMN tenant_service_accounts.created_by IS '创建人';
COMMENT ON COLUMN tenant_service_accounts.last_used_at IS '最近使用时间';
COMMENT ON COLUMN tenant_service_accounts.created_at IS '创建时间';

ALTER TABLE tenant_service_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_service_accounts FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_service_accounts
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_tenant_service_accounts__status ON tenant_service_accounts(tenant_id, status);
CREATE INDEX ix_tenant_service_accounts__created_at ON tenant_service_accounts(tenant_id, created_at);



CREATE TABLE IF NOT EXISTS tenant_service_account_role_bindings (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    service_account_id uuid NOT NULL,
    role_id uuid NOT NULL,
    binding_scope role_binding_scope_type NOT NULL,
    workspace_id uuid,
    org_unit_id uuid,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    granted_by uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_tenant_service_account_role_bindings__tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_tenant_service_account_role_bindings__account FOREIGN KEY (tenant_id, service_account_id) REFERENCES tenant_service_accounts(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_service_account_role_bindings__role FOREIGN KEY (tenant_id, role_id) REFERENCES tenant_roles(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_service_account_role_bindings__workspace FOREIGN KEY (tenant_id, workspace_id) REFERENCES tenant_workspaces(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_service_account_role_bindings__org_unit FOREIGN KEY (tenant_id, org_unit_id) REFERENCES tenant_org_units(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_service_account_role_bindings__granted_by FOREIGN KEY (tenant_id, granted_by) REFERENCES tenant_members(tenant_id, user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_tenant_service_account_role_bindings__scope CHECK (
        CASE binding_scope
            WHEN 'tenant'    THEN workspace_id IS NULL AND org_unit_id IS NULL
            WHEN 'workspace' THEN workspace_id IS NOT NULL AND org_unit_id IS NULL
            WHEN 'org_unit'  THEN workspace_id IS NULL AND org_unit_id IS NOT NULL
        END
    ),
    CONSTRAINT ck_tenant_service_account_role_bindings__period CHECK (valid_until IS NULL OR valid_until > valid_from)
);
COMMENT ON TABLE tenant_service_account_role_bindings IS '服务账号角色绑定';
COMMENT ON COLUMN tenant_service_account_role_bindings.id IS '绑定ID';
COMMENT ON COLUMN tenant_service_account_role_bindings.tenant_id IS '租户ID';
COMMENT ON COLUMN tenant_service_account_role_bindings.service_account_id IS '服务账号ID';
COMMENT ON COLUMN tenant_service_account_role_bindings.role_id IS '角色ID';
COMMENT ON COLUMN tenant_service_account_role_bindings.binding_scope IS '绑定范围';
COMMENT ON COLUMN tenant_service_account_role_bindings.workspace_id IS '工作区范围';
COMMENT ON COLUMN tenant_service_account_role_bindings.org_unit_id IS '组织范围';
COMMENT ON COLUMN tenant_service_account_role_bindings.valid_from IS '生效时间';
COMMENT ON COLUMN tenant_service_account_role_bindings.valid_until IS '失效时间';
COMMENT ON COLUMN tenant_service_account_role_bindings.granted_by IS '授权人';
COMMENT ON COLUMN tenant_service_account_role_bindings.created_at IS '创建时间';

ALTER TABLE tenant_service_account_role_bindings ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_service_account_role_bindings FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_service_account_role_bindings
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_tenant_service_account_role_bindings__account ON tenant_service_account_role_bindings(tenant_id, service_account_id);
CREATE INDEX ix_tenant_service_account_role_bindings__role ON tenant_service_account_role_bindings(tenant_id, role_id);
CREATE INDEX ix_tenant_service_account_role_bindings__valid_period ON tenant_service_account_role_bindings(tenant_id, valid_from, valid_until) WHERE valid_until IS NOT NULL;



CREATE TYPE service_account_api_key_status AS ENUM ('active', 'revoked', 'expired');
CREATE TABLE IF NOT EXISTS service_account_api_keys (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    service_account_id uuid NOT NULL,
    name varchar(128) NOT NULL,
    key_prefix varchar(32) NOT NULL,
    secret_hash bytea NOT NULL,
    status service_account_api_key_status NOT NULL DEFAULT 'active',
    allowed_cidrs cidr[],
    expires_at timestamptz,
    last_used_at timestamptz,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_service_account_api_keys__tenant_prefix UNIQUE (tenant_id, key_prefix),
    CONSTRAINT fk_service_account_api_keys__tenants FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_service_account_api_keys__account FOREIGN KEY (tenant_id, service_account_id) REFERENCES tenant_service_accounts(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE service_account_api_keys IS 'API密钥';
COMMENT ON COLUMN service_account_api_keys.id IS 'Key ID';
COMMENT ON COLUMN service_account_api_keys.tenant_id IS '租户ID';
COMMENT ON COLUMN service_account_api_keys.service_account_id IS '服务账号ID';
COMMENT ON COLUMN service_account_api_keys.name IS '名称';
COMMENT ON COLUMN service_account_api_keys.key_prefix IS '密钥前缀';
COMMENT ON COLUMN service_account_api_keys.secret_hash IS '密钥哈希';
COMMENT ON COLUMN service_account_api_keys.status IS '状态';
COMMENT ON COLUMN service_account_api_keys.allowed_cidrs IS 'IP限制';
COMMENT ON COLUMN service_account_api_keys.expires_at IS '过期时间';
COMMENT ON COLUMN service_account_api_keys.last_used_at IS '最近使用时间';
COMMENT ON COLUMN service_account_api_keys.revoked_at IS '撤销时间';
COMMENT ON COLUMN service_account_api_keys.created_at IS '创建时间';

ALTER TABLE service_account_api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_account_api_keys FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON service_account_api_keys
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_service_account_api_keys__account ON service_account_api_keys(tenant_id, service_account_id);
CREATE INDEX ix_service_account_api_keys__status ON service_account_api_keys(tenant_id, status);



CREATE TYPE oauth_client_type AS ENUM ('public', 'confidential');
CREATE TYPE oauth_client_status AS ENUM ('active', 'disabled');
CREATE TYPE oauth_grant_status AS ENUM ('active', 'revoked');
CREATE TABLE IF NOT EXISTS oauth_clients (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    name varchar(128) NOT NULL,
    client_type oauth_client_type NOT NULL DEFAULT 'confidential',
    client_secret_hash bytea,
    redirect_uris text[] NOT NULL,
    allowed_scopes text[],
    status oauth_client_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT fk_oauth_clients__tenants FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE oauth_clients IS 'OAuth应用';
COMMENT ON COLUMN oauth_clients.id IS 'Client ID';
COMMENT ON COLUMN oauth_clients.tenant_id IS '创建应用的租户';
COMMENT ON COLUMN oauth_clients.name IS '应用名称';
COMMENT ON COLUMN oauth_clients.client_type IS '客户端类型';
COMMENT ON COLUMN oauth_clients.client_secret_hash IS '机密客户端凭据';
COMMENT ON COLUMN oauth_clients.redirect_uris IS '精确回调地址';
COMMENT ON COLUMN oauth_clients.allowed_scopes IS '可申请权限上限';
COMMENT ON COLUMN oauth_clients.status IS '状态';
COMMENT ON COLUMN oauth_clients.created_at IS '创建时间';
COMMENT ON COLUMN oauth_clients.updated_at IS '更新时间';

ALTER TABLE oauth_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE oauth_clients FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON oauth_clients
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);

CREATE INDEX ix_oauth_clients__tenant_status ON oauth_clients(tenant_id, status);



CREATE TABLE IF NOT EXISTS oauth_grants (
    id uuid NOT NULL PRIMARY KEY,
    client_id uuid NOT NULL,
    user_id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    granted_scopes text[],
    status oauth_grant_status NOT NULL DEFAULT 'active',
    granted_at timestamptz NOT NULL,
    expires_at timestamptz,
    revoked_at timestamptz,
    CONSTRAINT fk_oauth_grants__client FOREIGN KEY (client_id) REFERENCES oauth_clients(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_oauth_grants__member FOREIGN KEY (tenant_id, user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE oauth_grants IS 'OAuth授权记录';
COMMENT ON COLUMN oauth_grants.id IS '授权ID';
COMMENT ON COLUMN oauth_grants.client_id IS 'OAuth应用ID';
COMMENT ON COLUMN oauth_grants.user_id IS '用户ID';
COMMENT ON COLUMN oauth_grants.tenant_id IS '授权租户';
COMMENT ON COLUMN oauth_grants.granted_scopes IS '用户同意的范围';
COMMENT ON COLUMN oauth_grants.status IS '状态';
COMMENT ON COLUMN oauth_grants.granted_at IS '授权时间';
COMMENT ON COLUMN oauth_grants.expires_at IS '到期时间';
COMMENT ON COLUMN oauth_grants.revoked_at IS '撤销时间';

ALTER TABLE oauth_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE oauth_grants FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON oauth_grants
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_oauth_grants__client ON oauth_grants(tenant_id, client_id);
CREATE INDEX ix_oauth_grants__user ON oauth_grants(tenant_id, user_id);
CREATE INDEX ix_oauth_grants__status ON oauth_grants(tenant_id, status);



CREATE TYPE feature_value_type AS ENUM ('boolean', 'integer', 'bytes', 'count', 'json');
CREATE TYPE feature_definition_status AS ENUM ('active', 'deprecated');
CREATE TABLE IF NOT EXISTS feature_definitions (
    code text NOT NULL PRIMARY KEY,
    name varchar(128) NOT NULL,
    description text,
    category varchar(64),
    value_type feature_value_type NOT NULL DEFAULT 'boolean',
    default_value jsonb,
    value_schema jsonb,
    is_metered boolean NOT NULL DEFAULT false,
    status feature_definition_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);
COMMENT ON TABLE feature_definitions IS '功能定义';
COMMENT ON COLUMN feature_definitions.code IS '功能编码';
COMMENT ON COLUMN feature_definitions.name IS '展示名称';
COMMENT ON COLUMN feature_definitions.description IS '功能说明';
COMMENT ON COLUMN feature_definitions.category IS '分类';
COMMENT ON COLUMN feature_definitions.value_type IS '值类型';
COMMENT ON COLUMN feature_definitions.default_value IS '默认值';
COMMENT ON COLUMN feature_definitions.value_schema IS '值校验Schema';
COMMENT ON COLUMN feature_definitions.is_metered IS '是否需要计量使用量';
COMMENT ON COLUMN feature_definitions.status IS '状态';
COMMENT ON COLUMN feature_definitions.created_at IS '创建时间';
COMMENT ON COLUMN feature_definitions.updated_at IS '更新时间';



CREATE TYPE plan_billing_cycle AS ENUM ('monthly', 'yearly', 'custom');
CREATE TYPE plan_status AS ENUM ('draft', 'active', 'retired');
CREATE TABLE IF NOT EXISTS plans (
    id uuid NOT NULL PRIMARY KEY,
    code varchar(64) NOT NULL,
    name varchar(128) NOT NULL,
    description text,
    billing_cycle plan_billing_cycle NOT NULL DEFAULT 'monthly',
    currency char(3) NOT NULL DEFAULT 'CNY',
    price_minor bigint NOT NULL DEFAULT 0,
    version integer NOT NULL DEFAULT 1,
    status plan_status NOT NULL DEFAULT 'draft',
    metadata jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT uq_plans__code UNIQUE (code)
);
COMMENT ON TABLE plans IS '套餐';
COMMENT ON COLUMN plans.id IS '套餐ID';
COMMENT ON COLUMN plans.code IS '套餐编码';
COMMENT ON COLUMN plans.name IS '展示名称';
COMMENT ON COLUMN plans.description IS '套餐说明';
COMMENT ON COLUMN plans.billing_cycle IS '计费周期';
COMMENT ON COLUMN plans.currency IS '计价币种（ISO 4217）';
COMMENT ON COLUMN plans.price_minor IS '最小货币单位价格';
COMMENT ON COLUMN plans.version IS '套餐定义版本';
COMMENT ON COLUMN plans.status IS '状态';
COMMENT ON COLUMN plans.metadata IS '面向展示或计费的扩展元数据';
COMMENT ON COLUMN plans.created_at IS '创建时间';
COMMENT ON COLUMN plans.updated_at IS '更新时间';



CREATE TABLE IF NOT EXISTS plan_features (
    plan_id uuid NOT NULL,
    feature_code text NOT NULL,
    value jsonb,
    is_included boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    PRIMARY KEY (plan_id, feature_code),
    CONSTRAINT fk_plan_features__plan FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_plan_features__feature FOREIGN KEY (feature_code) REFERENCES feature_definitions(code) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE plan_features IS '套餐功能';
COMMENT ON COLUMN plan_features.plan_id IS '所属套餐';
COMMENT ON COLUMN plan_features.feature_code IS '功能编码';
COMMENT ON COLUMN plan_features.value IS '套餐赋予的值或限额';
COMMENT ON COLUMN plan_features.is_included IS '是否包含该功能';
COMMENT ON COLUMN plan_features.created_at IS '创建时间';
COMMENT ON COLUMN plan_features.updated_at IS '更新时间';

CREATE INDEX ix_plan_features__feature ON plan_features(feature_code);



CREATE TYPE tenant_subscription_status AS ENUM ('trialing', 'active', 'past_due', 'suspended', 'canceled', 'expired');
CREATE TABLE IF NOT EXISTS tenant_subscriptions (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    plan_version integer NOT NULL,
    plan_snapshot jsonb,
    status tenant_subscription_status NOT NULL DEFAULT 'trialing',
    started_at timestamptz NOT NULL,
    current_period_start timestamptz NOT NULL,
    current_period_end timestamptz NOT NULL,
    cancel_at timestamptz,
    canceled_at timestamptz,
    provider varchar(64),
    provider_subscription_id varchar(128),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT uq_tenant_subscriptions__provider_subscription UNIQUE (provider, provider_subscription_id),
    CONSTRAINT fk_tenant_subscriptions__tenants FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_subscriptions__plan FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_tenant_subscriptions__period CHECK (current_period_end > current_period_start)
);
ALTER TABLE tenant_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_subscriptions FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_subscriptions
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE UNIQUE INDEX uq_tenant_subscriptions__active ON tenant_subscriptions(tenant_id) WHERE status IN ('trialing', 'active', 'past_due', 'suspended');
CREATE INDEX ix_tenant_subscriptions__status ON tenant_subscriptions(tenant_id, status);
CREATE INDEX ix_tenant_subscriptions__period ON tenant_subscriptions(tenant_id, current_period_start, current_period_end);
COMMENT ON TABLE tenant_subscriptions IS '租户订阅';
COMMENT ON COLUMN tenant_subscriptions.id IS '订阅ID';
COMMENT ON COLUMN tenant_subscriptions.tenant_id IS '租户ID';
COMMENT ON COLUMN tenant_subscriptions.plan_id IS '套餐ID';
COMMENT ON COLUMN tenant_subscriptions.plan_version IS '订阅时的套餐版本';
COMMENT ON COLUMN tenant_subscriptions.plan_snapshot IS '套餐及功能快照';
COMMENT ON COLUMN tenant_subscriptions.status IS '订阅状态';
COMMENT ON COLUMN tenant_subscriptions.started_at IS '生效时间';
COMMENT ON COLUMN tenant_subscriptions.current_period_start IS '当前计费周期开始';
COMMENT ON COLUMN tenant_subscriptions.current_period_end IS '当前计费周期结束';
COMMENT ON COLUMN tenant_subscriptions.cancel_at IS '计划取消时间';
COMMENT ON COLUMN tenant_subscriptions.canceled_at IS '实际取消时间';
COMMENT ON COLUMN tenant_subscriptions.provider IS '外部计费提供商标识';
COMMENT ON COLUMN tenant_subscriptions.provider_subscription_id IS '外部订阅ID';
COMMENT ON COLUMN tenant_subscriptions.created_at IS '创建时间';
COMMENT ON COLUMN tenant_subscriptions.updated_at IS '更新时间';



CREATE TYPE tenant_entitlement_effect AS ENUM ('replace', 'disable');
CREATE TYPE tenant_entitlement_source_type AS ENUM ('trial', 'contract', 'manual', 'incident', 'migration');
CREATE TYPE tenant_entitlement_status AS ENUM ('active', 'revoked', 'expired');
CREATE TABLE IF NOT EXISTS tenant_entitlements (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    feature_code text NOT NULL,
    effect tenant_entitlement_effect NOT NULL,
    value jsonb,
    priority integer NOT NULL DEFAULT 0,
    source_type tenant_entitlement_source_type NOT NULL,
    source_ref varchar(128),
    reason text,
    effective_from timestamptz NOT NULL,
    effective_until timestamptz,
    status tenant_entitlement_status NOT NULL DEFAULT 'active',
    granted_by uuid NOT NULL,
    revoked_by uuid,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT fk_tenant_entitlements__tenants FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_entitlements__feature FOREIGN KEY (feature_code) REFERENCES feature_definitions(code) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_entitlements__granted_by FOREIGN KEY (granted_by) REFERENCES platform_users(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_entitlements__revoked_by FOREIGN KEY (revoked_by) REFERENCES platform_users(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_tenant_entitlements__effect_value CHECK (
        (effect = 'replace' AND value IS NOT NULL)
        OR (effect = 'disable' AND value IS NULL)
    ),
    CONSTRAINT ck_tenant_entitlements__period CHECK (effective_until IS NULL OR effective_until > effective_from)
);
ALTER TABLE tenant_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_entitlements FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_entitlements
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX ix_tenant_entitlements__effective ON tenant_entitlements(tenant_id, feature_code, priority DESC) WHERE status = 'active';
CREATE INDEX ix_tenant_entitlements__status ON tenant_entitlements(tenant_id, status);
COMMENT ON TABLE tenant_entitlements IS '租户功能覆盖';
COMMENT ON COLUMN tenant_entitlements.id IS '覆盖记录ID';
COMMENT ON COLUMN tenant_entitlements.tenant_id IS '租户ID';
COMMENT ON COLUMN tenant_entitlements.feature_code IS '功能编码';
COMMENT ON COLUMN tenant_entitlements.effect IS '覆盖效果';
COMMENT ON COLUMN tenant_entitlements.value IS 'replace时的最终功能值';
COMMENT ON COLUMN tenant_entitlements.priority IS '覆盖优先级';
COMMENT ON COLUMN tenant_entitlements.source_type IS '来源类型';
COMMENT ON COLUMN tenant_entitlements.source_ref IS '合同、工单或迁移批次标识';
COMMENT ON COLUMN tenant_entitlements.reason IS '覆盖原因';
COMMENT ON COLUMN tenant_entitlements.effective_from IS '生效时间';
COMMENT ON COLUMN tenant_entitlements.effective_until IS '失效时间';
COMMENT ON COLUMN tenant_entitlements.status IS '状态';
COMMENT ON COLUMN tenant_entitlements.granted_by IS '授权平台用户';
COMMENT ON COLUMN tenant_entitlements.revoked_by IS '撤销平台用户';
COMMENT ON COLUMN tenant_entitlements.revoked_at IS '撤销时间';
COMMENT ON COLUMN tenant_entitlements.created_at IS '创建时间';
COMMENT ON COLUMN tenant_entitlements.updated_at IS '更新时间';



CREATE TABLE IF NOT EXISTS tenant_feature_usages (
    tenant_id uuid NOT NULL,
    feature_code text NOT NULL,
    period_start timestamptz NOT NULL,
    period_end timestamptz NOT NULL,
    usage_value bigint NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, feature_code, period_start),
    CONSTRAINT ck_tenant_feature_usages__value CHECK (usage_value >= 0),
    CONSTRAINT ck_tenant_feature_usages__period CHECK (period_end > period_start),
    CONSTRAINT fk_tenant_feature_usages__tenants FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_feature_usages__feature FOREIGN KEY (feature_code) REFERENCES feature_definitions(code) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE tenant_feature_usages IS '租户功能用量';
COMMENT ON COLUMN tenant_feature_usages.tenant_id IS '租户ID';
COMMENT ON COLUMN tenant_feature_usages.feature_code IS '计量功能编码';
COMMENT ON COLUMN tenant_feature_usages.period_start IS '计量周期开始';
COMMENT ON COLUMN tenant_feature_usages.period_end IS '计量周期结束';
COMMENT ON COLUMN tenant_feature_usages.usage_value IS '已消耗数量';
COMMENT ON COLUMN tenant_feature_usages.updated_at IS '最近更新时间';

ALTER TABLE tenant_feature_usages ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_feature_usages FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_feature_usages
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
