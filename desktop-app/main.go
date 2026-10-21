package main

import (
	"embed"
	"fmt"
	"io/fs"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"runtime"
	"syscall"
	"time"
)

//go:embed dist/*
var webAssets embed.FS

func main() {
	// Sub-filesystem for embedded dist directory
	distFS, err := fs.Sub(webAssets, "dist")
	if err != nil {
		fmt.Printf("Error accessing embedded assets: %v\n", err)
		os.Exit(1)
	}

	// Listen on an available loopback port
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		fmt.Printf("Error binding local port: %v\n", err)
		os.Exit(1)
	}
	port := listener.Addr().(*net.TCPAddr).Port
	url := fmt.Sprintf("http://127.0.0.1:%d", port)

	fmt.Println("==================================================")
	fmt.Println("   HP-35 RPN Scientific Calculator Desktop App   ")
	fmt.Println("==================================================")
	fmt.Printf("Serving calculator at: %s\n", url)
	fmt.Println("Press Ctrl+C to exit.")
	fmt.Println("==================================================")

	// HTTP File Server
	server := &http.Server{
		Handler: http.FileServer(http.FS(distFS)),
	}

	go func() {
		if err := server.Serve(listener); err != nil && err != http.ErrServerClosed {
			fmt.Printf("Server error: %v\n", err)
		}
	}()

	// Open browser / native webview window
	go func() {
		time.Sleep(150 * time.Millisecond)
		openURL(url)
	}()

	// Graceful shutdown on SIGINT/SIGTERM
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	<-sigChan

	fmt.Println("\nShutting down HP-35 Desktop App. Goodbye!")
}

func openURL(url string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		cmd = exec.Command("open", url)
	case "windows":
		cmd = exec.Command("cmd", "/c", "start", url)
	default:
		cmd = exec.Command("xdg-open", url)
	}
	_ = cmd.Start()
}
