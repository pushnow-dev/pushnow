package main

import (
	"context"
	"encoding/json"
	pushnow "github.com/pushnow-dev/pushnow-go"
	"os"
)

func must(value pushnow.Object, err error) pushnow.Object {
	if err != nil {
		panic(err)
	}
	return value
}
func main() {
	var input struct {
		APIURL       string               `json:"apiURL"`
		Root         string               `json:"rootFingerprint"`
		Notification pushnow.Notification `json:"notification"`
	}
	if err := json.NewDecoder(os.Stdin).Decode(&input); err != nil {
		panic("INVALID_TEST_INPUT")
	}
	ctx := context.Background()
	client := pushnow.New("runtime/main.js", input.Root, nil)
	pending := must(client.BeginAuthorization(ctx, input.APIURL, "Go integration"))
	must(client.Authorize(ctx, pending))
	directory := must(client.Recipients(ctx))
	envelope := must(client.Prepare(ctx, input.Notification))
	first := must(client.Retry(ctx, envelope))
	second := must(client.Retry(ctx, envelope))
	silent, defaultSound := "silent", "default"
	sent := must(client.Send(ctx, pushnow.Notification{Title: "Immediate Go", Body: "Second message", Sound: &silent}))
	defaultEnvelope := must(client.Prepare(ctx, pushnow.Notification{Title: "Default sound", Sound: &defaultSound}))
	legacyEnvelope := must(client.Prepare(ctx, pushnow.Notification{Title: "Legacy sound"}))
	sound := "custom"
	unknown := []string{"00000000-0000-0000-0000-000000000000"}
	codes := []string{}
	for _, n := range []pushnow.Notification{{Title: "Unsupported", Sound: &sound}, {Title: "Foreign", DeviceIDs: &unknown}} {
		_, err := client.Prepare(ctx, n)
		if err == nil {
			panic("INVALID_NOTIFICATION_ACCEPTED")
		}
		codes = append(codes, err.Error())
	}
	changed := pushnow.Object{}
	for key, value := range envelope {
		changed[key] = value
	}
	changed["sound"] = "silent"
	_, err := client.Retry(ctx, changed)
	if err == nil {
		panic("CHANGED_SOUND_ACCEPTED")
	}
	codes = append(codes, err.Error())
	if err := json.NewEncoder(os.Stdout).Encode(pushnow.Object{"envelope": envelope, "first": first, "second": second, "sent": sent,
		"defaultEnvelope": defaultEnvelope, "legacyEnvelope": legacyEnvelope,
		"deviceCount": len(directory["devices"].([]any)), "errors": codes, "logs": client.RequestLogs}); err != nil {
		panic(err)
	}
}
