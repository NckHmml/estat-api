package controllers

import (
	"database/sql"
	"encoding/json"
	"log"

	T "golambda/types"

	"github.com/aws/aws-lambda-go/events"
)

func LabourParticipation(db *sql.DB, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	rows, err := db.Query("SELECT age, age_string, area, area_string, labour_status, labour_status_string, total, person_one, person_two, person_three, person_four, person_five FROM labour_participation")
	if err != nil {
		log.Printf("Query error: %v", err)
		return events.APIGatewayProxyResponse{
			StatusCode: 500,
			Body:       `{"message": "Internal Server Error"}`,
		}, nil
	}
	defer rows.Close()

	var results []T.LabourParticipation
	for rows.Next() {
		var lp T.LabourParticipation
		err := rows.Scan(&lp.Age, &lp.AgeString, &lp.Area, &lp.AreaString, &lp.LabourStatus, &lp.LabourStatusString, &lp.Total, &lp.PersonOne, &lp.PersonTwo, &lp.PersonThree, &lp.PersonFour, &lp.PersonFive)
		if err != nil {
			log.Printf("Row scan error: %v", err)
			return events.APIGatewayProxyResponse{
				StatusCode: 500,
				Body:       `{"message": "Internal Server Error"}`,
			}, nil
		}
		results = append(results, lp)
	}

	jsonResp, err := json.Marshal(results)
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
