package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"ai-chat-backend/internal/config"
	"ai-chat-backend/internal/persistence"
)

func main() {
	cfg := config.Load()
	ctx := context.Background()

	db, err := persistence.NewDB(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	files, err := os.ReadDir("migrations")
	if err != nil {
		log.Fatalf("Failed to read migrations directory: %v", err)
	}

	var upFiles []string
	for _, f := range files {
		if !f.IsDir() && strings.HasSuffix(f.Name(), ".up.sql") {
			upFiles = append(upFiles, f.Name())
		}
	}
	sort.Strings(upFiles)

	for _, name := range upFiles {
		path := filepath.Join("migrations", name)
		sqlBytes, err := os.ReadFile(path)
		if err != nil {
			log.Fatalf("Failed to read %s: %v", path, err)
		}

		if _, err := db.Pool.Exec(ctx, string(sqlBytes)); err != nil {
			log.Printf("[WARN] Migration %s: %v", name, err)
		} else {
			fmt.Printf("Migration %s applied successfully!\n", name)
		}
	}
}
