package main

import (
	"context"
	"encoding/json"
	"log"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/expression"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
)

type Player struct {
	Name string `dynamodbav:"Name" json:"name"`
}

type PlayerLoadContent struct {
	Players []Player `json:"players"`
}

var dbClient *dynamodb.Client

func listPlayers() {
	all, err := expression.NewBuilder().WithFilter(expression.AttributeExists(expression.Name("Name"))).Build()
	if err != nil {
		log.Fatal(err)
	}
	output, err := dbClient.Scan(context.TODO(), &dynamodb.ScanInput{
		TableName:                 aws.String("Players"),
		FilterExpression:          all.Filter(),
		ExpressionAttributeNames:  all.Names(),
		ExpressionAttributeValues: all.Values(),
	})
	if err != nil {
		log.Fatal(err)
	}
	var players []Player
	err = attributevalue.UnmarshalListOfMaps(output.Items, &players)
	if err != nil {
		log.Fatal(err)
	}
	log.Println("players:")
	for _, player := range players {
		log.Printf("%v\n", player)
	}
}

func deletePlayer(ctx context.Context, player *Player) {
	key, err := attributevalue.MarshalMap(player)
	if err != nil {
		log.Fatal(err)
	}
	_, err = dbClient.DeleteItem(ctx, &dynamodb.DeleteItemInput{
		Key: key, TableName: aws.String("Players"),
	})
	if err != nil {
		log.Fatalf("Couldn't delete %v from the table. Here's why: %v\n", player.Name, err)
	}
}

func init() {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatal(err)
	}

	dbClient = dynamodb.NewFromConfig(cfg)

	log.Println("Function is ready!")
}

func HandleRequest(ctx context.Context, apiEvent *events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	if apiEvent == nil {
		log.Fatal("received nil event")
	}
	player := &Player{}
	err := json.Unmarshal([]byte(apiEvent.Body), &player)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("Deleting player: %v\n", player)
	deletePlayer(ctx, player)

	return events.APIGatewayProxyResponse{StatusCode: 200, Body: "OK"}, nil
}

func main() {
	lambda.Start(HandleRequest)
}
