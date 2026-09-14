package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
)

var ErrInsufficientStock = errors.New("insufficient stock")
var ErrPaymentFailed = errors.New("payment failed")

type SQSMessage struct {
	Body          string
	ReceiptHandle string
}

// Event represents a message from SQS
type Event struct {
	Type      string                 `json:"type"`
	Payload   map[string]interface{} `json:"payload"`
	Timestamp string                 `json:"timestamp"`
}

func main() {
	sqsQueue := os.Getenv("SQS_QUEUE_URL")
	if sqsQueue == "" {
		log.Fatal("SQS_QUEUE_URL is required")
	}

	// Internal service URLs for event-driven calls
	services := map[string]string{
		"inventory":    getEnv("INVENTORY_SERVICE_URL", "http://inventory-service-service"),
		"payment":      getEnv("PAYMENT_SERVICE_URL", "http://payment-service-service"),
		"notification": getEnv("NOTIFICATION_SERVICE_URL", "http://notification-service-service"),
		"shipping":     getEnv("SHIPPING_SERVICE_URL", "http://shipping-service-service"),
		"order":        getEnv("ORDER_SERVICE_URL", "http://order-service-service"),
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Health check endpoint
	go func() {
		mux := http.NewServeMux()
		mux.HandleFunc("/livez", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) })
		mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{"status": "ok", "service": "worker"})
		})
		port := getEnv("HEALTH_PORT", "8090")
		log.Printf("Worker health check on :%s", port)
		http.ListenAndServe(":"+port, mux)
	}()

	// Graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		log.Println("Shutting down worker...")
		cancel()
	}()

	log.Println("Worker started, polling SQS for events...")
	pollAndProcess(ctx, sqsQueue, services)
}

func pollAndProcess(ctx context.Context, queueURL string, services map[string]string) {
	client := &http.Client{Timeout: 10 * time.Second}

	for {
		select {
		case <-ctx.Done():
			log.Println("Worker stopped")
			return
		default:
			messages := receiveSQSMessages(ctx, queueURL)

			for _, message := range messages {
				var event Event

				if err := json.Unmarshal([]byte(message.Body), &event); err != nil {
					log.Printf("Failed to parse event: %v", err)
					continue
				}

				log.Printf("Processing event: %s", event.Type)

				if err := handleEvent(client, services, event); err != nil {
					log.Printf("Failed to handle event %s: %v", event.Type, err)
					// In production: don't delete from SQS, let it retry or go to DLQ
					continue
				}

				log.Printf("Successfully processed: %s", event.Type)

				if err := deleteSQSMessage(ctx, queueURL, message.ReceiptHandle); err != nil {
					log.Printf("Failed to delete SQS message: %v", err)
					continue
				}

				log.Printf("Deleted message from SQS: %s", event.Type)

			}

			if len(messages) == 0 {
				time.Sleep(5 * time.Second)
			}
		}
	}
}

func handleEvent(client *http.Client, services map[string]string, event Event) error {
	switch event.Type {

	case "order.created":
		// 1. Reserve inventory
		log.Printf("  -> Reserving inventory for order")

		inventoryURL := services["inventory"]

		if err := reserveInventory(client, inventoryURL, event); err != nil {
			if errors.Is(err, ErrInsufficientStock) {
				log.Printf("  -> Insufficient stock, cancelling order")

				orderURL := services["order"]

				if err := cancelOrder(client, orderURL, event); err != nil {
					return fmt.Errorf("failed to cancel order: %w", err)
				}

				log.Printf("  -> Order cancelled successfully")

				// Return nil so the SQS message gets deleted
				return nil
			}

			return fmt.Errorf("failed to reserve inventory: %w", err)
		}

		log.Printf("  -> Inventory reserved successfully")

		// 2. Process payment
		log.Printf("  -> Processing payment")
		paymentURL := services["payment"]

		if err := chargePayment(client, paymentURL, event); err != nil {
			if errors.Is(err, ErrPaymentFailed) {
				log.Printf("  -> Payment failed, releasing inventory")

				inventoryURL := services["inventory"]

				if err := releaseInventory(client, inventoryURL, event); err != nil {
					return fmt.Errorf("failed to release inventory: %w", err)
				}

				log.Printf("  -> Inventory released successfully")

				log.Printf("  -> Cancelling order")

				orderURL := services["order"]

				if err := cancelOrder(client, orderURL, event); err != nil {
					return fmt.Errorf("failed to cancel order: %w", err)
				}

				log.Printf("  -> Order cancelled successfully")

				// Business failure handled successfully,
				// so delete the SQS message.
				return nil
			}

			return fmt.Errorf("failed to process payment: %w", err)
		}

		log.Printf("  -> Payment completed successfully")

		// 3. Send confirmation notification
		log.Printf("  -> Sending order confirmation")

		notificationURL := services["notification"]

		if err := sendOrderConfirmation(client, notificationURL, event); err != nil {
			return fmt.Errorf("failed to send order confirmation: %w", err)
		}

		log.Printf("  -> Order confirmation sent successfully")

		// 4. Update order to confirmed
		log.Printf("  -> Confirming order")

		orderURL := services["order"]

		if err := confirmOrder(client, orderURL, event); err != nil {
			return fmt.Errorf("failed to confirm order: %w", err)
		}

		log.Printf("  -> Order confirmed successfully")

	case "order.status_changed":
		newStatus, _ := event.Payload["new_status"].(string)

		switch newStatus {

		case "processing":
			log.Printf("  -> Creating shipment for order")

			shippingURL := services["shipping"]
			orderURL := services["order"]

			if err := createShipment(client, shippingURL, orderURL, event); err != nil {
				return fmt.Errorf("failed to create shipment: %w", err)
			}

			log.Printf("  -> Shipment created successfully")

		case "shipped":
			// Notify customer
			log.Printf("  -> Sending shipping notification")
			// POST to notification-service/send with order_shipped template

		case "delivered":
			log.Printf("  -> Sending delivery notification")
			// POST to notification-service/send with order_delivered template

		case "cancelled":
			// Release inventory
			log.Printf("  -> Releasing inventory reservation")
			// POST to inventory-service/release

			// Process refund if payment was made
			log.Printf("  -> Processing refund")
			// POST to payment-service/refund
		}

	case "payment.completed":
		log.Printf("  -> Payment successful, confirming order")
		// Update order status to confirmed

	case "payment.failed":
		log.Printf("  -> Payment failed, cancelling order")
		// Release inventory reservation
		// Update order status to cancelled
		// Send payment failed notification

	case "shipment.created":
		log.Printf("  -> Shipment created, updating order to processing")
		// Update order status

	case "shipment.delivered":
		log.Printf("  -> Shipment delivered, updating order")
		// Update order status to delivered
		// Send delivery notification

	default:
		log.Printf("  -> Unknown event type: %s (skipping)", event.Type)
	}

	_ = client
	_ = services
	return nil
}

func receiveSQSMessages(ctx context.Context, queueURL string) []SQSMessage {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Printf("Failed to load AWS config: %v", err)
		return nil
	}

	client := sqs.NewFromConfig(cfg)

	result, err := client.ReceiveMessage(ctx, &sqs.ReceiveMessageInput{
		QueueUrl:            aws.String(queueURL),
		MaxNumberOfMessages: 10,
		WaitTimeSeconds:     20,
	})

	if err != nil {
		log.Printf("Failed to receive SQS messages: %v", err)
		return nil
	}

	messages := make([]SQSMessage, 0, len(result.Messages))

	for _, msg := range result.Messages {
		messages = append(messages, SQSMessage{
			Body:          aws.ToString(msg.Body),
			ReceiptHandle: aws.ToString(msg.ReceiptHandle),
		})
	}

	return messages
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func deleteSQSMessage(ctx context.Context, queueURL, receiptHandle string) error {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return err
	}

	client := sqs.NewFromConfig(cfg)

	_, err = client.DeleteMessage(ctx, &sqs.DeleteMessageInput{
		QueueUrl:      aws.String(queueURL),
		ReceiptHandle: aws.String(receiptHandle),
	})

	return err
}

func reserveInventory(
	client *http.Client,
	inventoryURL string,
	event Event,
) error {

	orderID, ok := event.Payload["order_id"].(float64)
	if !ok {
		return fmt.Errorf("missing or invalid order_id")
	}

	items, ok := event.Payload["items"]
	if !ok {
		return fmt.Errorf("missing order items")
	}

	payload := map[string]interface{}{
		"order_id": int(orderID),
		"items":    items,
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal inventory request: %w", err)
	}

	req, err := http.NewRequest(
		http.MethodPost,
		inventoryURL+"/reserve",
		bytes.NewBuffer(body),
	)
	if err != nil {
		return fmt.Errorf("failed to create inventory request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("inventory request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusConflict {
		responseBody, _ := io.ReadAll(resp.Body)

		return fmt.Errorf(
			"%w: %s",
			ErrInsufficientStock,
			string(responseBody),
		)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		responseBody, _ := io.ReadAll(resp.Body)

		return fmt.Errorf(
			"inventory reservation failed: status=%d body=%s",
			resp.StatusCode,
			string(responseBody),
		)
	}

	return nil

}

func chargePayment(client *http.Client, paymentURL string, event Event) error {
	orderID, ok := event.Payload["order_id"].(float64)
	if !ok {
		return fmt.Errorf("missing or invalid order_id")
	}

	customerID, ok := event.Payload["customer_id"].(string)
	if !ok || customerID == "" {
		return fmt.Errorf("missing or invalid customer_id")
	}

	total, ok := event.Payload["total"].(float64)
	if !ok {
		return fmt.Errorf("missing or invalid total")
	}

	currency, _ := event.Payload["currency"].(string)
	if currency == "" {
		currency = "GBP"
	}

	body := map[string]interface{}{
		"order_id":    int(orderID),
		"customer_id": customerID,
		"amount":      total,
		"currency":    currency,
		"method":      "card",
	}

	data, err := json.Marshal(body)
	if err != nil {
		return err
	}

	req, err := http.NewRequest(
		http.MethodPost,
		paymentURL+"/charge",
		bytes.NewBuffer(data),
	)
	if err != nil {
		return err
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode == http.StatusPaymentRequired {
		return fmt.Errorf("%w: %s", ErrPaymentFailed, string(respBody))
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("payment service returned %d: %s",
			resp.StatusCode,
			string(respBody),
		)
	}

	return nil
}

func sendOrderConfirmation(client *http.Client, notificationURL string, event Event) error {
	orderID, ok := event.Payload["order_id"].(float64)
	if !ok {
		return fmt.Errorf("missing or invalid order_id")
	}

	customerID, ok := event.Payload["customer_id"].(string)
	if !ok || customerID == "" {
		return fmt.Errorf("missing or invalid customer_id")
	}

	total, ok := event.Payload["total"].(float64)
	if !ok {
		return fmt.Errorf("missing or invalid total")
	}

	currency, _ := event.Payload["currency"].(string)
	if currency == "" {
		currency = "GBP"
	}

	body := map[string]interface{}{
		"order_id":  int(orderID),
		"recipient": customerID,
		"channel":   "email",
		"template":  "order_confirmed",
		"data": map[string]interface{}{
			"OrderID":  int(orderID),
			"Total":    total,
			"Currency": currency,
		},
	}

	data, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("failed to marshal notification request: %w", err)
	}

	req, err := http.NewRequest(
		http.MethodPost,
		notificationURL+"/send",
		bytes.NewBuffer(data),
	)
	if err != nil {
		return fmt.Errorf("failed to create notification request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("notification request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf(
			"notification service returned %d: %s",
			resp.StatusCode,
			string(respBody),
		)
	}

	return nil
}

func confirmOrder(client *http.Client, orderURL string, event Event) error {
	orderID, ok := event.Payload["order_id"].(float64)
	if !ok {
		return fmt.Errorf("missing or invalid order_id")
	}

	body := map[string]interface{}{
		"order_id":   int(orderID),
		"new_status": "confirmed",
	}

	data, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("failed to marshal order status request: %w", err)
	}

	req, err := http.NewRequest(
		http.MethodPut,
		orderURL+"/status",
		bytes.NewBuffer(data),
	)
	if err != nil {
		return fmt.Errorf("failed to create order status request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("order status request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf(
			"order service returned %d: %s",
			resp.StatusCode,
			string(respBody),
		)
	}

	return nil
}

func cancelOrder(client *http.Client, orderURL string, event Event) error {
	orderID, ok := event.Payload["order_id"].(float64)
	if !ok {
		return fmt.Errorf("missing or invalid order_id")
	}

	body := map[string]interface{}{
		"order_id":   int(orderID),
		"new_status": "cancelled",
	}

	data, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("failed to marshal order status request: %w", err)
	}

	req, err := http.NewRequest(
		http.MethodPut,
		orderURL+"/status",
		bytes.NewBuffer(data),
	)
	if err != nil {
		return fmt.Errorf("failed to create order cancellation request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("order cancellation request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf(
			"order service returned %d: %s",
			resp.StatusCode,
			string(respBody),
		)
	}

	return nil
}

func releaseInventory(
	client *http.Client,
	inventoryURL string,
	event Event,
) error {

	orderID, ok := event.Payload["order_id"].(float64)
	if !ok {
		return fmt.Errorf("missing or invalid order_id")
	}

	body := map[string]interface{}{
		"order_id": int(orderID),
	}

	data, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("failed to marshal release request: %w", err)
	}

	req, err := http.NewRequest(
		http.MethodPost,
		inventoryURL+"/release",
		bytes.NewBuffer(data),
	)
	if err != nil {
		return fmt.Errorf("failed to create release request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("inventory release request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf(
			"inventory release failed: status=%d body=%s",
			resp.StatusCode,
			string(respBody),
		)
	}

	return nil
}

func createShipment(
	client *http.Client,
	shippingURL string,
	orderURL string,
	event Event,
) error {

	orderID, ok := event.Payload["order_id"].(float64)
	if !ok {
		return fmt.Errorf("missing or invalid order_id")
	}

	// Fetch the order so we can get the customer information.
	req, err := http.NewRequest(
		http.MethodGet,
		fmt.Sprintf("%s/%d", orderURL, int(orderID)),
		nil,
	)
	if err != nil {
		return fmt.Errorf("failed to create order request: %w", err)
	}

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to fetch order: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		responseBody, _ := io.ReadAll(resp.Body)

		return fmt.Errorf(
			"order service returned %d: %s",
			resp.StatusCode,
			string(responseBody),
		)
	}

	var order struct {
		CustomerID string `json:"customer_id"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&order); err != nil {
		return fmt.Errorf("failed to decode order: %w", err)
	}

	if order.CustomerID == "" {
		return fmt.Errorf("order has no customer_id")
	}

	shipmentBody := map[string]interface{}{
		"order_id":       int(orderID),
		"recipient_name": order.CustomerID,
	}

	data, err := json.Marshal(shipmentBody)
	if err != nil {
		return fmt.Errorf("failed to marshal shipment request: %w", err)
	}

	shipmentReq, err := http.NewRequest(
		http.MethodPost,
		shippingURL+"/shipments",
		bytes.NewBuffer(data),
	)
	if err != nil {
		return fmt.Errorf("failed to create shipment request: %w", err)
	}

	shipmentReq.Header.Set("Content-Type", "application/json")

	shipmentResp, err := client.Do(shipmentReq)
	if err != nil {
		return fmt.Errorf("shipping request failed: %w", err)
	}
	defer shipmentResp.Body.Close()

	responseBody, _ := io.ReadAll(shipmentResp.Body)

	if shipmentResp.StatusCode < 200 || shipmentResp.StatusCode >= 300 {
		return fmt.Errorf(
			"shipping service returned %d: %s",
			shipmentResp.StatusCode,
			string(responseBody),
		)
	}

	return nil
}
