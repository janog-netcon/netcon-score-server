package main

import (
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"
)

type Config struct {
	bun.BaseModel `bun:"table:configs"`

	ID    uuid.UUID `bun:"id"`
	Key   string    `bun:"key"`
	Vaule string    `bun:"value"`
}

type Problem struct {
	bun.BaseModel `bun:"table:problems"`

	ID   uuid.UUID `bun:"id"`
	Code string    `bun:"code"`
}

type ProblemEnvironment struct {
	bun.BaseModel `bun:"table:problem_environments" json:"-"`

	ID          uuid.UUID `bun:"id" json:"id"`
	InnerStatus *string   `bun:"status" json:"inner_status"`
	Host        string    `bun:"host" json:"host"`
	User        string    `bun:"user" json:"user"`
	Password    string    `bun:"password" json:"password"`
	ProblemID   uuid.UUID `bun:"problem_id" json:"problem_id"`
	TeamID      uuid.UUID `bun:"team_id" json:"team_id"`
	SecretText  string    `bun:"secret_text" json:"secret_text"`
	Name        string    `bun:"name" json:"name"`
	Service     string    `bun:"service" json:"service"`
	Port        uint16    `bun:"port" json:"port"`
	CreatedAt   time.Time `bun:"created_at" json:"created_at"`
	UpdatedAt   time.Time `bun:"updated_at" json:"updated_at"`
}

type Answer struct {
	bun.BaseModel `bun:"table:answers" json:"-"`

	ID         uuid.UUID  `bun:"id"`
	Bodies     [][]string `bun:"bodies,type:jsonb"`
	Confirming bool       `bun:"confirming"`
	ProblemID  uuid.UUID  `bun:"problem_id"`
	TeamID     uuid.UUID  `bun:"team_id"`
	CreatedAt  time.Time  `bun:"created_at"`
	UpdatedAt  time.Time  `bun:"updated_at"`
}
