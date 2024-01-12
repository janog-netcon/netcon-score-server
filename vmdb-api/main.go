package main

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	"os"
	"os/signal"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/spf13/cobra"
	"github.com/uptrace/bun"
	"github.com/uptrace/bun/dialect/pgdialect"
	"github.com/uptrace/bun/driver/pgdriver"
)

type Command struct {
	cobra.Command

	listenAddr             string
	postgresHost           string
	postgresUser           string
	postgresPassword       string
	postgresDatabase       string
	postgresDisableSSLMode bool
}

func (c *Command) ExecuteContext(ctx context.Context) error {
	return c.Command.ExecuteContext(ctx)
}

func NewCommand() Command {
	cmd := Command{}

	cmd.Command = cobra.Command{
		Use:  "netcon-score-server-vmdb-api",
		RunE: cmd.RunE,
	}

	cmd.Flags().StringVar(&cmd.listenAddr, "listen-addr", ":8080", "Listen Address for metrics server")
	cmd.Flags().StringVar(&cmd.postgresHost, "postgres-host", "localhost:5432", "PostgreSQL host")
	cmd.Flags().StringVar(&cmd.postgresUser, "postgres-user", "postgres", "PostgreSQL user")
	cmd.Flags().StringVar(&cmd.postgresPassword, "postgres-password", "postgres", "PostgreSQL password")
	cmd.Flags().StringVar(&cmd.postgresDatabase, "postgres-database", "development", "PostgreSQL password")
	cmd.Flags().BoolVar(&cmd.postgresDisableSSLMode, "postgres-disable-ssl-mode", false, "Disable SSL to PostgreSQL")

	return cmd
}

func (c *Command) buildDSN() string {
	dsn := fmt.Sprintf("postgres://%s:%s@%s/%s", c.postgresUser, c.postgresPassword, c.postgresHost, c.postgresDatabase)
	if c.postgresDisableSSLMode {
		dsn += "?sslmode=disable"
	}
	return dsn
}

func (c *Command) RunE(cmd *cobra.Command, _ []string) error {
	ctx, cancel := context.WithCancelCause(cmd.Context())
	defer cancel(nil)

	dsn := c.buildDSN()
	sqldb := sql.OpenDB(pgdriver.NewConnector(pgdriver.WithDSN(dsn)))
	db := bun.NewDB(sqldb, pgdialect.New())
	repository := NewRepository(db)

	controller := Controller{repo: repository}

	r := chi.NewRouter()

	r.Use(middleware.Logger)
	r.Use(middleware.RealIP)
	r.Use(middleware.Heartbeat("/healthz"))
	r.Use(middleware.Recoverer)

	// 後方互換性のために、そのままのI/Fで提供する
	r.Get("/", controller.hello)
	r.Get("/problem-environments", controller.listProblemEnvironments)
	r.Get("/answer-id", controller.getAnswerID)

	r.Get("/local-problem-answers", controller.listUnscoredAnswersForLocalProblem)
	r.Get("/answers/{answerID}", controller.getAnswerInformation)

	server := Server{
		ListenAddr: c.listenAddr,
		Handler:    r,
	}

	if err := server.Run(ctx); err != nil {
		slog.Error("failed to run VMDB API server", "error", err)
		return err
	}

	return nil
}

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	cmd := NewCommand()
	if err := cmd.ExecuteContext(ctx); err != nil {
		slog.Error("failed to execute command", "error", err)
		os.Exit(1)
	}
}
