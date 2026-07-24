package response

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type Response struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
	TraceID string `json:"trace_id,omitempty"`
}

func Result(c *gin.Context, httpCode int, code int, message string, data any) {
	c.JSON(httpCode, Response{
		Code:    code,
		Message: message,
		Data:    data,
	})
}

func Success(c *gin.Context, data any) {
	Result(c, http.StatusOK, OK, "success", data)
}

func Error(c *gin.Context, code int, message string) {
	Result(c, http.StatusOK, code, message, nil)
}

func BusinessError(c *gin.Context, msg string) {
	Result(c, http.StatusOK, BusinessErrorCode, msg, nil)
}
