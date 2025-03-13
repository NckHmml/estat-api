package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	_ "github.com/lib/pq"
)

type Response struct {
	Message string `json:"message"`
}

func handler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	dbHost := os.Getenv("DB_HOST")
	dbUser := os.Getenv("DB_USER")
	// ToDo: use secret values instead of env vars
	dbPass := os.Getenv("DB_PASSWORD")
	dbName := os.Getenv("DB_NAME")

	connStr := fmt.Sprintf("host=%s user=%s password=%s dbname=%s",
		dbHost, dbUser, dbPass, dbName)

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		log.Fatalf("Error connecting to the database: %v", err)
	}
	defer db.Close()

	switch request.Path {
	case "/hello":
		var result string
		err = db.QueryRow("SELECT 'Hello from PostgreSQL!'").Scan(&result)
		if err != nil {
			log.Fatalf("Query error: %v", err)
		}

		resp := Response{Message: result}
		jsonResp, _ := json.Marshal(resp)

		return events.APIGatewayProxyResponse{
			StatusCode: 200,
			Body:       string(jsonResp),
		}, nil
	default:
		return events.APIGatewayProxyResponse{
			StatusCode: 404,
			Body:       `{"message": "Not Found"}`,
		}, nil
	}
}

func main() {
	lambda.Start(handler)
}
