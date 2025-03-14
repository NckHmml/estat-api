package controllers

import (
	"database/sql"
	"encoding/json"
	"log"

	T "golambda/types"

	"github.com/aws/aws-lambda-go/events"
)

func Hello(db *sql.DB, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	var result string
	err := db.QueryRow("SELECT 'Hello from PostgreSQL!'").Scan(&result)
	if err != nil {
		log.Printf("Query error: %v", err)
		return events.APIGatewayProxyResponse{
			StatusCode: 500,
			Body:       `{"message": "Internal Server Error"}`,
		}, nil
	}

	resp := T.Response{Message: result}
	jsonResp, err := json.Marshal(resp)
	if err != nil {
		log.Printf("JSON marshal error: %v", err)
		return events.APIGatewayProxyResponse{
			StatusCode: 500,
			Body:       `{"message": "Internal Server Error"}`,
		}, nil
	}

	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Body:       string(jsonResp),
	}, nil
}
