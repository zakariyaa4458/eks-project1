package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "github.com/lib/pq"
)

var db *sql.DB

func main() {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL is required")
	}

	var err error
	db, err = sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(3)
	db.SetConnMaxLifetime(5 * time.Minute)
	waitForDB()
	migrate()

	mux := http.NewServeMux()
	mux.HandleFunc("/livez", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) })
	mux.HandleFunc("/healthz", handleHealth)
	mux.HandleFunc("/send", handleSend)
	mux.HandleFunc("/history", handleHistory)
	mux.HandleFunc("/templates", handleTemplates)

	port := getEnv("PORT", "8084")
	server := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	go func() {
		log.Printf("Notification service listening on :%s", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server error: %v", err)
		}
	}()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	log.Println("Shutting down...")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("graceful shutdown error: %v", err)
	}
}

func migrate() {
	migrations := []string{
		`CREATE TABLE IF NOT EXISTS notifications (
		id SERIAL PRIMARY KEY,
		order_id INTEGER,
		recipient VARCHAR(255) NOT NULL,
		channel VARCHAR(20) NOT NULL,
		template VARCHAR(100) NOT NULL,
		subject TEXT,
		body TEXT NOT NULL,
		metadata JSONB,
		status VARCHAR(20) NOT NULL DEFAULT 'pending',
		sent_at TIMESTAMP,
		created_at TIMESTAMP DEFAULT NOW()
	)`,

		`ALTER TABLE notifications
	 ADD COLUMN IF NOT EXISTS order_id INTEGER`,

		`CREATE INDEX IF NOT EXISTS idx_notifications_recipient
	 ON notifications(recipient)`,

		`CREATE INDEX IF NOT EXISTS idx_notifications_status
	 ON notifications(status)`,

		`CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_sent_order_notification
	 ON notifications(order_id, template)
	 WHERE status = 'sent' AND order_id IS NOT NULL`,

		`CREATE TABLE IF NOT EXISTS notification_templates (
		id VARCHAR(100) PRIMARY KEY,
		channel VARCHAR(20) NOT NULL,
		subject TEXT,
		body TEXT NOT NULL,
		created_at TIMESTAMP DEFAULT NOW(),
		updated_at TIMESTAMP DEFAULT NOW()
	)`,
	}
	for _, m := range migrations {
		if _, err := db.Exec(m); err != nil {
			log.Fatalf("Migration failed: %v", err)
		}
	}

	// Seed default templates
	templates := []struct {
		id, channel, subject, body string
	}{
		{"order_confirmed", "email", "Order Confirmed - #{{.OrderID}}", "Hi {{.CustomerName}}, your order #{{.OrderID}} has been confirmed. Total: {{.Currency}} {{.Total}}"},
		{"order_shipped", "email", "Your Order Has Shipped - #{{.OrderID}}", "Good news! Your order #{{.OrderID}} has been shipped. Tracking: {{.TrackingNumber}}"},
		{"order_delivered", "email", "Order Delivered - #{{.OrderID}}", "Your order #{{.OrderID}} has been delivered. Thank you for your purchase!"},
		{"payment_failed", "email", "Payment Failed - Order #{{.OrderID}}", "We were unable to process your payment for order #{{.OrderID}}. Please update your payment method."},
		{"low_stock_alert", "email", "Low Stock Alert - {{.ProductName}}", "Product {{.ProductName}} ({{.SKU}}) is running low. Available: {{.Available}}"},
		{"order_confirmed_sms", "sms", "", "Order #{{.OrderID}} confirmed. Total: {{.Currency}} {{.Total}}"},
		{"order_shipped_sms", "sms", "", "Order #{{.OrderID}} shipped. Track: {{.TrackingNumber}}"},
	}

	for _, t := range templates {
		db.Exec(
			`INSERT INTO notification_templates (id, channel, subject, body)
			 VALUES ($1, $2, $3, $4) ON CONFLICT (id) DO NOTHING`,
			t.id, t.channel, t.subject, t.body,
		)
	}

	log.Println("Notification service migrations complete")
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	status := "ok"
	if err := db.Ping(); err != nil {
		status = "unhealthy"
		w.WriteHeader(http.StatusServiceUnavailable)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": status, "service": "notification-service"})
}

func handleSend(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		httpError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		OrderID   int                    `json:"order_id"`
		Recipient string                 `json:"recipient"`
		Channel   string                 `json:"channel"`
		Template  string                 `json:"template"`
		Data      map[string]interface{} `json:"data"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Recipient == "" {
		httpError(w, "recipient is required", http.StatusBadRequest)
		return
	}

	if req.Template == "" {
		httpError(w, "template is required", http.StatusBadRequest)
		return
	}

	if req.Channel == "" {
		req.Channel = "email"
	}

	// Idempotency check:
	// If this order has already received this notification,
	// return the existing notification instead of sending another one.
	if req.OrderID != 0 {
		var existingNotificationID int

		err := db.QueryRow(
			`SELECT id
			 FROM notifications
			 WHERE order_id = $1
			   AND template = $2
			   AND status = 'sent'
			 LIMIT 1`,
			req.OrderID,
			req.Template,
		).Scan(&existingNotificationID)

		if err == nil {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			json.NewEncoder(w).Encode(map[string]interface{}{
				"notification_id": existingNotificationID,
				"order_id":        req.OrderID,
				"status":          "sent",
			})
			return
		}

		if err != sql.ErrNoRows {
			httpError(w, "failed to check existing notification", http.StatusInternalServerError)
			return
		}
	}

	// Load notification template
	var subject sql.NullString
	var body string

	err := db.QueryRow(
		`SELECT subject, body
		 FROM notification_templates
		 WHERE id = $1
		   AND channel = $2`,
		req.Template,
		req.Channel,
	).Scan(&subject, &body)

	if err == sql.ErrNoRows {
		httpError(w, "notification template not found", http.StatusNotFound)
		return
	}

	if err != nil {
		httpError(w, "failed to load notification template", http.StatusInternalServerError)
		return
	}

	// Store notification data as JSON metadata
	metadata, err := json.Marshal(req.Data)
	if err != nil {
		httpError(w, "failed to encode notification data", http.StatusInternalServerError)
		return
	}

	// Simulated notification sending
	log.Printf(
		"Sending %s notification to %s using template %s for order %d",
		req.Channel,
		req.Recipient,
		req.Template,
		req.OrderID,
	)

	var notificationID int

	err = db.QueryRow(
		`INSERT INTO notifications
			(order_id, recipient, channel, template, subject, body, metadata, status, sent_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, 'sent', NOW())
		 RETURNING id`,
		req.OrderID,
		req.Recipient,
		req.Channel,
		req.Template,
		subject,
		body,
		metadata,
	).Scan(&notificationID)

	if err != nil {
		httpError(w, "failed to save notification", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"notification_id": notificationID,
		"order_id":        req.OrderID,
		"recipient":       req.Recipient,
		"channel":         req.Channel,
		"template":        req.Template,
		"status":          "sent",
	})
}

func handleHistory(w http.ResponseWriter, r *http.Request) {
	recipient := r.URL.Query().Get("recipient")

	query := "SELECT id, recipient, channel, template, subject, status, sent_at, created_at FROM notifications"
	args := []interface{}{}

	if recipient != "" {
		query += " WHERE recipient = $1"
		args = append(args, recipient)
	}
	query += " ORDER BY created_at DESC LIMIT 50"

	rows, err := db.Query(query, args...)
	if err != nil {
		httpError(w, "query failed", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	type Notif struct {
		ID        int    `json:"id"`
		Recipient string `json:"recipient"`
		Channel   string `json:"channel"`
		Template  string `json:"template"`
		Subject   string `json:"subject"`
		Status    string `json:"status"`
		SentAt    string `json:"sent_at"`
		CreatedAt string `json:"created_at"`
	}

	notifs := []Notif{}
	for rows.Next() {
		var n Notif
		var sentAt sql.NullString
		rows.Scan(&n.ID, &n.Recipient, &n.Channel, &n.Template, &n.Subject, &n.Status, &sentAt, &n.CreatedAt)
		if sentAt.Valid {
			n.SentAt = sentAt.String
		}
		notifs = append(notifs, n)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(notifs)
}

func handleTemplates(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, channel, subject, body FROM notification_templates ORDER BY id")
	if err != nil {
		httpError(w, "query failed", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	type Template struct {
		ID      string `json:"id"`
		Channel string `json:"channel"`
		Subject string `json:"subject"`
		Body    string `json:"body"`
	}

	templates := []Template{}
	for rows.Next() {
		var t Template
		rows.Scan(&t.ID, &t.Channel, &t.Subject, &t.Body)
		templates = append(templates, t)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(templates)
}

func httpError(w http.ResponseWriter, msg string, code int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func waitForDB() {
	for i := 0; i < 120; i++ {
		if err := db.Ping(); err == nil {
			return
		}
		log.Printf("Waiting for database... (%d/120)", i+1)
		time.Sleep(time.Second)
	}
	log.Fatal("Database not ready after 120s")
}
