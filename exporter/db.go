package main

import (
	"context"

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

// Answer

func (r *Repository) FindTeams(ctx context.Context) ([]Team, error) {
	var teams []Team
	err := r.db.NewSelect().
		Model(&teams).
		Where("name NOT IN (?)", bun.In(ignoredTeams)).
		Scan(ctx)
	if err != nil {
		return nil, err
	}
	return teams, nil
}

func (r *Repository) FindScores(ctx context.Context) ([]Score, error) {
	var scores []Score
	if err := r.db.NewSelect().Model(&scores).Scan(ctx); err != nil {
		return nil, err
	}
	return scores, nil
}

func (r *Repository) FindAnswers(ctx context.Context) ([]Answer, error) {
	answers := []Answer{}
	err := r.db.NewSelect().
		Column("answers.id", "problem_id", "team_id", "scores.point", "answers.created_at").
		Table("answers").
		Join("LEFT JOIN scores").JoinOn("answers.id = scores.answer_id").
		Scan(ctx, &answers)
	if err != nil {
		return nil, err
	}
	return answers, nil
}
