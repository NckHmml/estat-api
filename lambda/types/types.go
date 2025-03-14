package types

import "database/sql"

type Response struct {
	Message string `json:"message"`
}

type DBSecret struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type LabourParticipation struct {
	Age                string        `json:"age"`
	AgeString          string        `json:"age_string"`
	Area               string        `json:"area"`
	AreaString         string        `json:"area_string"`
	LabourStatus       string        `json:"labour_status"`
	LabourStatusString string        `json:"labour_status_string"`
	Total              sql.NullInt32 `json:"total"`
	PersonOne          sql.NullInt32 `json:"person_one"`
	PersonTwo          sql.NullInt32 `json:"person_two"`
	PersonThree        sql.NullInt32 `json:"person_three"`
	PersonFour         sql.NullInt32 `json:"person_four"`
	PersonFive         sql.NullInt32 `json:"person_five"`
}
