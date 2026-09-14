package pushnow

import (
	"context"
	"testing"
)

func TestNoTokenOnlyDowngrade(t *testing.T) {
	c := New("runtime/main.js", "0000000000000000000000000000000000000000000000000000000000000000", Object{"source_key": "private"})
	_, err := c.Recipients(context.Background())
	if err == nil || err.Error() != "E2EE_CONFIG_REQUIRED" {
		t.Fatal("token-only request was not rejected")
	}
	if len(c.RequestLogs) != 0 {
		t.Fatal("unexpected network request")
	}
}
func TestMissingRuntimeRedacted(t *testing.T) {
	c := New("runtime/main.js", "", nil)
	c.Node = "/missing/pushnow-node"
	_, err := c.Recipients(context.Background())
	if err == nil || err.Error() != "BRIDGE_RUNTIME_FAILED" {
		t.Fatal("unsafe runtime error")
	}
}
