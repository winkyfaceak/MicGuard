.PHONY: build test devices bundle run install uninstall clean

# Fast compile check while editing.
build:
	swift build

# Assertions over the selection rules. Not `swift test` — Command Line Tools
# has no test framework, so the checks live in their own executable.
test:
	@swift run MicGuardCheck

# What Core Audio actually sees right now. First thing to run when the app
# picks the wrong device.
devices:
	@swift run MicGuardCheck devices

# Produce build/MicGuard.app — needed for the menu bar item and login item.
bundle:
	@./Scripts/bundle.sh release

# Relaunch the app fresh. This is the main inner-loop command.
run: bundle
	@pkill -x MicGuard 2>/dev/null || true
	@open build/MicGuard.app
	@echo "MicGuard running — look for the mic icon in the menu bar."

# Move it to /Applications so it survives a clean and can launch at login.
install: bundle
	@pkill -x MicGuard 2>/dev/null || true
	rm -rf /Applications/MicGuard.app
	cp -R build/MicGuard.app /Applications/
	@open /Applications/MicGuard.app
	@echo "Installed to /Applications/MicGuard.app"

uninstall:
	@pkill -x MicGuard 2>/dev/null || true
	rm -rf /Applications/MicGuard.app
	@echo "Removed /Applications/MicGuard.app"

clean:
	swift package clean
	rm -rf build .build
