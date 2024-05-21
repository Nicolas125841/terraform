#!/bin/bash
go build -o bootstrap main.go
zip delete-lambda-handler.zip bootstrap
cp delete-lambda-handler.zip /mnt/c/Users/ristn/Desktop