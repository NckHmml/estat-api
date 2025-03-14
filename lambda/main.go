package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"

	C "golambda/controllers"
	T "golambda/types"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
	_ "github.com/lib/pq"
)

// Global database connection
var db *sql.DB

// init function runs before main, perfect for connection setup
func init() {
	dbHost := os.Getenv("DB_HOST")
	dbName := os.Getenv("DB_NAME")
	secretARN := os.Getenv("DB_SECRET_ARN")

	// Load AWS configuration
	config, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		log.Fatalf("Unable to load SDK config: %v", err)
	}

	// Get the secret value
	svc := secretsmanager.NewFromConfig(config)
	secretsInput := &secretsmanager.GetSecretValueInput{
		SecretId: aws.String(secretARN),
	}
	result, err := svc.GetSecretValue(context.Background(), secretsInput)
	if err != nil {
		log.Fatalf("Error getting secret: %v", err)
	}

	var secret T.DBSecret
	err = json.Unmarshal([]byte(*result.SecretString), &secret)
	if err != nil {
		log.Fatalf("Error parsing secret: %v", err)
	}

	// Connect to the database
	connStr := fmt.Sprintf("host=%s user=%s password=%s dbname=%s",
		dbHost, secret.Username, secret.Password, dbName)

	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatalf("Error connecting to the database: %v", err)
	}

	err = db.Ping()
	if err != nil {
		log.Fatalf("Error pinging database: %v", err)
	}
}

func handler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	switch fmt.Sprintf("%s:%s", request.HTTPMethod, request.Path) {
	case "GET:/hello":
		response, err := C.Hello(db, request)
		return response, err

	case "GET:/labour-participation":
		response, err := C.LabourParticipation(db, request)
		return response, err

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
