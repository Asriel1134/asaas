package i18n

import (
	"embed"
	"encoding/json"
	"fmt"
	"io/fs"
	"strings"

	"github.com/nicksnyder/go-i18n/v2/i18n"
	"golang.org/x/text/language"
)

var (
	bundle             *i18n.Bundle
	defaultLanguage    = language.English
	supportedLanguages = []language.Tag{
		language.English,
		language.Chinese,
	}
)

//go:embed locales
var translationFS embed.FS

func Init() {
	bundle = i18n.NewBundle(defaultLanguage)
	bundle.RegisterUnmarshalFunc("json", json.Unmarshal)

	err := fs.WalkDir(translationFS, "locales", func(filePath string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || !strings.HasSuffix(d.Name(), ".json") {
			return nil
		}

		data, err := translationFS.ReadFile(filePath)
		if err != nil {
			return fmt.Errorf("failed to read locale file %s: %w", filePath, err)
		}

		_, err = bundle.ParseMessageFileBytes(data, filePath)
		if err != nil {
			return fmt.Errorf("failed to parse locale file %s: %w", filePath, err)
		}
		return nil
	})
	if err != nil {
		panic(fmt.Errorf("failed to load locales: %w", err))
	}
}

func NewLocalizer(lang string) *i18n.Localizer {
	if lang == "" {
		return i18n.NewLocalizer(bundle, defaultLanguage.String())
	}
	return i18n.NewLocalizer(bundle, lang, defaultLanguage.String())
}

func T(lang, messageID string) string {
	localizer := NewLocalizer(lang)
	msg, err := localizer.Localize(&i18n.LocalizeConfig{
		MessageID: messageID,
	})
	if err != nil {
		return messageID
	}
	return msg
}

func TWD(lang, messageID string, templateData map[string]any) string {
	localizer := NewLocalizer(lang)
	msg, err := localizer.Localize(&i18n.LocalizeConfig{
		MessageID:    messageID,
		TemplateData: templateData,
	})
	if err != nil {
		return messageID
	}
	return msg
}

func TP(lang, messageID string, count any, templateData map[string]any) string {
	localizer := NewLocalizer(lang)
	msg, err := localizer.Localize(&i18n.LocalizeConfig{
		MessageID:    messageID,
		PluralCount:  count,
		TemplateData: templateData,
	})
	if err != nil {
		return messageID
	}
	return msg
}
