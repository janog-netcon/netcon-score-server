package main

import (
  "database/sql"
  "encoding/json"
  "fmt"
  "net/http"
  "os"
  "time"

  "github.com/google/uuid"
  "github.com/jmoiron/sqlx"
  "github.com/labstack/echo/v4"
  "github.com/labstack/echo/v4/middleware"
  "github.com/labstack/gommon/log"
  _ "github.com/lib/pq"
)

var db *sqlx.DB

type MySQLNullString struct {
  sql.NullString
}

func (msn MySQLNullString) MarshalJSON() ([]byte, error) {
  if msn.Valid {
    return json.Marshal(msn.String)
  } else {
    return json.Marshal(nil)
  }
}

func (msn *MySQLNullString) UnmarshalJSON(data []byte) error {
  str := string(data)
  if str == "" || str == "null" {
    msn.Valid = false
  } else {
    msn.Valid = true
    msn.String = str[1:len(str)-1]
  }

  return nil
}

type ProblemEnvironment struct {
  // create_table "problem_environments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    ID               uuid.UUID       `db:"id" json:"id"`
    Status           string          `db:"status" json:"status"`
    Host             string          `db:"host" json:"host"`
    User             string          `db:"user" json:"user"`
    Password         string          `db:"password" json:"password"`
    ProblemID        uuid.UUID       `db:"problem_id" json:"problem_id"`
    // TeamID           uuid.UUID       `db:"team_id" json:"team_id"` // nullable
    CreatedAt        time.Time       `db:"created_at" json:"created_at"`
    UpdatedAt        time.Time       `db:"updated_at" json:"updated_at"`
    // SecretText       string          `db:"secret_text" json:"secret_text"`
    Name             string          `db:"name" json:"name"`
    Service          string          `db:"service" json:"service"`
    Port             int             `db:"port" json:"port"`
    MachineImageName MySQLNullString `db:"machine_image_name" json:"machine_image_name"` // nullable
}

func main() {
  // Echo instance
  e := echo.New()

  // Middleware
  e.Use(middleware.Logger())
  e.Use(middleware.Recover())

  // Routes
  e.GET("/", hello)
  e.GET("/problem-environments", ListProblemEnvironment)
  e.GET("/problem-environments/:name", GetProblemEnvironment)
  e.POST("/problem-environments", CreateOrUpdateProblemEnvironment)
  e.DELETE("/problem-environments/:name", DeleteProblemEnvironment)

  // export POSTGRES_HOST=localhost POSTGRES_PORT=8902 POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres POSTGRES_DATABASE=development

  db_host := os.Getenv("POSTGRES_HOST")
  db_port := os.Getenv("POSTGRES_PORT")
  db_user := os.Getenv("POSTGRES_USER")
  db_password := os.Getenv("POSTGRES_PASSWORD")
  db_database := os.Getenv("POSTGRES_DATABASE")

  dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable", db_host, db_port, db_user, db_password, db_database)

  var err error
  db, err = sqlx.Open("postgres", dsn)

  if err != nil {
    e.Logger.Fatal(err)
  }

  defer db.Close()

  e.Logger.SetLevel(log.DEBUG)

  // Start server
  e.Logger.Fatal(e.Start(":8080"))

  // query(e.Logger)
}

// Handler
func hello(c echo.Context) error {
  return c.String(http.StatusOK, "This is api for VM Management Service by NETCON Score Server")
}

func QueryProblemEnvironment(c echo.Context, name string) error {
  var rows *sqlx.Rows
  var err error

  if name == "" {
    q := `SELECT id, status, host, "user", password, problem_id, created_at, updated_at, name, service, port, machine_image_name FROM problem_environments`
    rows, err = db.Queryx(q)
  } else {
    q := `SELECT id, status, host, "user", password, problem_id, created_at, updated_at, name, service, port, machine_image_name FROM problem_environments WHERE name = $1`
    rows, err = db.Queryx(q, name)
  }

  if err != nil {
    c.Echo().Logger.Errorf("Failed to run query", err)
    return c.String(http.StatusInternalServerError, "Failed to execute query")
  }

  pes := []ProblemEnvironment{}

  for rows.Next() {
    var pe ProblemEnvironment
    err = rows.StructScan(&pe)

    if err != nil {
      c.Echo().Logger.Errorf("Failed to StructScan", err)
      return c.String(http.StatusInternalServerError, "Failed to parse query result")
    }

    pes = append(pes, pe)
  }

  // var encoded []byte
  // encoded, err = json.Marshal(pes)

  // if err != nil {
  //   c.Echo().Logger.Errorf("Failed to marshal json", err)
  // }

  // fmt.Println(string(encoded))
  return c.JSON(http.StatusOK, pes)
}

func ListProblemEnvironment(c echo.Context) error {
  return QueryProblemEnvironment(c, "")
}

func GetProblemEnvironment(c echo.Context) error {
  name := c.Param("name")

  return QueryProblemEnvironment(c, name)
}

func CreateOrUpdateProblemEnvironment(c echo.Context) error {
  pe := ProblemEnvironment{}

  // TODO: validation
  err := c.Bind(&pe)

  if err != nil {
    c.Echo().Logger.Errorf("Failed to bind payload", err)
    return c.String(http.StatusInternalServerError, "Failed to parse query result")
  }

  q := `
    INSERT INTO problem_environments (status, host, "user", password, problem_id, name, service, port, machine_image_name, secret_text, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'generated by vmms', NOW(), NOW())
    ON CONFLICT (problem_id, name, service)
    DO UPDATE SET status=?, host=?, "user"=?, password=?, problem_id=?, name=?, service=?, port=?, machine_image_name=?, updated_at=NOW()
  `

  _, err = db.Exec(db.Rebind(q),
    pe.Status, pe.Host, pe.User, pe.Password, pe.ProblemID, pe.Name, pe.Service, pe.Port, pe.MachineImageName,
    pe.Status, pe.Host, pe.User, pe.Password, pe.ProblemID, pe.Name, pe.Service, pe.Port, pe.MachineImageName)
  if err != nil {
    c.Echo().Logger.Errorf("Failed to run query", err)
    return c.String(http.StatusInternalServerError, "Failed to execute query")
  }

  pe_from_db := ProblemEnvironment{}
  q = `SELECT id, status, host, "user", password, problem_id, created_at, updated_at, name, service, port, machine_image_name FROM problem_environments WHERE problem_id = ? AND name = ? AND service = ? LIMIT 1`
  err = db.Get(&pe_from_db, db.Rebind(q), pe.ProblemID, pe.Name, pe.Service)

  if err != nil {
    c.Echo().Logger.Errorf("Failed to get query result", err)
    return c.String(http.StatusInternalServerError, "Failed to execute query result")
  }

  return c.JSON(http.StatusOK, pe_from_db)
}

func DeleteProblemEnvironment(c echo.Context) error {
  name := c.Param("name")

  q := `DELETE FROM problem_environments WHERE name = $1`
  res, err := db.Exec(q, name)
  if err != nil {
    c.Echo().Logger.Errorf("Failed to run query", err)
    return c.String(http.StatusInternalServerError, "Failed to execute query")
  }

  rowCnt, err := res.RowsAffected()
  if err != nil {
    c.Echo().Logger.Errorf("Failed to run query", err)
    return c.String(http.StatusInternalServerError, "Failed to execute query")
  }

  if rowCnt == 0 {
    return c.NoContent(http.StatusGone)
  }

  return c.NoContent(http.StatusNoContent)
}
