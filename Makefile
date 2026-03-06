PROJECT = MacMonitor.xcodeproj
SCHEME = MacMonitor
DEST = platform=macOS
RELEASE_VERSION ?= $(shell /usr/bin/python3 -c 'import json,pathlib; p=pathlib.Path(".release-please-manifest.json"); print((json.loads(p.read_text()).get(".", "0.1.0")) if p.exists() else "0.1.0")')

generate:
	xcodegen generate

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' MARKETING_VERSION='$(RELEASE_VERSION)' build

test: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' MARKETING_VERSION='$(RELEASE_VERSION)' test

ci: build test

package-test:
	./scripts/create-test-build.sh
