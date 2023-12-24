package main

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"os/signal"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
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
		Use:  "netcon-score-server-exporter",
		RunE: cmd.RunE,
	}

	cmd.Flags().StringVar(&cmd.listenAddr, "listen-addr", ":3000", "Listen Address for metrics server")
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

	registry := prometheus.NewRegistry()

	metricsCollector := Collector{
		Repository:      repository,
		MetricsRegistry: registry,
	}

	metricsServer := Server{
		ListenAddr: c.listenAddr,
		Handler:    promhttp.HandlerFor(registry, promhttp.HandlerOpts{}),
	}

	go func() {
		if err := metricsCollector.Run(ctx); err != nil {
			slog.Error("failed to run metrics collector", "error", err)
			cancel(err)
			return
		}
		slog.Error("finished metrics collector successfully")
		cancel(nil)
	}()

	go func() {
		if err := metricsServer.Run(ctx); err != nil {
			slog.Error("failed to run metrics server", "error", err)
			cancel(err)
			return
		}
		slog.Error("finished metrics server successfully")
		cancel(nil)
	}()

	<-ctx.Done()

	if err := context.Cause(ctx); err != nil {
		if !errors.Is(err, context.Canceled) {
			return err
		}
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
