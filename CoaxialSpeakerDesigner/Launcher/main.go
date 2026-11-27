package main

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

func copyTreeWritable(src, dst string) error {
	return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		target := filepath.Join(dst, rel)
		if info.IsDir() {
			return os.MkdirAll(target, 0755)
		}
		if err := os.MkdirAll(filepath.Dir(target), 0755); err != nil {
			return err
		}
		in, err := os.Open(path)
		if err != nil {
			return err
		}
		defer in.Close()

		out, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
		if err != nil {
			return err
		}
		if _, err := io.Copy(out, in); err != nil {
			_ = out.Close()
			return err
		}
		return out.Close()
	})
}

func copyFileMode(src, dst string, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
		return err
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, mode)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		_ = out.Close()
		return err
	}
	return out.Close()
}

func showAlertDialog(message string) {
	escaped := strings.ReplaceAll(message, `\`, `\\`)
	escaped = strings.ReplaceAll(escaped, `"`, `\"`)
	script := fmt.Sprintf(`display dialog "%s" buttons {"OK"} default button "OK" with title "Coaxial Speaker Designer" with icon caution`, escaped)
	_ = exec.Command("/usr/bin/osascript", "-e", script).Run()
}

func main() {
	exePath, err := os.Executable()
	if err != nil {
		os.Exit(1)
	}
	if realExe, err := filepath.EvalSymlinks(exePath); err == nil {
		exePath = realExe
	}

	contentsDir := filepath.Dir(filepath.Dir(exePath))
	resourcesDir := filepath.Join(contentsDir, "Resources")
	swiftPkgSrc := filepath.Join(resourcesDir, "SwiftPackage")

	sourceHash := "v1.3.0"
	if hb, err := os.ReadFile(filepath.Join(resourcesDir, "source_hash.txt")); err == nil {
		if trimmed := strings.TrimSpace(string(hb)); trimmed != "" {
			sourceHash = trimmed
		}
	}

	homeDir, err := os.UserHomeDir()
	if err != nil || homeDir == "" {
		homeDir = os.Getenv("HOME")
	}

	cacheRoot := filepath.Join(homeDir, "Library", "Application Support", "CoaxialSpeakerDesignerNative")
	cachedAppParent := filepath.Join(cacheRoot, "App-"+sourceHash)
	cachedAppDir := filepath.Join(cachedAppParent, "CoaxialSpeakerDesigner.app")
	cachedBin := filepath.Join(cachedAppDir, "Contents", "MacOS", "CoaxialSpeakerDesigner")

	// Fast path: execute cached native SwiftUI binary directly in-place (same PID)
	if info, err := os.Stat(cachedBin); err == nil && !info.IsDir() && info.Size() > 0 {
		execArgs := append([]string{cachedBin}, os.Args[1:]...)
		if err := syscall.Exec(cachedBin, execArgs, os.Environ()); err == nil {
			return
		}
	}

	// Ensure developer toolchains are discoverable when launched from Finder/Dock
	curPath := os.Getenv("PATH")
	extraPaths := "/usr/bin:/bin:/usr/sbin:/sbin:/Library/Developer/CommandLineTools/usr/bin:/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin"
	if curPath != "" {
		_ = os.Setenv("PATH", curPath+":"+extraPaths)
	} else {
		_ = os.Setenv("PATH", extraPaths)
	}

	// Verify Apple Swift / Xcode Command Line Tools are installed
	if err := exec.Command("/usr/bin/xcode-select", "-p").Run(); err != nil {
		prompt := `display dialog "Coaxial Speaker Designer (Native SwiftUI) compiles once on first launch using Apple Swift.\n\nClick \"Install Tools\" to install Apple Command Line Tools, then open Coaxial Speaker Designer again." buttons {"Cancel", "Install Tools"} default button "Install Tools" with title "Coaxial Speaker Designer" with icon note`
		out, _ := exec.Command("/usr/bin/osascript", "-e", prompt).CombinedOutput()
		if strings.Contains(string(out), "Install Tools") {
			_ = exec.Command("/usr/bin/xcode-select", "--install").Start()
		}
		os.Exit(0)
	}

	if err := os.MkdirAll(cacheRoot, 0755); err != nil {
		showAlertDialog("Unable to create Application Support cache directory: " + err.Error())
		os.Exit(1)
	}

	_ = exec.Command("/usr/bin/osascript", "-e", `display notification "Building native SwiftUI app for Apple Silicon (first launch only)..." with title "Coaxial Speaker Designer"`).Start()

	workDir := filepath.Join(cacheRoot, fmt.Sprintf("build-%d", os.Getpid()))
	_ = os.RemoveAll(workDir)
	pkgDir := filepath.Join(workDir, "CoaxialSpeakerDesigner")

	if err := copyTreeWritable(swiftPkgSrc, pkgDir); err != nil {
		_ = os.RemoveAll(workDir)
		showAlertDialog("Failed to stage Swift package sources: " + err.Error())
		os.Exit(1)
	}

	var buildOut bytes.Buffer
	cmd := exec.Command("/usr/bin/xcrun", "swift", "build", "-c", "release", "--package-path", pkgDir)
	cmd.Stdout = &buildOut
	cmd.Stderr = &buildOut
	buildErr := cmd.Run()

	logPath := filepath.Join(cacheRoot, "build.log")
	_ = os.WriteFile(logPath, buildOut.Bytes(), 0644)

	if buildErr != nil {
		_ = os.RemoveAll(workDir)
		lines := strings.Split(strings.TrimSpace(buildOut.String()), "\n")
		tail := lines
		if len(tail) > 8 {
			tail = tail[len(tail)-8:]
		}
		showAlertDialog(fmt.Sprintf("Native SwiftUI compilation failed (see %s):\n\n%s", logPath, strings.Join(tail, "\n")))
		os.Exit(1)
	}

	// Locate compiled release binary
	candidates := []string{
		filepath.Join(pkgDir, ".build", "arm64-apple-macosx", "release", "CoaxialSpeakerDesigner"),
		filepath.Join(pkgDir, ".build", "release", "CoaxialSpeakerDesigner"),
	}
	builtBin := ""
	for _, c := range candidates {
		if st, err := os.Stat(c); err == nil && !st.IsDir() && st.Size() > 0 {
			builtBin = c
			break
		}
	}
	if builtBin == "" {
		_ = os.RemoveAll(workDir)
		showAlertDialog("Compiled SwiftUI binary was not found in .build/release.")
		os.Exit(1)
	}

	// Stage a complete native .app bundle in Application Support cache
	stageApp := filepath.Join(workDir, "Stage", "CoaxialSpeakerDesigner.app")
	stageBin := filepath.Join(stageApp, "Contents", "MacOS", "CoaxialSpeakerDesigner")
	if err := copyFileMode(builtBin, stageBin, 0755); err != nil {
		_ = os.RemoveAll(workDir)
		showAlertDialog("Failed to stage compiled binary: " + err.Error())
		os.Exit(1)
	}
	_ = copyFileMode(filepath.Join(contentsDir, "Info.plist"), filepath.Join(stageApp, "Contents", "Info.plist"), 0644)
	_ = os.WriteFile(filepath.Join(stageApp, "Contents", "PkgInfo"), []byte("APPL????"), 0644)
	_ = exec.Command("/usr/bin/codesign", "--force", "--deep", "--sign", "-", stageApp).Run()

	_ = os.RemoveAll(cachedAppParent)
	if err := os.MkdirAll(cachedAppParent, 0755); err != nil {
		_ = os.RemoveAll(workDir)
		showAlertDialog("Failed to finalize cached bundle directory: " + err.Error())
		os.Exit(1)
	}
	if err := os.Rename(stageApp, cachedAppDir); err != nil {
		if err := copyTreeWritable(stageApp, cachedAppDir); err != nil {
			_ = os.RemoveAll(workDir)
			showAlertDialog("Failed to install cached app bundle: " + err.Error())
			os.Exit(1)
		}
		_ = os.Chmod(cachedBin, 0755)
	}

	// Remove temporary build folder before replacing process image
	_ = os.RemoveAll(workDir)

	execArgs := append([]string{cachedBin}, os.Args[1:]...)
	if err := syscall.Exec(cachedBin, execArgs, os.Environ()); err != nil {
		showAlertDialog("Failed to launch compiled native SwiftUI binary: " + err.Error())
		os.Exit(1)
	}
}
