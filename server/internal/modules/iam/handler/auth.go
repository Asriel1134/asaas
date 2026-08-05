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

type AuthHandler struct {
	sessionService *service.SessionService
	userService    *service.UserService
}

func (handler *AuthHandler) Register(g *gin.RouterGroup) {
	group := g.Group("/auth", middleware.Module("AUTH"))
	group.POST("login/password", middleware.Action("LOGIN_BY_PASSWORD"), handler.loginByPassword)
	group.POST("logout", middleware.Action("LOGOUT"), handler.logout)
	group.POST("tenant", middleware.Action("SELECT_TENANT"), handler.selectTenant)
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

	switch i.Status.UserStatus {
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

	response.Success(c, tenants)
}

func (handler *AuthHandler) selectTenant(c *gin.Context) {
	lang := i18n.GetLanguage(c.Request.Context())

	acc, ok := access.Get(c.Request.Context())
	if !ok {
		response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.login_failed"))
		return
	}

	tenantID, err := uuid.Parse(c.PostForm("tenant_id"))
	if err != nil {
		response.Error(c, response.ParamErrorCode, i18n.T(lang, "iam.login.invalid_tenant"))
		return
	}

	if err := handler.sessionService.SetSessionTenant(c.Request.Context(), acc.SessionID, tenantID); err != nil {
		if errors.Is(err, service.ErrTenantAlreadySet) {
			response.Error(c, response.BusinessErrorCode, i18n.T(lang, "iam.login.tenant_already_set"))
			return
		}
		response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.login_failed"))
		return
	}

	response.Success(c, nil)
}

func (handler *AuthHandler) logout(c *gin.Context) {
	lang := i18n.GetLanguage(c.Request.Context())

	if err := handler.sessionService.RevokeSession(c); err != nil {
		response.Error(c, response.AuthenticationErrorCode, i18n.T(lang, "iam.login.logout_failed"))
		return
	}

	response.Success(c, nil)
}
