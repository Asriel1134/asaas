package handler

import (
	"errors"
	"time"

	"asriel.cn/asaas/server/internal/middleware"
	"asriel.cn/asaas/server/internal/modules/iam/auth"
	"asriel.cn/asaas/server/internal/modules/iam/db/sqlc"
	"asriel.cn/asaas/server/internal/modules/iam/service"
	"asriel.cn/asaas/server/internal/pkg/access"
	"asriel.cn/asaas/server/internal/platform/database"
	"asriel.cn/asaas/server/internal/platform/i18n"
	"asriel.cn/asaas/server/internal/platform/response"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type NavigationEntry struct {
	Type         string     `json:"type"`
	TenantID     *uuid.UUID `json:"tenant_id,omitempty"`
	Slug         string     `json:"slug"`
	Name         string     `json:"name"`
	TenantStatus string     `json:"tenant_status,omitempty"`
	MemberStatus string     `json:"member_status,omitempty"`
	JobTitle     *string    `json:"job_title,omitempty"`
	EmployeeNo   *string    `json:"employee_no,omitempty"`
}

type SelectContextRequest struct {
	Type     access.Realm `form:"type" json:"type" binding:"required,oneof=tenant platform"`
	TenantID string       `form:"tenant_id" json:"tenant_id"`
}

type SelectedContext struct {
	Type     access.Realm `json:"type"`
	TenantID *uuid.UUID   `json:"tenant_id"`
}

type SelectContextResponse struct {
	Context     SelectedContext           `json:"context"`
	Permissions []service.PermissionGrant `json:"permissions"`
}

type AuthHandler struct {
	sessionService    *service.SessionService
	userService       *service.UserService
	permissionService *service.PermissionService
}

func (handler *AuthHandler) Register(g *gin.RouterGroup) {
	group := g.Group("/auth", middleware.Module("AUTH"))
	group.POST("login/password", middleware.Action("LOGIN_BY_PASSWORD"), handler.loginByPassword)
	group.POST("logout", middleware.Action("LOGOUT"), handler.logout)
	group.POST("context", middleware.Action("SELECT_CONTEXT"), handler.selectContext)
}

func (handler *AuthHandler) loginByPassword(c *gin.Context) {
	lang := i18n.GetLanguage(c.Request.Context())

	kind := sqlc.IdentifierKind(c.PostForm("kind"))
	if kind != sqlc.IdentifierKindEmail && kind != sqlc.IdentifierKindPhone && kind != sqlc.IdentifierKindUsername {
		response.Error(c, response.ParamErrorCode, i18n.T(lang, "iam.login.invalid_kind"))
		return
	}

	identifier := c.PostForm("identifier")
	credential := c.PostForm("credential")

	i, err := database.Tx[sqlc.GetLoginIdentifierRow](c.Request.Context(),
		func(tx pgx.Tx) (sqlc.GetLoginIdentifierRow, error) {
			return sqlc.New(database.DB).GetLoginIdentifier(
				c.Request.Context(),
				sqlc.GetLoginIdentifierParams{Kind: kind, Value: identifier})
		})

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.invalid_credentials"))
			return
		}
		response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.login_failed"))
		return
	}

	if len(i.PasswordHash) == 0 {
		response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.password_not_set"))
		return
	}

	isVerified, err := auth.VerifyPassword(credential, i.PasswordHash)
	if err != nil || !isVerified {
		_ = handler.userService.RecordFailedAttempt(c.Request.Context(), i.UserID)
		response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.invalid_credentials"))
		return
	}

	switch i.Status {
	case sqlc.UserStatusLocked:
		response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.account_locked"))
		return
	case sqlc.UserStatusDeleted:
		response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.account_deleted"))
		return
	}

	if i.LockedUntil.Valid && i.LockedUntil.Time.After(time.Now()) {
		response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.account_locked"))
		return
	}

	if i.LockedUntil.Valid && i.LockedUntil.Time.Before(time.Now()) {
		_ = handler.userService.ResetFailedAttempts(c.Request.Context(), i.UserID)
	}

	if i.MustChangePassword {
		response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.must_change_password"))
		return
	}

	tenants, err := database.Tx[[]sqlc.GetUserTenantsRow](c.Request.Context(),
		func(tx pgx.Tx) ([]sqlc.GetUserTenantsRow, error) {
			return sqlc.New(database.DB).GetUserTenants(
				c.Request.Context(),
				i.UserID)
		})

	if err != nil {
		response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.login_failed"))
		return
	}

	err = handler.sessionService.CreateSession(c, i)
	if err != nil {
		response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.login_failed"))
		return
	}

	entries := make([]NavigationEntry, 0, len(tenants))
	for _, r := range tenants {
		e := NavigationEntry{
			Type:         "tenant",
			Slug:         r.TenantSlug.String,
			Name:         r.TenantName.String,
			MemberStatus: string(r.MemberStatus),
		}
		if r.TenantID.Valid {
			id := uuid.UUID(r.TenantID.Bytes)
			e.TenantID = &id
		}
		if r.TenantStatus.Valid {
			e.TenantStatus = string(r.TenantStatus.TenantStatus)
		}
		if r.JobTitle.Valid {
			e.JobTitle = &r.JobTitle.String
		}
		if r.EmployeeNo.Valid {
			e.EmployeeNo = &r.EmployeeNo.String
		}
		entries = append(entries, e)
	}

	isPlatformUser, _ := handler.permissionService.IsPlatformUser(c.Request.Context(), i.UserID)
	if isPlatformUser {
		platformEntry := NavigationEntry{
			Type: "platform",
			Slug: "platform",
			Name: i18n.T(lang, "iam.login.platform_entry"),
		}
		entries = append([]NavigationEntry{platformEntry}, entries...)
	}

	response.Success(c, entries)
}

func (handler *AuthHandler) selectContext(c *gin.Context) {
	lang := i18n.GetLanguage(c.Request.Context())

	acc, ok := access.Get(c.Request.Context())
	if !ok {
		response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.login_failed"))
		return
	}

	if acc.Realm != access.RealmPending {
		response.Error(c, response.BusinessErrorCode, i18n.T(lang, "iam.login.context_already_selected"))
		return
	}

	var req SelectContextRequest
	if err := c.ShouldBind(&req); err != nil {
		response.Error(c, response.ParamErrorCode, i18n.T(lang, "iam.login.invalid_context"))
		return
	}

	switch req.Type {
	case access.RealmTenant:
		tenantID, err := uuid.Parse(req.TenantID)
		if err != nil {
			response.Error(c, response.ParamErrorCode, i18n.T(lang, "iam.login.invalid_tenant"))
			return
		}

		if err := handler.sessionService.SelectTenantContext(c.Request.Context(), acc.SessionID, tenantID); err != nil {
			if errors.Is(err, service.ErrContextSelectionDenied) {
				response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.tenant_access_denied"))
				return
			}
			response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.login_failed"))
			return
		}
		selectedAcc, err := handler.sessionService.GetAuthorizationContext(c.Request.Context(), acc.SessionID)
		if err != nil {
			response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.login_failed"))
			return
		}
		snapshot, err := handler.permissionService.GetSnapshot(c.Request.Context(), selectedAcc)
		if err != nil {
			response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.login_failed"))
			return
		}

		response.Success(c, SelectContextResponse{
			Context:     SelectedContext{Type: access.RealmTenant, TenantID: &tenantID},
			Permissions: snapshot.List(),
		})

	case access.RealmPlatform:
		if req.TenantID != "" {
			response.Error(c, response.ParamErrorCode, i18n.T(lang, "iam.login.invalid_context"))
			return
		}

		if err := handler.sessionService.SelectPlatformContext(c.Request.Context(), acc.SessionID); err != nil {
			if errors.Is(err, service.ErrContextSelectionDenied) {
				response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.platform_access_denied"))
				return
			}
			response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.login_failed"))
			return
		}
		selectedAcc, err := handler.sessionService.GetAuthorizationContext(c.Request.Context(), acc.SessionID)
		if err != nil {
			response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.login_failed"))
			return
		}
		snapshot, err := handler.permissionService.GetSnapshot(c.Request.Context(), selectedAcc)
		if err != nil {
			response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.login_failed"))
			return
		}

		response.Success(c, SelectContextResponse{
			Context:     SelectedContext{Type: access.RealmPlatform},
			Permissions: snapshot.List(),
		})

	default:
		response.Error(c, response.ParamErrorCode, i18n.T(lang, "iam.login.invalid_context"))
	}
}

func (handler *AuthHandler) logout(c *gin.Context) {
	lang := i18n.GetLanguage(c.Request.Context())

	if err := handler.sessionService.RevokeSession(c); err != nil {
		response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.logout_failed"))
		return
	}

	response.Success(c, nil)
}
