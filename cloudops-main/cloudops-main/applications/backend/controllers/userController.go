package controllers

import (
	"cloudops/backend/models"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
)

type ValidateUserInput struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

func FindUsers(c *gin.Context) {
	var users []models.User
	models.DB.Find(&users)

	c.JSON(200, gin.H{
		"success": true,
		"message": "List Data Users",
		"data":    users,
	})
}

func StoreUser(c *gin.Context) {
	var input ValidateUserInput
	var hashedPassword string
	var err error

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

	hashedPassword, err = models.HashPassword(input.Password)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to Process Password"})
		return
	}

	user := models.User{
		Username:     input.Username,
		PasswordHash: hashedPassword,
	}

	models.DB.Create(&user)

	c.JSON(201, gin.H{
		"success": true,
		"message": "User created successfully",
		"data":    user,
	})
}

func FindUserById(c *gin.Context) {
	var user models.User
	if err := models.DB.Where("id = ?", c.Param("id")).First(&user).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Record not found!"})
		return
	}

	c.JSON(200, gin.H{
		"success": true,
		"message": "Detail Data Post By ID : " + c.Param("id"),
		"data":    user,
	})
}

func UpdateUser(c *gin.Context) {
	var user models.User
	var hashedPassword string
	var err error

	if err := models.DB.Where("id = ?", c.Param("id")).First(&user).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Record not found"})
		return
	}

	var input ValidateUserInput
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

	hashedPassword, err = models.HashPassword(input.Password)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to Process Password"})
		return
	}

	user = models.User{
		Username:     input.Username,
		PasswordHash: hashedPassword,
	}

	models.DB.Model(&user).Updates(input)

	c.JSON(200, gin.H{
		"success": true,
		"message": "User Updated Successfully",
		"data":    user,
	})
}

func DeleteUser(c *gin.Context) {
	var user models.User
	if err := models.DB.Where("id = ?", c.Param("id")).First(&user).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Record not found"})
		return
	}

	models.DB.Delete(&user)

	c.JSON(200, gin.H{
		"success": true,
		"message": "User Deleted Successfully",
	})
}
