package id

import "github.com/google/uuid"

func UUID() uuid.UUID {
	id, _ := uuid.NewV7()
	return id
}
