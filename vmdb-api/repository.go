package main

import (
	"context"
	"database/sql"
	"errors"

	"github.com/google/uuid"
	"github.com/uptrace/bun"
)

// ignoredTeams is a list of teams that should be ignored by exporter.
var ignoredTeams = []string{"staff", "team99", "audience"}

type Repository struct {
	db *bun.DB
}

func NewRepository(db *bun.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) findConfigBy(ctx context.Context, key string) (*Config, error) {
	var result Config
	err := r.db.NewSelect().Model(&result).
		Where("key = ?", key).
		Scan(ctx)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

func (r *Repository) listProblemEnvironments(ctx context.Context) ([]ProblemEnvironment, error) {
	var result []ProblemEnvironment
	if err := r.db.NewSelect().Model(&result).Scan(ctx); err != nil {
		return nil, err
	}
	return result, nil
}

func (r *Repository) findProblemEnvironmentBy(ctx context.Context, name string) (*ProblemEnvironment, error) {
	var result ProblemEnvironment
	err := r.db.NewSelect().Model(&result).
		Where("name = ?", name).
		Scan(ctx)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

func (r *Repository) findProblemBy(ctx context.Context, code string) (*Problem, error) {
	var result Problem
	err := r.db.NewSelect().Model(&result).
		Where("code = ?", code).
		Scan(ctx)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

func (r *Repository) listLatestUnscoredAnswersFor(ctx context.Context, problemID uuid.UUID) ([]Answer, error) {
	var result []Answer
	err := r.db.NewSelect().ColumnExpr("answers.*").
		Table("answers").
		Join("INNER JOIN scores").JoinOn("answers.id = scores.answer_id").
		Where("point IS NULL").
		Where("problem_id = ?", problemID).
		Order("created_at DESC").
		Scan(ctx, &result)
	if err != nil {
		return nil, err
	}
	return result, nil
}

func (r *Repository) findLatestAnswerFor(ctx context.Context, problemID, teamID string) (*Answer, error) {
	var result Answer
	err := r.db.NewSelect().Model(&result).
		Where("team_id = ?", teamID).
		Where("problem_id = ?", problemID).
		Order("created_at DESC").
		Limit(1).
		Scan(ctx)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &result, nil
}