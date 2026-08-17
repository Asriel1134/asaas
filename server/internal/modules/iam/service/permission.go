package service

import (
	"context"

	"asriel.cn/asaas/server/internal/modules/iam/db/sqlc"
	"asriel.cn/asaas/server/internal/platform/database"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

type PermissionService struct {
}

func (service *PermissionService) IsPlatformUser(c context.Context, userId uuid.UUID) (bool, error) {
	return sqlc.New(database.DB).IsPlatformUser(c, userId)
}

func (service *PermissionService) GetTenantPermissions(c context.Context, userId, tenantId, workspaceId uuid.UUID) ([]sqlc.GetTenantPermissionsRow, error) {
	return sqlc.New(database.DB).GetTenantPermissions(c, sqlc.GetTenantPermissionsParams{
		Userid:   userId,
		Tenantid: tenantId,
		Workspaceid: pgtype.UUID{
			Bytes: workspaceId,
			Valid: workspaceId != uuid.Nil,
		},
	})
}

func (service *PermissionService) GetPlatformPermissions(c context.Context, userId uuid.UUID) ([]sqlc.GetPlatformPermissionsRow, error) {
	return sqlc.New(database.DB).GetPlatformPermissions(c, userId)
}
