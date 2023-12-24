package main

import (
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"
)

type Answer struct {
	ID        uuid.UUID `bun:"id"`
	ProblemID uuid.UUID `bun:"problem_id"`
	TeamID    uuid.UUID `bun:"team_id"`
	Point     *int      `bun:"point"`
	CreatedAt time.Time `bun:"created_at"`
}

type Problem struct {
	bun.BaseModel `bun:"table:problems"`

	ID         uuid.UUID `bun:"id"`
	Code       string    `bun:"code"`
	CategoryID uuid.UUID `bun:"category_id"`
}

type Score struct {
	bun.BaseModel `bun:"table:scores"`

	ID     uuid.UUID `bun:"id"`
	Point  int       `bun:"point"`
	Solved bool      `bun:"solved"`
}

type Team struct {
	bun.BaseModel `bun:"table:teams"`

	ID           uuid.UUID `bun:"id"`
	Name         string    `bun:"name"`
	Organization string    `bun:"organization"`
}

type Config struct {
	bun.BaseModel `bun:"table:configs"`

	ID  uuid.UUID `bun:"id"`
	Key string    `bun:"key"`

	// The actual type of Value is JSONB, but to parse it correctly, it is defined as string.
	Vaule string `bun:"value"`
}
