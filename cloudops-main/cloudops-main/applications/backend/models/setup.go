package models

import (
	"fmt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"os"
	"strconv"
)

var DB *gorm.DB

func GetDsn(host string, user string, password string, dbname string, port int) string {
	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%d sslmode=disable", host, user, password, dbname, port)
	return dsn
}

func ConnectDatabase() {

	host := os.Getenv("DB_HOST")
	if host == "" {
		host = "db"
	}

	pass := os.Getenv("POSTGRES_PASSWORD")
	user := os.Getenv("POSTGRES_USER")
	dbname := os.Getenv("POSTGRES_DB")

	portStr := os.Getenv("DB_PORT")
	port, err := strconv.Atoi(portStr)
	if err != nil {
		port = 5432
	}

	dsn := GetDsn(host, user, pass, dbname, port)
	fmt.Println("Connecting with DSN:", dsn)

	database, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		panic("failed to connect database")
	}

	database.AutoMigrate(&Task{}, &User{})
	DB = database
}
