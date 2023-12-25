package main

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/samber/lo"
)

const namespace = "netcon"

var (
	metricsCollectDurationSeconds = prometheus.NewGauge(prometheus.GaugeOpts{
		Namespace: namespace,
		Name:      "metrics_collect_duration_seconds",
	})

	// sum(teamsInfo) == teamsTotal
	teamsInfo = prometheus.NewGaugeVec(prometheus.GaugeOpts{
		Namespace: namespace,
		Name:      "teams_info",
	}, []string{
		"team_id", "team_name", "team_organization",
	})

	// sum(problemsInfo) == problemsTotal
	problemsInfo = prometheus.NewGaugeVec(prometheus.GaugeOpts{
		Namespace: namespace,
		Name:      "problems_info",
	}, []string{
		"problem_id", "problem_code", "problem_title",
	})

	teamsTotal = prometheus.NewGauge(prometheus.GaugeOpts{
		Namespace: namespace,
		Name:      "teams_total",
	})

	problemsTotal = prometheus.NewGauge(prometheus.GaugeOpts{
		Namespace: namespace,
		Name:      "problems_total",
	})

	answersTotal = prometheus.NewGaugeVec(prometheus.GaugeOpts{
		Namespace: namespace,
		Name:      "answers_total",
	}, []string{
		"team_id", "problem_id",
	})

	scores = prometheus.NewGaugeVec(prometheus.GaugeOpts{
		Namespace: namespace,
		Name:      "scores",
	}, []string{
		"team_id", "problem_id",
	})
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
		teamsInfo,
		problemsInfo,
		teamsTotal,
		problemsTotal,
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

	problems, err := c.Repository.FindProblems(ctx)
	if err != nil {
		return fmt.Errorf("failed to find problems: %w", err)
	}

	allAnswers, err := c.Repository.FindAnswers(ctx)
	if err != nil {
		return fmt.Errorf("failed to find answers: %w", err)
	}

	// DB might be reset during the collection. So, call Reset() before setting metrics.
	teamsInfo.Reset()
	for _, team := range teams {
		teamsInfo.WithLabelValues(team.ID.String(), team.Name, team.Organization).Set(1)
	}

	// DB might be reset during the collection. So, call Reset() before setting metrics.
	problemsInfo.Reset()
	for _, problem := range problems {
		problemsInfo.WithLabelValues(problem.ID.String(), problem.Code, problem.Title).Set(1)
	}

	teamsTotal.Set(float64(len(teams)))
	problemsTotal.Set(float64(len(problems)))

	// DB might be reset during the collection. So, call Reset() before setting metrics.
	answersTotal.Reset()
	scores.Reset()
	for _, team := range teams {
		for _, problem := range problems {
			teamAnswers := lo.Filter(allAnswers, func(answer Answer, _ int) bool {
				return answer.TeamID == team.ID && answer.ProblemID == problem.ID
			})
			bestAnswer := c.findBestAnswerFor(teamAnswers)
			score := 0
			if bestAnswer != nil {
				score = *bestAnswer.Point
			}
			answersTotal.WithLabelValues(team.ID.String(), problem.ID.String()).Set(float64(len(teamAnswers)))
			scores.WithLabelValues(team.ID.String(), problem.ID.String()).Set(float64(score))
		}
	}

	return nil
}

// findBestAnswers finds the best answers. The Points in the returned slice are guaranteed to be non-nil.
func (c *Collector) findBestAnswerFor(answers []Answer) *Answer {
	var bestAnswer Answer
	for _, answer := range answers {
		// Skip answers that are not graded yet
		if answer.Point == nil {
			continue
		}

		// In realtime_grading mode, the best answer is the one with the highest point.
		// Points in the both Answer should not be nil thanks to the previous check. We can check them safely.
		if bestAnswer.ID == uuid.Nil || *answer.Point > *bestAnswer.Point {
			bestAnswer = answer
		}
	}

	if bestAnswer.ID == uuid.Nil {
		return nil
	}
	return &bestAnswer
}
