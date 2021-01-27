package main

import (
  "database/sql"
  "encoding/json"
  "reflect"
  "testing"
)

func TestMarshalJSONInvalid(t *testing.T) {
    ex := MySQLNullString{sql.NullString{Valid: false, String: ""}}

    b, err := json.Marshal(ex)

    if err != nil {
      t.Fatal(err)
    }

    if !reflect.DeepEqual(b, []byte{'n', 'u', 'l', 'l'}) {
      t.Fatal()
    }
}

func TestMarshalJSONValid(t *testing.T) {
    ex := MySQLNullString{sql.NullString{Valid: true, String: "yeah"}}

    b, err := json.Marshal(ex)

    if err != nil {
      t.Fatal(err)
    }

    if !reflect.DeepEqual(b, []byte{'"', 'y', 'e', 'a', 'h', '"'}) {
      t.Fatal()
    }
}

func TestUnMarshalJSONInvalid(t *testing.T) {
    expected := MySQLNullString{sql.NullString{Valid: false, String: ""}}

    input := []byte{'n', 'u', 'l', 'l'}

    var mns MySQLNullString
    err := json.Unmarshal(input, &mns)

    if err != nil {
      t.Fatal(err)
    }

    if !reflect.DeepEqual(mns, expected) {
      t.Fatal()
    }
}

func TestUnMarshalJSONValid(t *testing.T) {
    expected := MySQLNullString{sql.NullString{Valid: true, String: "yeah"}}

    input := []byte{'"', 'y', 'e', 'a', 'h', '"'}

    var mns MySQLNullString
    err := json.Unmarshal(input, &mns)

    if err != nil {
      t.Fatal(err)
    }

    if !reflect.DeepEqual(mns, expected) {
      t.Fatal()
    }
}

