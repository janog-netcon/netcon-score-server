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

func (r *Repository) FindProblems(ctx context.Context) ([]Problem, error) {
	var problems []Problem
	err := r.db.NewSelect().
		Column("problems.id", "problems.code", "problem_bodies.title").
		Table("problems").
		Join("LEFT JOIN problem_bodies").JoinOn("problems.id = problem_bodies.problem_id").
		Scan(ctx, &problems)
	if err != nil {
		return nil, err
	}
	return problems, nil
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
