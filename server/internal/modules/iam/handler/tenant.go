package handler

import (
	"errors"

	"asriel.cn/asaas/server/internal/middleware"
	"asriel.cn/asaas/server/internal/modules/iam/service"
	"asriel.cn/asaas/server/internal/platform/i18n"
	"asriel.cn/asaas/server/internal/platform/response"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type TenantHandler struct {
	tenantService *service.TenantService
}

func (handler *TenantHandler) Register(g *gin.RouterGroup) {
	group := g.Group("/tenant", middleware.Module("TENANT"))
	group.POST("create", middleware.Action("CREATE"), handler.create)
	group.POST("invite", middleware.Action("INVITE"), handler.invite)
	group.POST("member/disable", middleware.Action("DISABLE_MEMBER"), handler.disableMember)
	group.POST("member/remove", middleware.Action("REMOVE_MEMBER"), handler.removeMember)
}

func (handler *TenantHandler) create(c *gin.Context) {
	lang := i18n.GetLanguage(c.Request.Context())

	slug := c.PostForm("slug")
	name := c.PostForm("name")

	tenantID, err := handler.tenantService.CreateTenant(c.Request.Context(), slug, name)
	if err != nil {
		if errors.Is(err, service.ErrInvalidSlug) || errors.Is(err, service.ErrInvalidTenantName) {
			response.Error(c, response.ParamErrorCode, i18n.T(lang, "iam.tenant.invalid_param"))
			return
		}
		response.Error(c, response.BusinessErrorCode, i18n.T(lang, "iam.tenant.create_failed"))
		return
	}

	response.Success(c, gin.H{"tenant_id": tenantID})
}

func (handler *TenantHandler) invite(c *gin.Context) {
	lang := i18n.GetLanguage(c.Request.Context())

	tenantID, err := uuid.Parse(c.PostForm("tenant_id"))
	if err != nil {
		response.Error(c, response.ParamErrorCode, i18n.T(lang, "iam.tenant.invalid_param"))
		return
	}

	userID, err := uuid.Parse(c.PostForm("user_id"))
	if err != nil {
		response.Error(c, response.ParamErrorCode, i18n.T(lang, "iam.tenant.invalid_param"))
		return
	}

	if err := handler.tenantService.InviteMember(c.Request.Context(), tenantID, userID); err != nil {
		if errors.Is(err, service.ErrAlreadyMember) {
			response.Error(c, response.BusinessErrorCode, i18n.T(lang, "iam.tenant.already_member"))
			return
		}
		response.Error(c, response.BusinessErrorCode, i18n.T(lang, "iam.tenant.invite_failed"))
		return
	}

	response.Success(c, nil)
}

func (handler *TenantHandler) disableMember(c *gin.Context) {
	lang := i18n.GetLanguage(c.Request.Context())

	tenantID, err := uuid.Parse(c.PostForm("tenant_id"))
	if err != nil {
		response.Error(c, response.ParamErrorCode, i18n.T(lang, "iam.tenant.invalid_param"))
		return
	}

	userID, err := uuid.Parse(c.PostForm("user_id"))
	if err != nil {
		response.Error(c, response.ParamErrorCode, i18n.T(lang, "iam.tenant.invalid_param"))
		return
	}

	if err := handler.tenantService.DisableMember(c.Request.Context(), tenantID, userID); err != nil {
		response.Error(c, response.BusinessErrorCode, i18n.T(lang, "iam.tenant.disable_member_failed"))
		return
	}

	response.Success(c, nil)
}

func (handler *TenantHandler) removeMember(c *gin.Context) {
	lang := i18n.GetLanguage(c.Request.Context())

	tenantID, err := uuid.Parse(c.PostForm("tenant_id"))
	if err != nil {
		response.Error(c, response.ParamErrorCode, i18n.T(lang, "iam.tenant.invalid_param"))
		return
	}

	userID, err := uuid.Parse(c.PostForm("user_id"))
	if err != nil {
		response.Error(c, response.ParamErrorCode, i18n.T(lang, "iam.tenant.invalid_param"))
		return
	}

	if err := handler.tenantService.RemoveMember(c.Request.Context(), tenantID, userID); err != nil {
		response.Error(c, response.BusinessErrorCode, i18n.T(lang, "iam.tenant.remove_member_failed"))
		return
	}

	response.Success(c, nil)
}
