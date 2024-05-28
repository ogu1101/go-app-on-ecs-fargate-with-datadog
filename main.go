package main

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"gopkg.in/DataDog/dd-trace-go.v1/ddtrace/tracer"
	"gopkg.in/DataDog/dd-trace-go.v1/profiler"

	"database/sql"
	"fmt"
	"os"

	"github.com/go-sql-driver/mysql"
)

// album represents data about a record album.
type album struct {
	ID     string  `json:"id"`
	Title  string  `json:"title"`
	Artist string  `json:"artist"`
	Price  float64 `json:"price"`
}

var logger = slog.New(slog.NewJSONHandler(os.Stdout, nil))
var db *sql.DB

func main() {
	tracer.Start(
		tracer.WithEnv("prod"),
		tracer.WithService("test-go"),
		tracer.WithServiceVersion("abc123"),
	)

	err := profiler.Start(
		profiler.WithService("test-go"),
		profiler.WithEnv("prod"),
		profiler.WithVersion("abc123"),
		profiler.WithProfileTypes(
			profiler.CPUProfile,
			profiler.HeapProfile,
			// The profiles below are disabled by default to keep overhead
			// low, but can be enabled as needed.

			profiler.BlockProfile,
			profiler.MutexProfile,
			profiler.GoroutineProfile,
		),
	)
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}

	// Capture connection properties.
	cfg := mysql.Config{
		User:   os.Getenv("DBUSER"),
		Passwd: os.Getenv("DBPASS"),
		Net:    "tcp",
		Addr:   os.Getenv("DBADDR"),
		DBName: "recordings",
	}
	// Get a database handle.
	var openErr error
	db, openErr = sql.Open("mysql", cfg.FormatDSN())
	if openErr != nil {
		logger.Error(openErr.Error())
		os.Exit(1)
	}

	pingErr := db.Ping()
	if pingErr != nil {
		logger.Error(pingErr.Error())
		os.Exit(1)
	}
	logger.Info("Connected!")

	router := gin.Default()
	router.GET("/albums/:id", getAlbumByID)
	router.POST("/albums", postAlbums)

	router.Run()

	defer tracer.Stop()
	defer profiler.Stop()
}

// postAlbums adds the specified album to the database,
// returning the album ID of the new entry
func postAlbums(c *gin.Context) {
	logger.Info("postAlbums started!")

	var newAlbum album

	// Call BindJSON to bind the received JSON to
	// newAlbum.
	if err := c.BindJSON(&newAlbum); err != nil {
		logger.Error(fmt.Errorf("postAlbums: %v", err).Error())
		c.IndentedJSON(http.StatusBadRequest, "")
		return
	}

	result, err := db.Exec("INSERT INTO album (title, artist, price) VALUES (?, ?, ?)", newAlbum.Title, newAlbum.Artist, newAlbum.Price)
	if err != nil {
		logger.Error(fmt.Errorf("postAlbums: %v", err).Error())
		c.IndentedJSON(http.StatusInternalServerError, "")
		return
	}
	id, err := result.LastInsertId()
	if err != nil {
		logger.Error(fmt.Errorf("postAlbums: %v", err).Error())
		c.IndentedJSON(http.StatusInternalServerError, "")
		return
	}
	c.IndentedJSON(http.StatusCreated, gin.H{"id": id})
	logger.Info("Returned response!", "id", id)
	logger.Info("postAlbums was completed!")
}

// getAlbumByID queries for the album with the specified ID.
// parameter sent by the client, then returns that album as a response.
func getAlbumByID(c *gin.Context) {
	logger.Info("getAlbumByID started!")

	id := c.Param("id")

	// An album to hold data from the returned row.
	var alb album

	row := db.QueryRow("SELECT * FROM album WHERE id = ?", id)
	if err := row.Scan(&alb.ID, &alb.Title, &alb.Artist, &alb.Price); err != nil {
		if err == sql.ErrNoRows {
			c.IndentedJSON(http.StatusNotFound, "")
			return
		}
		logger.Error(fmt.Errorf("getAlbumByID %s: %v", id, err).Error())
		c.IndentedJSON(http.StatusInternalServerError, "")
		return
	}
	c.IndentedJSON(http.StatusOK, alb)
	logger.Info("Returned response!", "alb", alb)
	logger.Info("getAlbumByID was completed!")
}
