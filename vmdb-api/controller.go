package main

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

const GREETING = "This is API for VM Management Service by NETCON Score Server"

type Controller struct {
	repo *Repository
}

func (c *Controller) hello(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte(GREETING))
}

type answerResponse struct {
	ID          uuid.UUID `json:"id"`
	ProblemID   uuid.UUID `json:"problem_id"`
	ProblemCode string    `json:"problem_code"`
	TeamID      uuid.UUID `json:"team_id"`
	Body        string    `json:"body"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

func newAnswerResponseFrom(answer Answer, problem Problem) answerResponse {
	bodies := []string{}
	for _, b := range answer.Bodies {
		bodies = append(bodies, b...)
	}

	return answerResponse{
		ID:          answer.ID,
		ProblemID:   answer.ProblemID,
		ProblemCode: problem.Code,
		TeamID:      answer.TeamID,
		CreatedAt:   answer.CreatedAt,
		UpdatedAt:   answer.UpdatedAt,
		Body:        strings.Join(bodies, "\n"),
	}
}

type listProblemEnvironmentsResponse []problemEnvironmentResponse

type problemEnvironmentResponse struct {
	// The following fields are derived from original ProblemEnvironment
	ID        uuid.UUID `bun:"id" json:"id"`
	Host      string    `bun:"host" json:"host"`
	ProblemID uuid.UUID `bun:"problem_id" json:"problem_id"`
	TeamID    uuid.UUID `bun:"team_id" json:"team_id"`
	Name      string    `bun:"name" json:"name"`
	CreatedAt time.Time `bun:"created_at" json:"created_at"`
	UpdatedAt time.Time `bun:"updated_at" json:"updated_at"`

	// This field is calculated from the latest Answer
	LatestAnswerBody string `json:"latest_answer_body"`
}

func newProblemEnvironmentResponseFrom(problemEnvironment ProblemEnvironment, latestAnswer Answer) problemEnvironmentResponse {
	bodies := []string{}
	for _, b := range latestAnswer.Bodies {
		bodies = append(bodies, b...)
	}

	return problemEnvironmentResponse{
		ID:               problemEnvironment.ID,
		Host:             problemEnvironment.Host,
		ProblemID:        problemEnvironment.ProblemID,
		TeamID:           problemEnvironment.TeamID,
		Name:             problemEnvironment.Name,
		CreatedAt:        problemEnvironment.CreatedAt,
		UpdatedAt:        problemEnvironment.UpdatedAt,
		LatestAnswerBody: strings.Join(bodies, "\n"),
	}
}

func (c *Controller) listProblemEnvironments(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	problemEnvironments, err := c.repo.listProblemEnvironments(ctx)
	if err != nil {
		slog.ErrorContext(ctx, "failed to list ProblemEnvironments", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	response := listProblemEnvironmentsResponse{}
	for _, pe := range problemEnvironments {
		latestAnswer, err := c.repo.findLatestAnswerFor(ctx, pe.ProblemID, pe.TeamID)
		if err != nil {
			slog.ErrorContext(ctx, "failed to find latest Answer", "error", err)
			w.WriteHeader(http.StatusInternalServerError)
			return
		}

		response = append(response, newProblemEnvironmentResponseFrom(pe, *latestAnswer))
	}

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
		problemEnvironment.ProblemID,
		problemEnvironment.TeamID,
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

type listUnconfirmedAnswersForLocalProblemResponse []answerResponse

func (c *Controller) listUnscoredAnswersForLocalProblem(w http.ResponseWriter, r *http.Request) {
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

	response := listUnconfirmedAnswersForLocalProblemResponse{}
	for _, code := range strings.Split(value, ",") {
		code = strings.TrimSpace(code)

		problem, err := c.repo.findProblemByCode(ctx, code)
		if err != nil {
			slog.WarnContext(ctx, "failed to find Problem", "error", err, "code", code)
			continue
		}

		answers, err := c.repo.listUnscoredAnswersFor(ctx, problem.ID)
		if err != nil {
			slog.ErrorContext(ctx, "failed to list latest unconfirmed Answers", "error", err)
			w.WriteHeader(http.StatusInternalServerError)
			return
		}

		for _, answer := range answers {
			response = append(response, newAnswerResponseFrom(answer, *problem))
		}
	}

	if err := renderJSON(w, http.StatusOK, response); err != nil {
		slog.ErrorContext(ctx, "failed to render JSON", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
	}
}

type getAnswerInformationResponse answerResponse

func (c *Controller) getAnswerInformation(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	answerIDStr := chi.URLParam(r, "answerID")
	answerID, err := uuid.Parse(answerIDStr)
	if err != nil {
		slog.WarnContext(ctx, "invalid query parameters", "answer_id", answerIDStr)
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	answer, err := c.repo.findAnswerBy(ctx, answerID)
	if err != nil {
		slog.WarnContext(ctx, "failed to find Answer", "error", err)
		w.WriteHeader(http.StatusNotFound)
		return
	}

	problem, err := c.repo.findProblemBy(ctx, answer.ProblemID)
	if err != nil {
		slog.ErrorContext(ctx, "failed to find Problem", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	response := getAnswerInformationResponse(newAnswerResponseFrom(*answer, *problem))

	if err := renderJSON(w, http.StatusOK, response); err != nil {
		slog.ErrorContext(ctx, "failed to render JSON", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
	}
}
