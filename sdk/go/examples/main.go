package main

import (
	"context"
	"encoding/json"
	pushnow "github.com/pushnow-dev/pushnow-go"
	"fmt"
	"os"
)

func check(err error) {
	if err != nil {
		panic(err)
	}
}
func save(path string, value pushnow.Object) {
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	check(err)
	defer f.Close()
	check(json.NewEncoder(f).Encode(value))
}
func load(path string) (pushnow.Object, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var value pushnow.Object
	err = json.Unmarshal(raw, &value)
	return value, err
}
func main() {
	if len(os.Args) != 2 {
		fmt.Println("Usage: go run ./examples authorize|send")
		return
	}
	c := pushnow.New("runtime/main.js", nil)
	ctx := context.Background()
	switch os.Args[1] {
	case "authorize":
		pending, err := c.BeginAccountAuthorization(ctx, "https://api.pushnow.dev", os.Getenv("PUSHNOW_ACCESS_TOKEN"), "Go automation")
		check(err)
		fmt.Println("Approve code:", pending["authorization"].(map[string]any)["user_code"])
		fmt.Println("Sender fingerprint:", pending["fingerprint"])
		config, err := c.AuthorizeAccount(ctx, pending)
		check(err)
		save("private-config.json", config)
		fmt.Println("Authorized. Private configuration stored locally.")
	case "send":
		config, err := load("private-config.json")
		check(err)
		c.Config = config
		envelope, err := load("outbox.json")
		if os.IsNotExist(err) {
			envelope, err = c.Prepare(ctx, pushnow.Notification{Title: "Build finished", Body: "Your artifact is ready."})
			check(err)
			save("outbox.json", envelope)
		} else {
			check(err)
		}
		result, err := c.Retry(ctx, envelope)
		check(err)
		fmt.Println("API accepted:", result["message_id"], "deduplicated:", result["deduplicated"])
	default:
		fmt.Println("Use authorize or send.")
	}
}
