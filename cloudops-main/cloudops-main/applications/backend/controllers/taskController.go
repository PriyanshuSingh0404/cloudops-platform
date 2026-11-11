package controllers

import (
	"cloudops/backend/models"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
)

type ValidateTaskInput struct {
	Content string `json:"content" binding:"required"`
	Status  string `json:"status" binding:"required"`
}

type UpdateTaskInput struct {
	Content string `json:"content"`
	Status  string `json:"status"`
}

func FindTasks(c *gin.Context) {
	var tasks []models.Task
	models.DB.Find(&tasks)

	c.JSON(200, gin.H{
		"success": true,
		"message": "List Data Posts",
		"data":    tasks,
	})
}

func StoreTask(c *gin.Context) {
	var input ValidateTaskInput
	if err := c.ShouldBindJSON(&input); err != nil {
		var ve validator.ValidationErrors
		if errors.As(err, &ve) {
			out := make([]ErrorMsg, len(ve))
			for i, fe := range ve {
				out[i] = ErrorMsg{fe.Field(), GetErrorMsg(fe)}
			}
			c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"errors": out})
		}
		return
	}

	task := models.Task{
		Content: input.Content,
		Status:  input.Status,
	}
	models.DB.Create(&task)

	c.JSON(201, gin.H{
		"success": true,
		"message": "Task created successfully",
		"data":    task,
	})
}

func FindTaskById(c *gin.Context) {
	var task models.Task
	if err := models.DB.Where("id = ?", c.Param("id")).First(&task).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Record not found!"})
		return
	}

	c.JSON(200, gin.H{
		"success": true,
		"message": "Detail Data Post By ID : " + c.Param("id"),
		"data":    task,
	})
}

func UpdateTask(c *gin.Context) {
	var task models.Task
	if err := models.DB.Where("id = ?", c.Param("id")).First(&task).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Record not found"})
		return
	}

	var input UpdateTaskInput
	if err := c.ShouldBindJSON(&input); err != nil {
		var ve validator.ValidationErrors
		if errors.As(err, &ve) {
			out := make([]ErrorMsg, len(ve))
			for i, fe := range ve {
				out[i] = ErrorMsg{fe.Field(), GetErrorMsg(fe)}
			}
			c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"errors": out})
		}
		return
	}

	models.DB.Model(&task).Updates(input)

	c.JSON(200, gin.H{
		"success": true,
		"message": "Task Updated Successfully",
		"data":    task,
	})
}

func DeleteTask(c *gin.Context) {
	var task models.Task
	if err := models.DB.Where("id = ?", c.Param("id")).First(&task).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Record not found"})
		return
	}

	models.DB.Delete(&task)

	c.JSON(200, gin.H{
		"success": true,
		"message": "Task Deleted Successfully",
	})
}
