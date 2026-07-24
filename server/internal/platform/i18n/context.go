package i18n

import (
	"context"

	"golang.org/x/text/language"
)

type langKey struct{}

func WithLanguage(ctx context.Context, lang string) context.Context {
	return context.WithValue(ctx, langKey{}, lang)
}

func GetLanguage(ctx context.Context) string {
	if lang, ok := ctx.Value(langKey{}).(string); ok {
		return lang
	}
	return defaultLanguage.String()
}

func MatchLanguage(accept string) string {
	tags, _, err := language.ParseAcceptLanguage(accept)
	if err != nil || len(tags) == 0 {
		return defaultLanguage.String()
	}

	matcher := language.NewMatcher(supportedLanguages)
	_, index, _ := matcher.Match(tags...)
	return supportedLanguages[index].String()
}
