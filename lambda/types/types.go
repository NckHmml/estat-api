package types

type Response struct {
	Message string `json:"message"`
}

type DBSecret struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type LabourParticipation struct {
	Age                string `json:"age"`
	AgeString          string `json:"age_string"`
	Area               string `json:"area"`
	AreaString         string `json:"area_string"`
	LabourStatus       string `json:"labour_status"`
	LabourStatusString string `json:"labour_status_string"`
	Total              int    `json:"total"`
	PersonOne          int    `json:"person_one"`
	PersonTwo          int    `json:"person_two"`
	PersonThree        int    `json:"person_three"`
	PersonFour         int    `json:"person_four"`
	PersonFive         int    `json:"person_five"`
}
