package main

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/prometheus/client_golang/prometheus"
)

const namespace = "netcon"

var (
	teamMetricsLabel = []string{"id", "name", "organization"}

	metricsCollectDurationSeconds = prometheus.NewGauge(prometheus.GaugeOpts{
		Namespace: namespace,
		Name:      "metrics_collect_duration_seconds",
	})
	teamsTotal = prometheus.NewGauge(prometheus.GaugeOpts{
		Namespace: namespace,
		Name:      "teams_total",
	})
	answersTotal = prometheus.NewGauge(prometheus.GaugeOpts{
		Namespace: namespace,
		Name:      "answers_total",
	})

	scores = prometheus.NewGaugeVec(prometheus.GaugeOpts{
		Namespace: namespace,
		Name:      "scores",
	}, teamMetricsLabel)
)

type Collector struct {
	Repository      *Repository
	MetricsRegistry *prometheus.Registry
}

func (c *Collector) Run(ctx context.Context) error {
	if err := c.register(); err != nil {
		return err
	}

	// Return immediately if error happens in the first collection
	if err := c.collect(ctx); err != nil {
		return fmt.Errorf("failed to collect metrics in the first collection: %w", err)
	}

	collectTicker := time.NewTicker(30 * time.Second)
	defer collectTicker.Stop()

	for {
		select {
		case <-collectTicker.C:
			if err := c.collect(ctx); err != nil {
				slog.Error("failed to collect metrics", "error", err)
			}
		case <-ctx.Done():
			return nil
		}
	}
}

func (c *Collector) register() error {
	collectors := []prometheus.Collector{
		metricsCollectDurationSeconds,
		teamsTotal,
		answersTotal,
		scores,
	}

	for _, collector := range collectors {
		if err := c.MetricsRegistry.Register(collector); err != nil {
			return err
		}
	}

	return nil
}

func (c *Collector) collect(ctx context.Context) error {
	slog.Info("starting to collect metrics")

	start := time.Now()
	defer func() {
		duration := time.Since(start).Seconds()
		slog.Info("metrics collected", "duration", duration)
		metricsCollectDurationSeconds.Set(duration)
	}()

	teams, err := c.Repository.FindTeams(ctx)
	if err != nil {
		return fmt.Errorf("failed to find teams: %w", err)
	}

	answers, err := c.Repository.FindAnswers(ctx)
	if err != nil {
		return fmt.Errorf("failed to find answers: %w", err)
	}

	teamsTotal.Set(float64(len(teams)))
	answersTotal.Set(float64(len(answers)))

	for _, team := range teams {
		score := c.calculateScore(answers, team.ID)
		scores.WithLabelValues(team.ID.String(), team.Name, team.Organization).Set(float64(score))
	}

	return nil
}

// calculateScores calculates scores from answers according to the algorithm implemented in ScoreAggregator.
// It only supports realtime_grading mode. The returned value is a score for the Team specified with teamID.
func (c *Collector) calculateScore(answers []Answer, teamID uuid.UUID) int {
	score := 0
	for _, answer := range c.findBestAnswers(answers, teamID) {
		score += *answer.Point
	}
	return score
}

// findBestAnswers finds the best answers for the team specified with teamID.
// The Points in the returned slice are guaranteed to be non-nil.
func (c *Collector) findBestAnswers(answers []Answer, teamID uuid.UUID) []Answer {
	// bestAnswersPerProblem is a map from ProblemID to best Answer
	bestAnswersPerProblem := map[uuid.UUID]Answer{}

	for _, answer := range answers {
		// Skip answers from other teams
		if answer.TeamID != teamID {
			continue
		}

		// Skip answers that are not graded yet
		if answer.Point == nil {
			continue
		}

		if bestAnswer, ok := bestAnswersPerProblem[answer.ProblemID]; ok {
			// In realtime_grading mode, the best answer is the one with the highest point.
			// Points in the both Answer should not be nil thanks to the previous check. We can check them safely.
			if *answer.Point > *bestAnswer.Point {
				bestAnswersPerProblem[answer.ProblemID] = answer
			}
		} else {
			bestAnswersPerProblem[answer.ProblemID] = answer
		}
	}

	// Convert bestAnswers map to a slice
	bestAnswers := []Answer{}
	for _, answer := range bestAnswersPerProblem {
		bestAnswers = append(bestAnswers, answer)
	}

	return bestAnswers
}

func (c *Collector) findTeamByID(teams []Team, team_id uuid.UUID) *Team {
	for _, team := range teams {
		if team.ID == team_id {
			return &team
		}
	}
	return nil
}
