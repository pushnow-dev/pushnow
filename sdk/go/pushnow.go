// Package pushnow provides account-bound E2EE v2 bindings to the bundled Node.js runtime.
package pushnow

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"os/exec"
	"time"
)

type Object = map[string]any
type File struct {
	Path       string  `json:"path,omitempty"`
	DataBase64 *string `json:"dataBase64,omitempty"`
	Name       string  `json:"name,omitempty"`
	MIME       string  `json:"mime,omitempty"`
}
type Notification struct {
	Title       string    `json:"title"`
	Body        string    `json:"body"`
	Links       []string  `json:"links,omitempty"`
	Files       []File    `json:"files,omitempty"`
	Images      []File    `json:"images,omitempty"`
	Icon        *File     `json:"icon,omitempty"`
	DeviceIDs   *[]string `json:"deviceIds,omitempty"`
	PushEnabled *bool     `json:"pushEnabled,omitempty"`
	ScheduledAt string    `json:"scheduledAt,omitempty"`
	ExpiresAt   string    `json:"expiresAt,omitempty"`
	Sound       *string   `json:"sound,omitempty"` // nil preserves legacy behavior; default, silent or chime.
}
type RequestLog struct {
	Method    string `json:"method"`
	Route     string `json:"route"`
	Status    int    `json:"status"`
	ElapsedMS int    `json:"elapsedMs"`
}

// Client is not safe for concurrent use. Use one client per goroutine.
type Client struct {
	Node            string
	RuntimePath     string
	RootFingerprint string
	Config          Object
	RequestLogs     []RequestLog
}

func New(runtimePath, rootFingerprint string, config Object) *Client {
	return &Client{Node: "node", RuntimePath: runtimePath, RootFingerprint: rootFingerprint, Config: config}
}
func (c *Client) call(ctx context.Context, operation string, arguments Object) (Object, error) {
	payload := Object{"operation": operation, "rootFingerprint": c.RootFingerprint, "config": c.Config}
	for k, v := range arguments {
		payload[k] = v
	}
	input, err := json.Marshal(payload)
	if err != nil {
		return nil, errors.New("INVALID_INPUT")
	}
	ctx, cancel := context.WithTimeout(ctx, 660*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, c.Node, c.RuntimePath)
	cmd.WaitDelay = 2 * time.Second
	cmd.Stdin = bytes.NewReader(input)
	cmd.Stderr = io.Discard
	output, err := cmd.Output()
	if err != nil {
		return nil, errors.New("BRIDGE_RUNTIME_FAILED")
	}
	var reply struct {
		OK    bool   `json:"ok"`
		Data  Object `json:"data"`
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
		Logs []RequestLog `json:"logs"`
	}
	if json.Unmarshal(output, &reply) != nil {
		return nil, errors.New("BRIDGE_RUNTIME_FAILED")
	}
	c.RequestLogs = append(c.RequestLogs, reply.Logs...)
	if !reply.OK {
		if reply.Error.Code == "" {
			reply.Error.Code = "E2EE_REQUEST_FAILED"
		}
		return nil, errors.New(reply.Error.Code)
	}
	return reply.Data, nil
}
func (c *Client) BeginAuthorization(ctx context.Context, apiURL, name string) (Object, error) {
	return c.call(ctx, "beginAuthorization", Object{"apiURL": apiURL, "name": name})
}
func (c *Client) Authorize(ctx context.Context, pending Object) (Object, error) {
	config, err := c.call(ctx, "finishAuthorization", Object{"pending": pending})
	if err == nil {
		c.Config = config
	}
	return config, err
}
func (c *Client) Recipients(ctx context.Context) (Object, error) {
	return c.call(ctx, "recipients", nil)
}
func (c *Client) Prepare(ctx context.Context, n Notification) (Object, error) {
	return c.call(ctx, "prepare", Object{"notification": n})
}
func (c *Client) Send(ctx context.Context, n Notification) (Object, error) {
	return c.call(ctx, "send", Object{"notification": n})
}
func (c *Client) Retry(ctx context.Context, envelope Object) (Object, error) {
	return c.call(ctx, "retry", Object{"envelope": envelope})
}
