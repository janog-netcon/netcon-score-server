package main

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
)

const GREETING = "This is API for VM Management Service by NETCON Score Server"

type Controller struct {
	repo *Repository
}

func (c *Controller) hello(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte(GREETING))
}

type listProblemEnvironmentsResponse []ProblemEnvironment

func (c *Controller) listProblemEnvironments(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	problemEnvironments, err := c.repo.listProblemEnvironments(ctx)
	if err != nil {
		slog.ErrorContext(ctx, "failed to list ProblemEnvironments", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	response := listProblemEnvironmentsResponse(problemEnvironments)

	if err := renderJSON(w, http.StatusOK, response); err != nil {
		slog.ErrorContext(ctx, "failed to render JSON", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
}

type getAnswerIDResponse struct {
	ID string `json:"id"`
}

func (c *Controller) getAnswerID(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	name := r.URL.Query().Get("name")

	if name == "" {
		slog.WarnContext(ctx, "invalid query parameters", "name", name)
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	problemEnvironment, err := c.repo.findProblemEnvironmentBy(ctx, name)
	if err != nil {
		slog.WarnContext(ctx, "failed to find ProblemEnvironment", "error", err)
		w.WriteHeader(http.StatusNotFound)
		return
	}

	latestAnswer, err := c.repo.findLatestAnswerFor(
		ctx,
		problemEnvironment.ProblemID.String(),
		problemEnvironment.TeamID.String(),
	)
	if err != nil {
		slog.ErrorContext(ctx, "failed to find latest Answer", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	if latestAnswer == nil {
		slog.InfoContext(ctx, "no answer found")
		w.WriteHeader(http.StatusNotFound)
		return
	}

	response := getAnswerIDResponse{
		ID: latestAnswer.ID.String(),
	}

	if err := renderJSON(w, http.StatusOK, response); err != nil {
		slog.ErrorContext(ctx, "failed to render JSON", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
	}
}

type listLatestUnconfirmedAnswersForLocalProblemResponse []listLatestUnconfirmedAnswersForLocalProblemResponseItem

type listLatestUnconfirmedAnswersForLocalProblemResponseItem struct {
	ID          uuid.UUID `json:"id"`
	ProblemID   uuid.UUID `json:"problem_id"`
	ProblemCode string    `json:"problem_code"`
	TeamID      uuid.UUID `json:"team_id"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
	Body        string    `json:"body"`
}

func (c *Controller) listLatestUnconfirmedAnswersForLocalProblem(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	config, err := c.repo.findConfigBy(ctx, "local_problem_codes")
	if err != nil {
		slog.ErrorContext(ctx, "failed to find Config", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	var value string
	if err := json.Unmarshal([]byte(config.Vaule), &value); err != nil {
		slog.ErrorContext(ctx, "failed to unmarshal JSON", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	response := listLatestUnconfirmedAnswersForLocalProblemResponse{}
	for _, code := range strings.Split(value, ",") {
		code = strings.TrimSpace(code)

		problem, err := c.repo.findProblemBy(ctx, code)
		if err != nil {
			slog.WarnContext(ctx, "failed to find Problem", "error", err, "code", code)
			continue
		}

		answers, err := c.repo.listLatestUnscoredAnswersFor(ctx, problem.ID)
		if err != nil {
			slog.ErrorContext(ctx, "failed to list latest unconfirmed Answers", "error", err)
			w.WriteHeader(http.StatusInternalServerError)
			return
		}

		latestAnswers := map[uuid.UUID]Answer{}
		for _, answer := range answers {
			if _, ok := latestAnswers[answer.TeamID]; !ok {
				latestAnswers[answer.TeamID] = answer
			}
			if answer.CreatedAt.After(latestAnswers[answer.TeamID].CreatedAt) {
				latestAnswers[answer.TeamID] = answer
			}
		}

		for _, answer := range latestAnswers {
			bodies := []string{}
			for _, b := range answer.Bodies {
				bodies = append(bodies, b...)
			}

			response = append(response, listLatestUnconfirmedAnswersForLocalProblemResponseItem{
				ID:          answer.ID,
				ProblemID:   answer.ProblemID,
				ProblemCode: problem.Code,
				TeamID:      answer.TeamID,
				CreatedAt:   answer.CreatedAt,
				UpdatedAt:   answer.UpdatedAt,
				Body:        strings.Join(bodies, "\n"),
			})
		}
	}

	if err := renderJSON(w, http.StatusOK, response); err != nil {
		slog.ErrorContext(ctx, "failed to render JSON", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
	}
}
