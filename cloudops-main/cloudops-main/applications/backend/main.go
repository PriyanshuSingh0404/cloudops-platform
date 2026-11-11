package main

import (
	"cloudops/backend/controllers"
	"cloudops/backend/models"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func main() {
	router := gin.Default()

	router.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
	}))

	models.ConnectDatabase()

	router.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "Hello World v2",
		})
	})

	router.GET("/tasks", controllers.FindTasks)
	router.POST("/tasks", controllers.StoreTask)
	router.GET("/tasks/:id", controllers.FindTaskById)
	router.PUT("/tasks/:id", controllers.UpdateTask)
	router.DELETE("/tasks/:id", controllers.DeleteTask)

	router.GET("/users", controllers.FindUsers)
	router.POST("/users", controllers.StoreUser)
	router.GET("/users/:id", controllers.FindUserById)
	router.PUT("/users/:id", controllers.UpdateUser)
	router.DELETE("/users/:id", controllers.DeleteUser)

	router.Run(":5000")
}
