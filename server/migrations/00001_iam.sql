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

CREATE INDEX idx_user_identifiers_user_id ON user_identifiers(user_id);



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
    status provider_status NOT NULL,
    created_at timestamptz NOT NULL
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



CREATE TABLE IF NOT EXISTS user_identities (
    id uuid NOT NULL PRIMARY KEY,
    user_id uuid NOT NULL,
    provider_id uuid NOT NULL,
    provider_subject varchar(256) NOT NULL,
    email_snapshot varchar(256),
    profile_snapshot jsonb,
    bound_at timestamptz NOT NULL,
    last_login_at timestamptz,
    CONSTRAINT uk_user_identities_provider_id_subject UNIQUE(provider_id, provider_subject),
    CONSTRAINT fk_user_identities_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_user_identities_provider_id FOREIGN KEY (provider_id) REFERENCES identity_providers(id) ON DELETE CASCADE ON UPDATE CASCADE
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

CREATE INDEX idx_user_identities_user ON user_identities(user_id);
CREATE INDEX idx_user_identities_provider ON user_identities(provider_id);



CREATE TYPE mfa_type AS ENUM('totp', 'webauthn', 'recovery_code');
CREATE TYPE mfa_status AS ENUM('active', 'revoked');
CREATE TABLE IF NOT EXISTS mfa_methods (
    id uuid NOT NULL PRIMARY KEY,
    user_id uuid NOT NULL,
    method_type mfa_type NOT NULL,
    name varchar(64) NOT NULL,
    secret_ref varchar(256) NOT NULL,
    credential_data jsonb,
    status mfa_status NOT NULL,
    verified_at timestamptz,
    last_used_at timestamptz,
    CONSTRAINT fk_mfa_methods_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE mfa_methods IS '多因素认证';
COMMENT ON COLUMN mfa_methods.id IS 'MFA方法IS';
COMMENT ON COLUMN mfa_methods.user_id IS '用户ID';
COMMENT ON COLUMN mfa_methods.method_type IS '方法类型';
COMMENT ON COLUMN mfa_methods.name IS '设备名称';
COMMENT ON COLUMN mfa_methods.secret_ref IS '密钥引用';
COMMENT ON COLUMN mfa_methods.credential_data IS '认证信息';
COMMENT ON COLUMN mfa_methods.status IS 'MFA方法状态';
COMMENT ON COLUMN mfa_methods.verified_at IS '验证时间';
COMMENT ON COLUMN mfa_methods.last_used_at IS '最近使用时间';

CREATE INDEX idx_mfa_methods_user_id ON mfa_methods(user_id);



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
CREATE INDEX idx_sessions_status ON sessions(status);
CREATE INDEX idx_sessions_expires ON sessions(absolute_expires_at) WHERE status = 'active';



CREATE TYPE tenants_status AS ENUM('pending', 'active', 'suspended', 'readonly', 'deleted');
CREATE TABLE IF NOT EXISTS tenants (
    id uuid NOT NULL PRIMARY KEY,
    slug varchar(256) NOT NULL,
    name varchar(64) NOT NULL,
    status tenants_status NOT NULL,
    authz_version bigint NOT NULL,
    create_by_user_id uuid NOT NULL,
    activated_at timestamptz,
    suspended_at timestamptz,
    created_at timestamptz NOT NULL,
    updated_at timestamptz,
    CONSTRAINT uk_tenants_slug UNIQUE(slug),
    CONSTRAINT fk_tenants_create_by_user_id FOREIGN KEY (create_by_user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE tenants IS '租户';
COMMENT ON COLUMN tenants.id IS '租户ID';
COMMENT ON COLUMN tenants.slug IS '租户标识';
COMMENT ON COLUMN tenants.name IS '租户名称';
COMMENT ON COLUMN tenants.status IS '租户状态';
COMMENT ON COLUMN tenants.authz_version IS '租户权限版本';
COMMENT ON COLUMN tenants.create_by_user_id IS '创建人';
COMMENT ON COLUMN tenants.activated_at IS '激活时间';
COMMENT ON COLUMN tenants.suspended_at IS '暂停时间';
COMMENT ON COLUMN tenants.created_at IS '创建时间';
COMMENT ON COLUMN tenants.updated_at IS '更新时间';

CREATE INDEX idx_tenants_slug ON tenants(slug);
CREATE INDEX idx_tenants_status ON tenants(status);



CREATE TYPE tenant_member_status AS ENUM('active', 'disabled', 'removed');
CREATE TABLE IF NOT EXISTS tenant_members (
    tenant_id uuid NOT NULL,
    user_id uuid NOT NULL,
    status tenant_member_status NOT NULL,
    job_title varchar(64),
    employee_no varchar(64),
    default_workspace_id uuid,
    authz_version bigint NOT NULL,
    joined_at timestamptz NOT NULL,
    disabled_at timestamptz,
    removed_at timestamptz,
    created_at timestamptz NOT NULL,
    updated_at timestamptz,
    PRIMARY KEY (tenant_id, user_id),
    CONSTRAINT fk_tenant_members_tenant_id FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_members_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tenant_members_default_workspace FOREIGN KEY (tenant_id, default_workspace_id) REFERENCES workspaces(tenant_id, id) ON DELETE SET NULL ON UPDATE CASCADE
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


CREATE TYPE member_invitation_status AS ENUM ('pending', 'accepted', 'expired', 'revoked');
CREATE TABLE IF NOT EXISTS member_invitations (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    identifier_type identifier_kind NOT NULL,
    identifier_value varchar(256) NOT NULL,
    token_hash bytea NOT NULL,
    invited_by_user_id uuid NOT NULL,
    status member_invitation_status NOT NULL DEFAULT 'pending',
    expires_at timestamptz NOT NULL,
    accepted_by_user_id uuid,
    accepted_at timestamptz,
    created_at timestamptz NOT NULL,
    CONSTRAINT uk_member_invitations_token_hash UNIQUE(token_hash),
    CONSTRAINT fk_inv_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_inv_inviter FOREIGN KEY (tenant_id, invited_by_user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_inv_accepted_by FOREIGN KEY (accepted_by_user_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE
);
COMMENT ON TABLE member_invitations IS '成员邀请';
COMMENT ON COLUMN member_invitations.id IS '邀请ID';
COMMENT ON COLUMN member_invitations.tenant_id IS '租户ID';
COMMENT ON COLUMN member_invitations.identifier_type IS '标识类型';
COMMENT ON COLUMN member_invitations.identifier_value IS '被邀请邮箱/手机号';
COMMENT ON COLUMN member_invitations.token_hash IS '一次性令牌哈希';
COMMENT ON COLUMN member_invitations.invited_by_user_id IS '邀请人';
COMMENT ON COLUMN member_invitations.status IS '邀请状态';
COMMENT ON COLUMN member_invitations.expires_at IS '过期时间';
COMMENT ON COLUMN member_invitations.accepted_by_user_id IS '接受人';
COMMENT ON COLUMN member_invitations.accepted_at IS '接受时间';
COMMENT ON COLUMN member_invitations.created_at IS '创建时间';

CREATE INDEX idx_member_invitations_tenant ON member_invitations(tenant_id, status);
CREATE INDEX idx_member_invitations_identifier ON member_invitations(tenant_id, identifier_type, identifier_value);


CREATE TYPE workspace_status AS ENUM ('active', 'archived');
CREATE TABLE IF NOT EXISTS workspaces (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    code varchar(64) NOT NULL,
    name varchar(128) NOT NULL,
    workspace_type varchar(64),
    status workspace_status NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT uk_workspaces_tenant_id_code UNIQUE (tenant_id, code),
    CONSTRAINT uk_workspaces_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_workspaces_tenant_id FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE workspaces IS '工作区';
COMMENT ON COLUMN workspaces.id IS '工作区ID';
COMMENT ON COLUMN workspaces.tenant_id IS '所属租户';
COMMENT ON COLUMN workspaces.code IS '租户内编码';
COMMENT ON COLUMN workspaces.name IS '名称';
COMMENT ON COLUMN workspaces.workspace_type IS '工作区类型';
COMMENT ON COLUMN workspaces.status IS '工作区状态';
COMMENT ON COLUMN workspaces.created_at IS '创建时间';

ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspaces FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON workspaces
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX idx_workspaces_status ON workspaces(status);
CREATE INDEX idx_workspaces_created_at ON workspaces(created_at);



CREATE TYPE workspace_membership_status AS ENUM ('active', 'removed');
CREATE TABLE IF NOT EXISTS workspace_memberships (
    tenant_id uuid NOT NULL,
    workspace_id uuid NOT NULL,
    user_id uuid NOT NULL,
    status workspace_membership_status NOT NULL DEFAULT 'active',
    joined_at timestamptz NOT NULL,
    PRIMARY KEY (workspace_id, user_id),
    CONSTRAINT fk_wsm_tenant_workspace FOREIGN KEY (tenant_id, workspace_id) REFERENCES workspaces(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_wsm_tenant_member FOREIGN KEY (tenant_id, user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE workspace_memberships IS '成员工作区关系';
COMMENT ON COLUMN workspace_memberships.tenant_id IS '租户ID（冗余用于同租户约束）';
COMMENT ON COLUMN workspace_memberships.workspace_id IS '工作区ID';
COMMENT ON COLUMN workspace_memberships.user_id IS '用户ID';
COMMENT ON COLUMN workspace_memberships.status IS '成员状态';
COMMENT ON COLUMN workspace_memberships.joined_at IS '加入时间';

ALTER TABLE workspace_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_memberships FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON workspace_memberships
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX idx_wsm_tenant_workspace ON workspace_memberships(tenant_id, workspace_id);
CREATE INDEX idx_wsm_tenant_member ON workspace_memberships(tenant_id, user_id);
CREATE INDEX idx_wsm_status ON workspace_memberships(status);



CREATE TYPE org_unit_type AS ENUM ('organization', 'division', 'department', 'team');
CREATE TYPE org_unit_status AS ENUM ('active', 'disabled');
CREATE TABLE IF NOT EXISTS org_units (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    parent_id uuid,
    unit_type org_unit_type NOT NULL,
    code varchar(64) NOT NULL,
    name varchar(128) NOT NULL,
    status org_unit_status NOT NULL DEFAULT 'active',
    manager_user_id uuid,
    created_at timestamptz NOT NULL,
    CONSTRAINT uk_org_units_tenant_id_code UNIQUE (tenant_id, code),
    CONSTRAINT uk_org_units_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_org_units_tenant_id FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_org_units_parent FOREIGN KEY (tenant_id, parent_id) REFERENCES org_units(tenant_id, id) ON DELETE SET NULL ON UPDATE CASCADE
);
COMMENT ON TABLE org_units IS '组织单元';
COMMENT ON COLUMN org_units.id IS '组织单元ID';
COMMENT ON COLUMN org_units.tenant_id IS '租户ID';
COMMENT ON COLUMN org_units.parent_id IS '父节点';
COMMENT ON COLUMN org_units.unit_type IS '组织类型';
COMMENT ON COLUMN org_units.code IS '编码';
COMMENT ON COLUMN org_units.name IS '名称';
COMMENT ON COLUMN org_units.status IS '组织状态';
COMMENT ON COLUMN org_units.manager_user_id IS '负责人';
COMMENT ON COLUMN org_units.created_at IS '创建时间';

ALTER TABLE org_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE org_units FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON org_units
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX idx_org_units_parent ON org_units(tenant_id, parent_id);
CREATE INDEX idx_org_units_status ON org_units(status);
CREATE INDEX idx_org_units_created_at ON org_units(created_at);



CREATE TABLE IF NOT EXISTS org_unit_closure (
    tenant_id uuid NOT NULL,
    ancestor_id uuid NOT NULL,
    descendant_id uuid NOT NULL,
    depth integer NOT NULL,
    PRIMARY KEY (ancestor_id, descendant_id),
    CONSTRAINT ck_org_unit_closure_depth CHECK (depth >= 0),
    CONSTRAINT fk_org_unit_closure_ancestor FOREIGN KEY (tenant_id, ancestor_id) REFERENCES org_units(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_org_unit_closure_descendant FOREIGN KEY (tenant_id, descendant_id) REFERENCES org_units(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE org_unit_closure IS '组织树闭包表';
COMMENT ON COLUMN org_unit_closure.tenant_id IS '租户ID';
COMMENT ON COLUMN org_unit_closure.ancestor_id IS '祖先节点';
COMMENT ON COLUMN org_unit_closure.descendant_id IS '后代节点';
COMMENT ON COLUMN org_unit_closure.depth IS '相对深度';

ALTER TABLE org_unit_closure ENABLE ROW LEVEL SECURITY;
ALTER TABLE org_unit_closure FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON org_unit_closure
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX idx_ouc_tenant_descendant ON org_unit_closure(tenant_id, descendant_id);
CREATE INDEX idx_ouc_tenant_ancestor ON org_unit_closure(tenant_id, ancestor_id);



CREATE TYPE member_org_relation_type AS ENUM ('member', 'manager');
CREATE TABLE IF NOT EXISTS member_org_units (
    tenant_id uuid NOT NULL,
    user_id uuid NOT NULL,
    org_unit_id uuid NOT NULL,
    relation_type member_org_relation_type NOT NULL DEFAULT 'member',
    is_primary boolean NOT NULL DEFAULT false,
    joined_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, org_unit_id),
    CONSTRAINT fk_member_org_units_tenant_member FOREIGN KEY (tenant_id, user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_member_org_units_tenant_org_unit FOREIGN KEY (tenant_id, org_unit_id) REFERENCES org_units(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE UNIQUE INDEX uq_user_primary_org_unit ON member_org_units(user_id) WHERE is_primary = true;
COMMENT ON TABLE member_org_units IS '成员组织归属';
COMMENT ON COLUMN member_org_units.tenant_id IS '租户ID';
COMMENT ON COLUMN member_org_units.user_id IS '用户ID';
COMMENT ON COLUMN member_org_units.org_unit_id IS '组织单元ID';
COMMENT ON COLUMN member_org_units.relation_type IS '关系类型';
COMMENT ON COLUMN member_org_units.is_primary IS '是否主组织';
COMMENT ON COLUMN member_org_units.joined_at IS '加入时间';

ALTER TABLE member_org_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_org_units FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON member_org_units
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX idx_mou_tenant_org_unit ON member_org_units(tenant_id, org_unit_id);
CREATE INDEX idx_mou_relation_type ON member_org_units(relation_type);



CREATE TYPE permission_realm AS ENUM ('tenant', 'platform');
CREATE TYPE permission_risk_level AS ENUM ('normal', 'sensitive', 'critical');
CREATE TYPE permission_status AS ENUM ('active', 'deprecated');
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
    created_at timestamptz NOT NULL
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

CREATE INDEX idx_permission_defs_module ON permission_definitions(module, resource);
CREATE INDEX idx_permission_defs_realm ON permission_definitions(realm);



CREATE TABLE IF NOT EXISTS role_templates (
    id uuid NOT NULL PRIMARY KEY,
    code varchar(64) NOT NULL,
    name varchar(128) NOT NULL,
    description text,
    is_system boolean NOT NULL DEFAULT false,
    version bigint NOT NULL DEFAULT 1,
    status permission_status NOT NULL DEFAULT 'active',
    CONSTRAINT uk_role_templates_code UNIQUE (code)
);
COMMENT ON TABLE role_templates IS '平台角色模板';
COMMENT ON COLUMN role_templates.id IS '模板ID';
COMMENT ON COLUMN role_templates.code IS '模板编码';
COMMENT ON COLUMN role_templates.name IS '模板名称';
COMMENT ON COLUMN role_templates.description IS '描述';
COMMENT ON COLUMN role_templates.is_system IS '是否系统模板';
COMMENT ON COLUMN role_templates.version IS '模板版本';
COMMENT ON COLUMN role_templates.status IS '状态';

CREATE INDEX idx_role_templates_code ON role_templates(code);



CREATE TABLE IF NOT EXISTS role_template_permissions (
    role_template_id uuid NOT NULL,
    permission_code varchar(128) NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (role_template_id, permission_code),
    CONSTRAINT fk_rtp_template FOREIGN KEY (role_template_id) REFERENCES role_templates(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_rtp_permission FOREIGN KEY (permission_code) REFERENCES permission_definitions(code) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE role_template_permissions IS '角色模板权限';
COMMENT ON COLUMN role_template_permissions.role_template_id IS '角色模板ID';
COMMENT ON COLUMN role_template_permissions.permission_code IS '权限编码';
COMMENT ON COLUMN role_template_permissions.created_at IS '创建时间';



CREATE TYPE role_type AS ENUM ('system', 'custom');
CREATE TABLE IF NOT EXISTS roles (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    source_template_id uuid,
    code varchar(64) NOT NULL,
    name varchar(128) NOT NULL,
    description text,
    role_type role_type NOT NULL,
    status org_unit_status NOT NULL,
    version bigint NOT NULL DEFAULT 1,
    created_by_user_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz,
    CONSTRAINT uk_roles_tenant_id_code UNIQUE (tenant_id, code),
    CONSTRAINT uk_roles_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_roles_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_roles_source_template FOREIGN KEY (source_template_id) REFERENCES role_templates(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_roles_created_by FOREIGN KEY (tenant_id, created_by_user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE roles IS '租户角色';
COMMENT ON COLUMN roles.id IS '角色ID';
COMMENT ON COLUMN roles.tenant_id IS '所属租户';
COMMENT ON COLUMN roles.source_template_id IS '来源模板';
COMMENT ON COLUMN roles.code IS '租户内角色编码';
COMMENT ON COLUMN roles.name IS '角色名称';
COMMENT ON COLUMN roles.description IS '描述';
COMMENT ON COLUMN roles.role_type IS '角色类型';
COMMENT ON COLUMN roles.status IS '状态';
COMMENT ON COLUMN roles.version IS '乐观锁版本';
COMMENT ON COLUMN roles.created_by_user_id IS '创建人';
COMMENT ON COLUMN roles.created_at IS '创建时间';
COMMENT ON COLUMN roles.updated_at IS '更新时间';

ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON roles
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX idx_roles_status ON roles(status);
CREATE INDEX idx_roles_role_type ON roles(role_type);
CREATE INDEX idx_roles_created_at ON roles(created_at);



CREATE TABLE IF NOT EXISTS role_permissions (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    role_id uuid NOT NULL,
    permission_code varchar(128) NOT NULL,
    created_by_user_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT uk_role_permissions_role_perm UNIQUE (role_id, permission_code),
    CONSTRAINT uk_role_permissions_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_rp_tenant_role FOREIGN KEY (tenant_id, role_id) REFERENCES roles(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_rp_permission FOREIGN KEY (permission_code) REFERENCES permission_definitions(code) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_rp_created_by FOREIGN KEY (tenant_id, created_by_user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE role_permissions IS '角色权限授权';
COMMENT ON COLUMN role_permissions.id IS '授权ID';
COMMENT ON COLUMN role_permissions.tenant_id IS '租户ID';
COMMENT ON COLUMN role_permissions.role_id IS '角色ID';
COMMENT ON COLUMN role_permissions.permission_code IS '原子权限编码';
COMMENT ON COLUMN role_permissions.created_by_user_id IS '授权人';
COMMENT ON COLUMN role_permissions.created_at IS '授权时间';

ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON role_permissions
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX idx_rp_tenant_role ON role_permissions(tenant_id, role_id);



CREATE TYPE permission_scope_type AS ENUM ('SELF', 'DEPARTMENT', 'DEPARTMENT_AND_CHILDREN', 'WORKSPACE', 'TENANT', 'CUSTOM');
CREATE TABLE IF NOT EXISTS permission_scopes (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    role_permission_id uuid NOT NULL,
    scope_type permission_scope_type NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT uk_permission_scopes_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_ps_tenant_role_permission FOREIGN KEY (tenant_id, role_permission_id) REFERENCES role_permissions(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE permission_scopes IS '权限的数据范围';
COMMENT ON COLUMN permission_scopes.id IS '范围ID';
COMMENT ON COLUMN permission_scopes.tenant_id IS '租户ID';
COMMENT ON COLUMN permission_scopes.role_permission_id IS '所属角色权限ID';
COMMENT ON COLUMN permission_scopes.scope_type IS '数据范围类型';
COMMENT ON COLUMN permission_scopes.created_at IS '创建时间';

ALTER TABLE permission_scopes ENABLE ROW LEVEL SECURITY;
ALTER TABLE permission_scopes FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON permission_scopes
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX idx_ps_tenant_role_permission ON permission_scopes(tenant_id, role_permission_id);



CREATE TYPE scope_target_type AS ENUM ('member', 'org_unit', 'workspace');
CREATE TABLE IF NOT EXISTS permission_scope_targets (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    scope_id uuid NOT NULL,
    target_type scope_target_type NOT NULL,
    target_user_id uuid,
    target_org_unit_id uuid,
    target_workspace_id uuid,
    CONSTRAINT uk_permission_scope_targets_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_pst_tenant_scope FOREIGN KEY (tenant_id, scope_id) REFERENCES permission_scopes(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_pst_target_match CHECK (
        CASE target_type
            WHEN 'member'    THEN target_user_id IS NOT NULL AND target_org_unit_id IS NULL AND target_workspace_id IS NULL
            WHEN 'org_unit'  THEN target_user_id IS NULL AND target_org_unit_id IS NOT NULL AND target_workspace_id IS NULL
            WHEN 'workspace' THEN target_user_id IS NULL AND target_org_unit_id IS NULL AND target_workspace_id IS NOT NULL
        END
    )
);
COMMENT ON TABLE permission_scope_targets IS '自定义范围目标';
COMMENT ON COLUMN permission_scope_targets.id IS '目标ID';
COMMENT ON COLUMN permission_scope_targets.tenant_id IS '租户ID';
COMMENT ON COLUMN permission_scope_targets.scope_id IS '所属数据范围ID';
COMMENT ON COLUMN permission_scope_targets.target_type IS '目标类型';
COMMENT ON COLUMN permission_scope_targets.target_user_id IS '指定用户';
COMMENT ON COLUMN permission_scope_targets.target_org_unit_id IS '指定组织';
COMMENT ON COLUMN permission_scope_targets.target_workspace_id IS '指定工作区';

ALTER TABLE permission_scope_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE permission_scope_targets FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON permission_scope_targets
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX idx_pst_tenant_scope ON permission_scope_targets(tenant_id, scope_id);



CREATE TYPE binding_scope_type AS ENUM ('tenant', 'workspace', 'org_unit');
CREATE TABLE IF NOT EXISTS member_role_bindings (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role_id uuid NOT NULL,
    binding_scope binding_scope_type NOT NULL,
    workspace_id uuid,
    org_unit_id uuid,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    granted_by_user_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT uk_member_role_bindings_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_mrb_tenant_member FOREIGN KEY (tenant_id, user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_mrb_tenant_role FOREIGN KEY (tenant_id, role_id) REFERENCES roles(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_mrb_tenant_granted_by FOREIGN KEY (tenant_id, granted_by_user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_mrb_binding_scope CHECK (
        CASE binding_scope
            WHEN 'tenant'    THEN workspace_id IS NULL AND org_unit_id IS NULL
            WHEN 'workspace' THEN workspace_id IS NOT NULL AND org_unit_id IS NULL
            WHEN 'org_unit'  THEN workspace_id IS NULL AND org_unit_id IS NOT NULL
        END
    )
);
COMMENT ON TABLE member_role_bindings IS '成员角色绑定';
COMMENT ON COLUMN member_role_bindings.id IS '绑定ID';
COMMENT ON COLUMN member_role_bindings.tenant_id IS '租户ID';
COMMENT ON COLUMN member_role_bindings.user_id IS '用户ID';
COMMENT ON COLUMN member_role_bindings.role_id IS '角色ID';
COMMENT ON COLUMN member_role_bindings.binding_scope IS '绑定范围';
COMMENT ON COLUMN member_role_bindings.workspace_id IS '工作区范围';
COMMENT ON COLUMN member_role_bindings.org_unit_id IS '组织范围';
COMMENT ON COLUMN member_role_bindings.valid_from IS '生效时间';
COMMENT ON COLUMN member_role_bindings.valid_until IS '失效时间';
COMMENT ON COLUMN member_role_bindings.granted_by_user_id IS '授权人';
COMMENT ON COLUMN member_role_bindings.created_at IS '创建时间';

ALTER TABLE member_role_bindings ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_role_bindings FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON member_role_bindings
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX idx_mrb_tenant_member ON member_role_bindings(tenant_id, user_id);
CREATE INDEX idx_mrb_tenant_role ON member_role_bindings(tenant_id, role_id);
CREATE INDEX idx_mrb_valid_period ON member_role_bindings(valid_from, valid_until) WHERE valid_until IS NOT NULL;
CREATE INDEX idx_mrb_binding_scope ON member_role_bindings(tenant_id, binding_scope);



CREATE TYPE policy_subject_type AS ENUM ('role', 'member');
CREATE TYPE policy_effect AS ENUM ('deny', 'constrain');
CREATE TABLE IF NOT EXISTS policy_rules (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    subject_type policy_subject_type NOT NULL,
    role_id uuid,
    member_id uuid,
    resource varchar(128) NOT NULL,
    action varchar(64) NOT NULL,
    effect policy_effect NOT NULL,
    condition jsonb,
    priority integer NOT NULL DEFAULT 0,
    status org_unit_status NOT NULL DEFAULT 'active',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    CONSTRAINT fk_policy_rules_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_policy_rules_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_policy_rules_member FOREIGN KEY (tenant_id, member_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_policy_rules_subject CHECK (
        CASE subject_type
            WHEN 'role'   THEN role_id IS NOT NULL AND member_id IS NULL
            WHEN 'member' THEN role_id IS NULL AND member_id IS NOT NULL
        END
    )
);
COMMENT ON TABLE policy_rules IS '受控ABAC策略';
COMMENT ON COLUMN policy_rules.id IS '策略ID';
COMMENT ON COLUMN policy_rules.tenant_id IS '租户ID';
COMMENT ON COLUMN policy_rules.subject_type IS '主体类型';
COMMENT ON COLUMN policy_rules.role_id IS '角色主体';
COMMENT ON COLUMN policy_rules.member_id IS '成员主体';
COMMENT ON COLUMN policy_rules.resource IS '资源';
COMMENT ON COLUMN policy_rules.action IS '操作';
COMMENT ON COLUMN policy_rules.effect IS '效果';
COMMENT ON COLUMN policy_rules.condition IS '受控条件';
COMMENT ON COLUMN policy_rules.priority IS '优先级';
COMMENT ON COLUMN policy_rules.status IS '状态';
COMMENT ON COLUMN policy_rules.valid_from IS '生效时间';
COMMENT ON COLUMN policy_rules.valid_until IS '失效时间';

ALTER TABLE policy_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE policy_rules FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON policy_rules
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX idx_pr_tenant_status ON policy_rules(tenant_id, status);
CREATE INDEX idx_pr_resource_action ON policy_rules(tenant_id, resource, action);
CREATE INDEX idx_pr_priority ON policy_rules(tenant_id, priority DESC);



CREATE TABLE IF NOT EXISTS platform_roles (
    id uuid NOT NULL PRIMARY KEY,
    code varchar(64) NOT NULL,
    name varchar(128) NOT NULL,
    description text,
    role_type role_type NOT NULL DEFAULT 'custom',
    status org_unit_status NOT NULL DEFAULT 'active',
    version bigint NOT NULL DEFAULT 1,
    created_by_user_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz,
    CONSTRAINT uk_platform_roles_code UNIQUE (code),
    CONSTRAINT fk_platform_roles_created_by FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE platform_roles IS '平台角色';
COMMENT ON COLUMN platform_roles.id IS '平台角色ID';
COMMENT ON COLUMN platform_roles.code IS '角色编码';
COMMENT ON COLUMN platform_roles.name IS '角色名称';
COMMENT ON COLUMN platform_roles.description IS '描述';
COMMENT ON COLUMN platform_roles.role_type IS '角色类型';
COMMENT ON COLUMN platform_roles.status IS '状态';
COMMENT ON COLUMN platform_roles.version IS '乐观锁版本';
COMMENT ON COLUMN platform_roles.created_by_user_id IS '创建人';
COMMENT ON COLUMN platform_roles.created_at IS '创建时间';
COMMENT ON COLUMN platform_roles.updated_at IS '更新时间';



CREATE TABLE IF NOT EXISTS platform_role_permissions (
    id uuid NOT NULL PRIMARY KEY,
    platform_role_id uuid NOT NULL,
    permission_code varchar(128) NOT NULL,
    created_by_user_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT uk_prp_role_perm UNIQUE (platform_role_id, permission_code),
    CONSTRAINT fk_prp_role FOREIGN KEY (platform_role_id) REFERENCES platform_roles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_prp_permission FOREIGN KEY (permission_code) REFERENCES permission_definitions(code) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_prp_created_by FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE platform_role_permissions IS '平台角色权限';
COMMENT ON COLUMN platform_role_permissions.id IS '授权ID';
COMMENT ON COLUMN platform_role_permissions.platform_role_id IS '平台角色ID';
COMMENT ON COLUMN platform_role_permissions.permission_code IS '权限编码';
COMMENT ON COLUMN platform_role_permissions.created_by_user_id IS '授权人';
COMMENT ON COLUMN platform_role_permissions.created_at IS '授权时间';

CREATE INDEX idx_prp_role ON platform_role_permissions(platform_role_id);



CREATE TABLE IF NOT EXISTS platform_user_role_bindings (
    id uuid NOT NULL PRIMARY KEY,
    user_id uuid NOT NULL,
    platform_role_id uuid NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    granted_by_user_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT fk_purb_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_purb_role FOREIGN KEY (platform_role_id) REFERENCES platform_roles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_purb_granted_by FOREIGN KEY (granted_by_user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE platform_user_role_bindings IS '平台用户角色绑定';
COMMENT ON COLUMN platform_user_role_bindings.id IS '绑定ID';
COMMENT ON COLUMN platform_user_role_bindings.user_id IS '平台人员';
COMMENT ON COLUMN platform_user_role_bindings.platform_role_id IS '平台角色ID';
COMMENT ON COLUMN platform_user_role_bindings.valid_from IS '生效时间';
COMMENT ON COLUMN platform_user_role_bindings.valid_until IS '失效时间';
COMMENT ON COLUMN platform_user_role_bindings.granted_by_user_id IS '授权人';
COMMENT ON COLUMN platform_user_role_bindings.created_at IS '创建时间';

CREATE INDEX idx_purb_user ON platform_user_role_bindings(user_id);
CREATE INDEX idx_purb_role ON platform_user_role_bindings(platform_role_id);



CREATE TYPE access_mode AS ENUM ('readonly', 'limited');
CREATE TABLE IF NOT EXISTS support_access_sessions (
    id uuid NOT NULL PRIMARY KEY,
    platform_user_id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    reason text NOT NULL,
    ticket_no varchar(64),
    access_mode access_mode NOT NULL DEFAULT 'readonly',
    allowed_permissions jsonb,
    approved_by_user_id uuid,
    started_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    CONSTRAINT fk_sas_platform_user FOREIGN KEY (platform_user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_sas_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_sas_approved_by FOREIGN KEY (approved_by_user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE support_access_sessions IS '租户代操作会话';
COMMENT ON COLUMN support_access_sessions.id IS '代操作会话ID';
COMMENT ON COLUMN support_access_sessions.platform_user_id IS '平台操作人';
COMMENT ON COLUMN support_access_sessions.tenant_id IS '目标租户';
COMMENT ON COLUMN support_access_sessions.reason IS '访问原因';
COMMENT ON COLUMN support_access_sessions.ticket_no IS '工单号';
COMMENT ON COLUMN support_access_sessions.access_mode IS '访问模式';
COMMENT ON COLUMN support_access_sessions.allowed_permissions IS '临时权限上限';
COMMENT ON COLUMN support_access_sessions.approved_by_user_id IS '审批人';
COMMENT ON COLUMN support_access_sessions.started_at IS '开始时间';
COMMENT ON COLUMN support_access_sessions.expires_at IS '过期时间';
COMMENT ON COLUMN support_access_sessions.revoked_at IS '撤销时间';

CREATE INDEX idx_sas_platform_user ON support_access_sessions(platform_user_id);
CREATE INDEX idx_sas_tenant ON support_access_sessions(tenant_id);



CREATE TABLE IF NOT EXISTS service_accounts (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    name varchar(128) NOT NULL,
    description text,
    status org_unit_status NOT NULL DEFAULT 'active',
    authz_version bigint NOT NULL DEFAULT 1,
    created_by_user_id uuid NOT NULL,
    last_used_at timestamptz,
    created_at timestamptz NOT NULL,
    CONSTRAINT uk_service_accounts_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_sa_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_sa_created_by FOREIGN KEY (tenant_id, created_by_user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE service_accounts IS '服务账号';
COMMENT ON COLUMN service_accounts.id IS '服务账号ID';
COMMENT ON COLUMN service_accounts.tenant_id IS '所属租户';
COMMENT ON COLUMN service_accounts.name IS '名称';
COMMENT ON COLUMN service_accounts.description IS '用途';
COMMENT ON COLUMN service_accounts.status IS '状态';
COMMENT ON COLUMN service_accounts.authz_version IS '权限版本';
COMMENT ON COLUMN service_accounts.created_by_user_id IS '创建人';
COMMENT ON COLUMN service_accounts.last_used_at IS '最近使用时间';
COMMENT ON COLUMN service_accounts.created_at IS '创建时间';

ALTER TABLE service_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_accounts FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON service_accounts
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX idx_sa_status ON service_accounts(status);
CREATE INDEX idx_sa_created_at ON service_accounts(created_at);



CREATE TABLE IF NOT EXISTS service_account_role_bindings (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    service_account_id uuid NOT NULL,
    role_id uuid NOT NULL,
    binding_scope binding_scope_type NOT NULL,
    workspace_id uuid,
    org_unit_id uuid,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    granted_by_user_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT uk_sarb_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_sarb_tenant_sa FOREIGN KEY (tenant_id, service_account_id) REFERENCES service_accounts(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_sarb_tenant_role FOREIGN KEY (tenant_id, role_id) REFERENCES roles(tenant_id, id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_sarb_tenant_granted_by FOREIGN KEY (tenant_id, granted_by_user_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_sarb_binding_scope CHECK (
        CASE binding_scope
            WHEN 'tenant'    THEN workspace_id IS NULL AND org_unit_id IS NULL
            WHEN 'workspace' THEN workspace_id IS NOT NULL AND org_unit_id IS NULL
            WHEN 'org_unit'  THEN workspace_id IS NULL AND org_unit_id IS NOT NULL
        END
    )
);
COMMENT ON TABLE service_account_role_bindings IS '服务账号角色绑定';
COMMENT ON COLUMN service_account_role_bindings.id IS '绑定ID';
COMMENT ON COLUMN service_account_role_bindings.tenant_id IS '租户ID';
COMMENT ON COLUMN service_account_role_bindings.service_account_id IS '服务账号ID';
COMMENT ON COLUMN service_account_role_bindings.role_id IS '角色ID';
COMMENT ON COLUMN service_account_role_bindings.binding_scope IS '绑定范围';
COMMENT ON COLUMN service_account_role_bindings.workspace_id IS '工作区范围';
COMMENT ON COLUMN service_account_role_bindings.org_unit_id IS '组织范围';
COMMENT ON COLUMN service_account_role_bindings.valid_from IS '生效时间';
COMMENT ON COLUMN service_account_role_bindings.valid_until IS '失效时间';
COMMENT ON COLUMN service_account_role_bindings.granted_by_user_id IS '授权人';
COMMENT ON COLUMN service_account_role_bindings.created_at IS '创建时间';

ALTER TABLE service_account_role_bindings ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_account_role_bindings FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON service_account_role_bindings
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX idx_sarb_tenant_sa ON service_account_role_bindings(tenant_id, service_account_id);
CREATE INDEX idx_sarb_tenant_role ON service_account_role_bindings(tenant_id, role_id);
CREATE INDEX idx_sarb_valid_period ON service_account_role_bindings(valid_from, valid_until) WHERE valid_until IS NOT NULL;



CREATE TYPE api_key_status AS ENUM ('active', 'revoked', 'expired');
CREATE TABLE IF NOT EXISTS api_keys (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    service_account_id uuid NOT NULL,
    name varchar(128) NOT NULL,
    key_prefix varchar(32) NOT NULL,
    secret_hash bytea NOT NULL,
    status api_key_status NOT NULL DEFAULT 'active',
    allowed_cidrs cidr[],
    expires_at timestamptz,
    last_used_at timestamptz,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL,
    CONSTRAINT fk_api_keys_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_api_keys_sa FOREIGN KEY (service_account_id) REFERENCES service_accounts(id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE api_keys IS 'API密钥';
COMMENT ON COLUMN api_keys.id IS 'Key ID';
COMMENT ON COLUMN api_keys.tenant_id IS '租户ID';
COMMENT ON COLUMN api_keys.service_account_id IS '服务账号ID';
COMMENT ON COLUMN api_keys.name IS '名称';
COMMENT ON COLUMN api_keys.key_prefix IS '密钥前缀';
COMMENT ON COLUMN api_keys.secret_hash IS '密钥哈希';
COMMENT ON COLUMN api_keys.status IS '状态';
COMMENT ON COLUMN api_keys.allowed_cidrs IS 'IP限制';
COMMENT ON COLUMN api_keys.expires_at IS '过期时间';
COMMENT ON COLUMN api_keys.last_used_at IS '最近使用时间';
COMMENT ON COLUMN api_keys.revoked_at IS '撤销时间';
COMMENT ON COLUMN api_keys.created_at IS '创建时间';

ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_keys FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON api_keys
USING (
    tenant_id = current_setting('app.tenant_id')::uuid
)
WITH CHECK (
    tenant_id = current_setting('app.tenant_id')::uuid
);
CREATE INDEX idx_api_keys_tenant_sa ON api_keys(tenant_id, service_account_id);
CREATE INDEX idx_api_keys_key_prefix ON api_keys(tenant_id, key_prefix);
CREATE INDEX idx_api_keys_status ON api_keys(status);



CREATE TYPE oauth_client_type AS ENUM ('public', 'confidential');
CREATE TABLE IF NOT EXISTS oauth_clients (
    id uuid NOT NULL PRIMARY KEY,
    owner_tenant_id uuid NOT NULL,
    name varchar(128) NOT NULL,
    client_type oauth_client_type NOT NULL DEFAULT 'confidential',
    client_secret_hash bytea,
    redirect_uris text[] NOT NULL,
    allowed_scopes text[],
    status org_unit_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL,
    CONSTRAINT fk_oauth_clients_tenant FOREIGN KEY (owner_tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE oauth_clients IS 'OAuth应用';
COMMENT ON COLUMN oauth_clients.id IS 'Client ID';
COMMENT ON COLUMN oauth_clients.owner_tenant_id IS '创建应用的租户';
COMMENT ON COLUMN oauth_clients.name IS '应用名称';
COMMENT ON COLUMN oauth_clients.client_type IS '客户端类型';
COMMENT ON COLUMN oauth_clients.client_secret_hash IS '机密客户端凭据';
COMMENT ON COLUMN oauth_clients.redirect_uris IS '精确回调地址';
COMMENT ON COLUMN oauth_clients.allowed_scopes IS '可申请权限上限';
COMMENT ON COLUMN oauth_clients.status IS '状态';
COMMENT ON COLUMN oauth_clients.created_at IS '创建时间';

CREATE INDEX idx_oauth_clients_owner ON oauth_clients(owner_tenant_id);



CREATE TABLE IF NOT EXISTS oauth_grants (
    id uuid NOT NULL PRIMARY KEY,
    client_id uuid NOT NULL,
    user_id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    member_id uuid NOT NULL,
    granted_scopes text[],
    status mfa_status NOT NULL DEFAULT 'active',
    granted_at timestamptz NOT NULL,
    expires_at timestamptz,
    revoked_at timestamptz,
    CONSTRAINT fk_oauth_grants_client FOREIGN KEY (client_id) REFERENCES oauth_clients(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_oauth_grants_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_oauth_grants_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_oauth_grants_tenant_member FOREIGN KEY (tenant_id, member_id) REFERENCES tenant_members(tenant_id, user_id) ON DELETE CASCADE ON UPDATE CASCADE
);
COMMENT ON TABLE oauth_grants IS 'OAuth授权记录';
COMMENT ON COLUMN oauth_grants.id IS '授权ID';
COMMENT ON COLUMN oauth_grants.client_id IS 'OAuth应用ID';
COMMENT ON COLUMN oauth_grants.user_id IS '用户ID';
COMMENT ON COLUMN oauth_grants.tenant_id IS '授权租户';
COMMENT ON COLUMN oauth_grants.member_id IS '对应成员';
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
CREATE INDEX idx_og_tenant_client ON oauth_grants(tenant_id, client_id);
CREATE INDEX idx_og_tenant_user ON oauth_grants(tenant_id, user_id);
CREATE INDEX idx_og_status ON oauth_grants(status);



CREATE TYPE feature_value_type AS ENUM ('boolean', 'integer', 'bytes', 'count', 'json');
CREATE TABLE IF NOT EXISTS feature_definitions (
    code text NOT NULL PRIMARY KEY,
    name varchar(128) NOT NULL,
    description text,
    category varchar(64),
    value_type feature_value_type NOT NULL DEFAULT 'boolean',
    default_value jsonb,
    value_schema jsonb,
    is_metered boolean NOT NULL DEFAULT false,
    status permission_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL,
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
    created_at timestamptz NOT NULL,
    updated_at timestamptz,
    CONSTRAINT uk_plans_code UNIQUE (code)
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
    created_at timestamptz NOT NULL,
    updated_at timestamptz,
    PRIMARY KEY (plan_id, feature_code),
    CONSTRAINT fk_pf_plan FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pf_feature FOREIGN KEY (feature_code) REFERENCES feature_definitions(code) ON DELETE RESTRICT ON UPDATE CASCADE
);
COMMENT ON TABLE plan_features IS '套餐功能';
COMMENT ON COLUMN plan_features.plan_id IS '所属套餐';
COMMENT ON COLUMN plan_features.feature_code IS '功能编码';
COMMENT ON COLUMN plan_features.value IS '套餐赋予的值或限额';
COMMENT ON COLUMN plan_features.is_included IS '是否包含该功能';
COMMENT ON COLUMN plan_features.created_at IS '创建时间';
COMMENT ON COLUMN plan_features.updated_at IS '更新时间';

CREATE INDEX idx_plan_features_feature ON plan_features(feature_code);



CREATE TYPE subscription_status AS ENUM ('trialing', 'active', 'past_due', 'suspended', 'canceled', 'expired');
CREATE TABLE IF NOT EXISTS tenant_subscriptions (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    plan_version integer NOT NULL,
    plan_snapshot jsonb,
    status subscription_status NOT NULL DEFAULT 'trialing',
    started_at timestamptz NOT NULL,
    current_period_start timestamptz NOT NULL,
    current_period_end timestamptz NOT NULL,
    cancel_at timestamptz,
    canceled_at timestamptz,
    provider varchar(64),
    provider_subscription_id varchar(128),
    created_at timestamptz NOT NULL,
    updated_at timestamptz,
    CONSTRAINT uk_ts_provider_sub UNIQUE (provider, provider_subscription_id),
    CONSTRAINT fk_ts_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ts_plan FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE RESTRICT ON UPDATE CASCADE
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
CREATE UNIQUE INDEX uq_tenant_active_subscription ON tenant_subscriptions(tenant_id) WHERE status IN ('trialing', 'active', 'past_due', 'suspended');
CREATE INDEX idx_ts_tenant_status ON tenant_subscriptions(tenant_id, status);
CREATE INDEX idx_ts_period ON tenant_subscriptions(tenant_id, current_period_start, current_period_end);
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



CREATE TYPE entitlement_effect AS ENUM ('replace', 'disable');
CREATE TYPE entitlement_source_type AS ENUM ('trial', 'contract', 'manual', 'incident', 'migration');
CREATE TABLE IF NOT EXISTS tenant_entitlements (
    id uuid NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    feature_code text NOT NULL,
    effect entitlement_effect NOT NULL,
    value jsonb,
    priority integer NOT NULL DEFAULT 0,
    source_type entitlement_source_type NOT NULL,
    source_ref varchar(128),
    reason text,
    effective_from timestamptz NOT NULL,
    effective_until timestamptz,
    status api_key_status NOT NULL DEFAULT 'active',
    granted_by_user_id uuid NOT NULL,
    revoked_by_user_id uuid,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL,
    updated_at timestamptz,
    CONSTRAINT fk_te_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_te_feature FOREIGN KEY (feature_code) REFERENCES feature_definitions(code) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_te_granted_by FOREIGN KEY (granted_by_user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_te_revoked_by FOREIGN KEY (revoked_by_user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE
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
CREATE INDEX idx_tenant_entitlements_effective ON tenant_entitlements(tenant_id, feature_code, priority DESC) WHERE status = 'active';
CREATE INDEX idx_te_tenant_status ON tenant_entitlements(tenant_id, status);
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
COMMENT ON COLUMN tenant_entitlements.granted_by_user_id IS '授权平台用户';
COMMENT ON COLUMN tenant_entitlements.revoked_by_user_id IS '撤销平台用户';
COMMENT ON COLUMN tenant_entitlements.revoked_at IS '撤销时间';
COMMENT ON COLUMN tenant_entitlements.created_at IS '创建时间';
COMMENT ON COLUMN tenant_entitlements.updated_at IS '更新时间';



CREATE TABLE IF NOT EXISTS tenant_feature_usages (
    tenant_id uuid NOT NULL,
    feature_code text NOT NULL,
    period_start timestamptz NOT NULL,
    period_end timestamptz NOT NULL,
    usage_value bigint NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (tenant_id, feature_code, period_start),
    CONSTRAINT ck_tfu_usage_value CHECK (usage_value >= 0),
    CONSTRAINT ck_tfu_period CHECK (period_end > period_start),
    CONSTRAINT fk_tfu_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tfu_feature FOREIGN KEY (feature_code) REFERENCES feature_definitions(code) ON DELETE RESTRICT ON UPDATE CASCADE
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