package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"time"

	"asriel.cn/asaas/server/internal/modules/iam/db/sqlc"
	"asriel.cn/asaas/server/internal/pkg/access"
	"asriel.cn/asaas/server/internal/platform/cache"
	"asriel.cn/asaas/server/internal/platform/database"
	"asriel.cn/asaas/server/internal/platform/logger"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"golang.org/x/sync/singleflight"
)

const permissionCacheTTL = 30 * time.Minute

var (
	ErrUnsupportedAuthorizationRealm = errors.New("unsupported authorization realm")
	permissionSnapshotLoads          singleflight.Group
)

type PermissionBinding struct {
	Scope       string     `json:"scope"`
	WorkspaceID *uuid.UUID `json:"workspace_id,omitempty"`
	OrgUnitID   *uuid.UUID `json:"org_unit_id,omitempty"`
}

type PermissionGrant struct {
	Code              string              `json:"code"`
	Module            string              `json:"module"`
	Resource          string              `json:"resource"`
	Action            string              `json:"action"`
	Name              string              `json:"name"`
	RiskLevel         string              `json:"risk_level"`
	SupportsDataScope bool                `json:"supports_data_scope"`
	Bindings          []PermissionBinding `json:"bindings,omitempty"`
}

type PermissionSnapshot struct {
	Realm                access.Realm               `json:"realm"`
	TenantID             *uuid.UUID                 `json:"tenant_id,omitempty"`
	UserID               uuid.UUID                  `json:"user_id"`
	WorkspaceID          *uuid.UUID                 `json:"workspace_id,omitempty"`
	CatalogAuthzVersion  int64                      `json:"catalog_authz_version"`
	TenantAuthzVersion   int64                      `json:"tenant_authz_version,omitempty"`
	SubjectAuthzVersion  int64                      `json:"subject_authz_version"`
	PlatformAuthzVersion int64                      `json:"platform_authz_version,omitempty"`
	Permissions          map[string]PermissionGrant `json:"permissions"`
	GeneratedAt          time.Time                  `json:"generated_at"`
}

func (snapshot *PermissionSnapshot) MarshalBinary() ([]byte, error) {
	return json.Marshal(snapshot)
}

func (snapshot *PermissionSnapshot) UnmarshalBinary(data []byte) error {
	return json.Unmarshal(data, snapshot)
}

func (snapshot *PermissionSnapshot) Has(permissionCode string) bool {
	_, ok := snapshot.Permissions[permissionCode]
	return ok
}

func (snapshot *PermissionSnapshot) List() []PermissionGrant {
	permissions := make([]PermissionGrant, 0, len(snapshot.Permissions))
	for _, permission := range snapshot.Permissions {
		permissions = append(permissions, permission)
	}
	sort.Slice(permissions, func(i, j int) bool {
		return permissions[i].Code < permissions[j].Code
	})
	return permissions
}

func (snapshot *PermissionSnapshot) Matches(acc access.Context) bool {
	if snapshot.Realm != acc.Realm || snapshot.UserID != acc.UserID ||
		snapshot.CatalogAuthzVersion != acc.CatalogAuthzVersion ||
		snapshot.SubjectAuthzVersion != acc.SubjectAuthzVersion {
		return false
	}
	switch acc.Realm {
	case access.RealmTenant:
		return snapshot.TenantID != nil && *snapshot.TenantID == acc.TenantID &&
			equalOptionalUUID(snapshot.WorkspaceID, acc.WorkspaceID) &&
			snapshot.TenantAuthzVersion == acc.TenantAuthzVersion
	case access.RealmPlatform:
		return snapshot.TenantID == nil && snapshot.PlatformAuthzVersion == acc.PlatformAuthzVersion
	default:
		return false
	}
}

type PermissionService struct {
}

func (*PermissionService) IsPlatformUser(ctx context.Context, userID uuid.UUID) (bool, error) {
	return sqlc.New(database.DB).IsPlatformUser(ctx, userID)
}

func (*PermissionService) GetSnapshot(ctx context.Context, acc access.Context) (*PermissionSnapshot, error) {
	key, err := PermissionCacheKey(acc)
	if err != nil {
		return nil, err
	}

	if snapshot, found := getCachedPermissionSnapshot(ctx, key, acc); found {
		return snapshot, nil
	}

	loaded, err, _ := permissionSnapshotLoads.Do(key, func() (any, error) {
		if snapshot, found := getCachedPermissionSnapshot(ctx, key, acc); found {
			return snapshot, nil
		}

		snapshot, ttl, loadErr := loadPermissionSnapshot(ctx, acc)
		if loadErr != nil {
			return nil, loadErr
		}
		if cache.Cache != nil {
			if cacheErr := cache.Cache.Set(ctx, key, snapshot, ttl); cacheErr != nil && logger.S != nil {
				logger.FromContext(ctx).Warnw("failed to cache permission snapshot", "key", key, "error", cacheErr)
			}
		}
		return snapshot, nil
	})
	if err != nil {
		return nil, err
	}
	return loaded.(*PermissionSnapshot), nil
}

func PermissionCacheKey(acc access.Context) (string, error) {
	switch acc.Realm {
	case access.RealmTenant:
		workspaceID := "none"
		if acc.WorkspaceID != uuid.Nil {
			workspaceID = acc.WorkspaceID.String()
		}
		return fmt.Sprintf("authz:v1:tenant:%s:%s:%s:%d:%d:%d",
			acc.TenantID, acc.UserID, workspaceID,
			acc.CatalogAuthzVersion, acc.TenantAuthzVersion, acc.SubjectAuthzVersion), nil
	case access.RealmPlatform:
		return fmt.Sprintf("authz:v1:platform:%s:%d:%d:%d",
			acc.UserID, acc.CatalogAuthzVersion, acc.PlatformAuthzVersion, acc.SubjectAuthzVersion), nil
	default:
		return "", ErrUnsupportedAuthorizationRealm
	}
}

func getCachedPermissionSnapshot(ctx context.Context, key string, acc access.Context) (*PermissionSnapshot, bool) {
	if cache.Cache == nil {
		return nil, false
	}
	snapshot := &PermissionSnapshot{}
	found, err := cache.Cache.Get(ctx, key, snapshot)
	if err != nil {
		if logger.S != nil {
			logger.FromContext(ctx).Warnw("failed to read permission snapshot cache", "key", key, "error", err)
		}
		return nil, false
	}
	if !found || !snapshot.Matches(acc) {
		return nil, false
	}
	return snapshot, true
}

func loadPermissionSnapshot(ctx context.Context, acc access.Context) (*PermissionSnapshot, time.Duration, error) {
	authzCtx := access.Set(ctx, acc)
	result, err := database.Tx[permissionLoadResult](authzCtx, func(tx pgx.Tx) (permissionLoadResult, error) {
		queries := sqlc.New(tx)
		snapshot := newPermissionSnapshot(acc)
		deadline := time.Now().Add(permissionCacheTTL)

		switch acc.Realm {
		case access.RealmTenant:
			rows, queryErr := queries.GetTenantPermissions(authzCtx, sqlc.GetTenantPermissionsParams{
				Userid:   acc.UserID,
				Tenantid: acc.TenantID,
				Workspaceid: pgtype.UUID{
					Bytes: acc.WorkspaceID,
					Valid: acc.WorkspaceID != uuid.Nil,
				},
			})
			if queryErr != nil {
				return permissionLoadResult{}, queryErr
			}
			for _, row := range rows {
				addTenantPermission(snapshot, row)
			}
			deadline, queryErr = queries.GetTenantPermissionDeadline(authzCtx, sqlc.GetTenantPermissionDeadlineParams{
				Userid: acc.UserID, Tenantid: acc.TenantID,
			})
			if queryErr != nil {
				return permissionLoadResult{}, queryErr
			}

		case access.RealmPlatform:
			rows, queryErr := queries.GetPlatformPermissions(authzCtx, acc.UserID)
			if queryErr != nil {
				return permissionLoadResult{}, queryErr
			}
			for _, row := range rows {
				snapshot.Permissions[row.Code] = PermissionGrant{
					Code: row.Code, Module: row.Module, Resource: row.Resource, Action: row.Action,
					Name: row.Name, RiskLevel: string(row.RiskLevel), SupportsDataScope: row.SupportsDataScope,
				}
			}
			deadline, queryErr = queries.GetPlatformPermissionDeadline(authzCtx, acc.UserID)
			if queryErr != nil {
				return permissionLoadResult{}, queryErr
			}

		default:
			return permissionLoadResult{}, ErrUnsupportedAuthorizationRealm
		}

		return permissionLoadResult{snapshot: snapshot, deadline: deadline}, nil
	})
	if err != nil {
		return nil, 0, err
	}
	return result.snapshot, permissionTTL(result.deadline), nil
}

type permissionLoadResult struct {
	snapshot *PermissionSnapshot
	deadline time.Time
}

func permissionTTL(deadline time.Time) time.Duration {
	ttl := time.Until(deadline)
	if ttl > permissionCacheTTL {
		ttl = permissionCacheTTL
	}
	if ttl < time.Second {
		ttl = time.Second
	}
	return ttl
}

func newPermissionSnapshot(acc access.Context) *PermissionSnapshot {
	snapshot := &PermissionSnapshot{
		Realm: acc.Realm, UserID: acc.UserID,
		CatalogAuthzVersion: acc.CatalogAuthzVersion, TenantAuthzVersion: acc.TenantAuthzVersion,
		SubjectAuthzVersion: acc.SubjectAuthzVersion, PlatformAuthzVersion: acc.PlatformAuthzVersion,
		Permissions: make(map[string]PermissionGrant), GeneratedAt: time.Now().UTC(),
	}
	if acc.TenantID != uuid.Nil {
		tenantID := acc.TenantID
		snapshot.TenantID = &tenantID
	}
	if acc.WorkspaceID != uuid.Nil {
		workspaceID := acc.WorkspaceID
		snapshot.WorkspaceID = &workspaceID
	}
	return snapshot
}

func addTenantPermission(snapshot *PermissionSnapshot, row sqlc.GetTenantPermissionsRow) {
	grant, ok := snapshot.Permissions[row.Code]
	if !ok {
		grant = PermissionGrant{
			Code: row.Code, Module: row.Module, Resource: row.Resource, Action: row.Action,
			Name: row.Name, RiskLevel: string(row.RiskLevel), SupportsDataScope: row.SupportsDataScope,
		}
	}
	binding := PermissionBinding{Scope: string(row.BindingScope)}
	if row.WorkspaceID.Valid {
		workspaceID := uuid.UUID(row.WorkspaceID.Bytes)
		binding.WorkspaceID = &workspaceID
	}
	if row.OrgUnitID.Valid {
		orgUnitID := uuid.UUID(row.OrgUnitID.Bytes)
		binding.OrgUnitID = &orgUnitID
	}
	if !containsBinding(grant.Bindings, binding) {
		grant.Bindings = append(grant.Bindings, binding)
	}
	snapshot.Permissions[row.Code] = grant
}

func containsBinding(bindings []PermissionBinding, target PermissionBinding) bool {
	for _, binding := range bindings {
		if binding.Scope == target.Scope && equalUUIDPointer(binding.WorkspaceID, target.WorkspaceID) && equalUUIDPointer(binding.OrgUnitID, target.OrgUnitID) {
			return true
		}
	}
	return false
}

func equalUUIDPointer(left, right *uuid.UUID) bool {
	if left == nil || right == nil {
		return left == nil && right == nil
	}
	return *left == *right
}

func equalOptionalUUID(value *uuid.UUID, expected uuid.UUID) bool {
	if expected == uuid.Nil {
		return value == nil
	}
	return value != nil && *value == expected
}
