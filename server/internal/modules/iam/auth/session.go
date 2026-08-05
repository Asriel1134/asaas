package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
)

const (
	TokenLength       = 32
	SessionCookieName = "session"
)

// GenerateToken returns a cryptographically random hex-encoded token.
// The raw length is TokenLength bytes, encoded as 2×TokenLength hex characters.
func GenerateToken() (string, error) {
	b := make([]byte, TokenLength)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("generate token: %w", err)
	}
	return hex.EncodeToString(b), nil
}

// HashToken computes the SHA-256 hash of a token for secure storage.
// Only the hash is persisted — a DB compromise cannot steal active sessions.
func HashToken(token string) ([]byte, error) {
	b, err := hex.DecodeString(token)
	if err != nil {
		return nil, fmt.Errorf("decode token: %w", err)
	}
	hash := sha256.Sum256(b)
	return hash[:], nil
}
