package main

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	sqltrace "gopkg.in/DataDog/dd-trace-go.v1/contrib/database/sql"
	gintrace "gopkg.in/DataDog/dd-trace-go.v1/contrib/gin-gonic/gin"
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
	env := os.Getenv("DD_ENV")
	service := os.Getenv("DD_SERVICE")
	version := os.Getenv("DD_VERSION")

	tracer.Start(
		tracer.WithEnv(env),
		tracer.WithService(service),
		tracer.WithServiceVersion(version),
	)
	defer tracer.Stop()

	err := profiler.Start(
		profiler.WithService(service),
		profiler.WithEnv(env),
		profiler.WithVersion(version),
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
	defer profiler.Stop()

	connectToDatabase(service)
	createAlbumTable()

	router := initializeRouter(service)
	router.Run()
}

func connectToDatabase(service string) {
	// Capture connection properties.
	cfg := mysql.Config{
		User:                 os.Getenv("DBUSER"),
		Passwd:               os.Getenv("DBPASS"),
		Net:                  "tcp",
		Addr:                 os.Getenv("DBADDR"),
		DBName:               "recordings",
		AllowNativePasswords: true,
	}
	// Register the driver that we will be using (in this case mysql) under a custom service name.
	sqltrace.Register("mysql", &mysql.MySQLDriver{}, sqltrace.WithServiceName(service))
	// Get a database handle.
	var err error
	db, err = sqltrace.Open("mysql", cfg.FormatDSN())
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}

	pingErr := db.Ping()
	if pingErr != nil {
		logger.Error(pingErr.Error())
		os.Exit(1)
	}
	logger.Info("Connected!")
}

func createAlbumTable() {
	createTableSQL := `CREATE TABLE IF NOT EXISTS album (
		id         INT AUTO_INCREMENT NOT NULL,
		title      VARCHAR(128) NOT NULL,
		artist     VARCHAR(255) NOT NULL,
		price      DECIMAL(5,2) NOT NULL,
		PRIMARY KEY (id)
	);`

	_, err := db.Exec(createTableSQL)
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}
}

func initializeRouter(service string) *gin.Engine {
	router := gin.Default()
	router.Use(gintrace.Middleware(service))
	router.GET("/", healthCheck)
	router.GET("/albums/:id", getAlbumByID)
	router.POST("/albums", postAlbums)
	return router
}

func healthCheck(c *gin.Context) {
	c.IndentedJSON(http.StatusOK, "")
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
