APP_NAME = GLMStatus
BUILD_DIR = .build/release
APP_BUNDLE = build/$(APP_NAME).app

all: bundle

build:
	swift build -c release

bundle: build
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	@cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist

run: bundle
	@open $(APP_BUNDLE)

clean:
	rm -rf .build build

.PHONY: all build bundle run clean
