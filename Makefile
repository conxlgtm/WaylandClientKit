SWIFT_FORMAT := ./scripts/dev/swift-format.sh
SWIFTLINT := ./scripts/dev/swiftlint.sh
SWIFT := ./scripts/dev/swift.sh
CLANG_FILTER := $(CURDIR)/scripts/dev/clang-filter-index-store.sh
TSAN_SUPPRESSIONS := $(CURDIR)/scripts/safety/tsan-suppressions.txt

.PHONY: format lint verify-generated verify-protocol-manifest verify-shims verify-release-shim-symbols verify-docs verify-docc docc verify-public-api-audit verify-target-imports verify-unsafe-allowlist strict-concurrency test test-release test-tsan test-asan test-public-api-client test-graphics-preview-client check-base check check-wayland-smoke-if-available smoke-wayland smoke-wayland-headless integration-wayland integration-wayland-headless wayland-request-headless wayland-request-headless-tsan wayland-request-headless-asan gpu-preview-wayland gpu-preview-headless wayland-headless swiftbuild-smoke release-check install-pre-commit

format:
	@$(SWIFT_FORMAT) format --configuration .swift-format --in-place Package.swift
	@$(SWIFT_FORMAT) format --configuration .swift-format --in-place IntegrationTests/PublicAPIClient/Package.swift
	@$(SWIFT_FORMAT) format --configuration .swift-format --in-place IntegrationTests/GraphicsPreviewClient/Package.swift
	@$(SWIFT_FORMAT) format --configuration .swift-format --in-place --parallel --recursive Sources Tests Examples IntegrationTests/PublicAPIClient/Tests IntegrationTests/GraphicsPreviewClient/Tests

lint:
	@$(SWIFT_FORMAT) lint --configuration .swift-format --strict Package.swift
	@$(SWIFT_FORMAT) lint --configuration .swift-format --strict IntegrationTests/PublicAPIClient/Package.swift
	@$(SWIFT_FORMAT) lint --configuration .swift-format --strict IntegrationTests/GraphicsPreviewClient/Package.swift
	@$(SWIFT_FORMAT) lint --configuration .swift-format --strict --parallel --recursive Sources Tests Examples IntegrationTests/PublicAPIClient/Tests IntegrationTests/GraphicsPreviewClient/Tests
	@$(SWIFTLINT) lint --strict --no-cache --force-exclude --config .swiftlint.yml

verify-generated:
	@./scripts/protocols/verify-generated.sh

verify-protocol-manifest:
	@./scripts/protocols/verify-manifest.py

verify-shims:
	@./scripts/shims/verify-shims.sh

verify-release-shim-symbols:
	@./scripts/shims/verify-release-shim-symbols.sh

verify-docs:
	@./scripts/ci/verify-docs.sh

verify-docc:
	@./scripts/ci/verify-docc.sh

docc: verify-docc

verify-public-api-audit:
	@./scripts/ci/verify-public-api-audit.sh

verify-target-imports:
	@./scripts/ci/verify-target-imports.sh

verify-unsafe-allowlist:
	@bash ./scripts/safety/verify-unsafe-allowlist.sh

strict-concurrency:
	@$(SWIFT) build --disable-index-store -Xswiftc -strict-concurrency=complete -Xswiftc -warn-concurrency

test:
	@./scripts/ci/test-with-warnings-as-errors.sh

test-release:
	@$(SWIFT) test -c release

test-tsan:
	@env CC="$(CLANG_FILTER)" TSAN_OPTIONS="$${TSAN_OPTIONS:+$${TSAN_OPTIONS}:}detect_deadlocks=0:suppressions=$(TSAN_SUPPRESSIONS)" $(SWIFT) test --sanitize=thread

test-asan:
	@env CC="$(CLANG_FILTER)" $(SWIFT) test --sanitize=address

test-public-api-client:
	@./scripts/ci/test-public-api-client.sh

test-graphics-preview-client:
	@./scripts/ci/test-graphics-preview-client.sh

check-base: lint verify-generated verify-protocol-manifest verify-shims verify-docs verify-docc verify-public-api-audit verify-target-imports verify-unsafe-allowlist strict-concurrency test test-public-api-client test-graphics-preview-client

check: check-base check-wayland-smoke-if-available

check-wayland-smoke-if-available:
	@if [ -n "$${WAYLAND_DISPLAY:-}" ]; then \
		./scripts/smoke/smoke-wayland.sh; \
	else \
		echo "Skipping live Wayland smoke check because WAYLAND_DISPLAY is not set."; \
	fi

smoke-wayland:
	@./scripts/smoke/smoke-wayland.sh

smoke-wayland-headless:
	@./scripts/smoke/with-headless-weston.sh -- ./scripts/smoke/smoke-wayland.sh

integration-wayland:
	@./scripts/smoke/integration-wayland.sh

integration-wayland-headless:
	@./scripts/smoke/with-headless-weston.sh -- ./scripts/smoke/integration-wayland.sh

wayland-request-headless:
	@./scripts/ci/headless-request-tests.sh plain

wayland-request-headless-tsan:
	@./scripts/ci/headless-request-tests.sh tsan

wayland-request-headless-asan:
	@./scripts/ci/headless-request-tests.sh asan

gpu-preview-wayland:
	@./scripts/smoke/gpu-preview-wayland.sh

gpu-preview-headless:
	@./scripts/smoke/with-headless-weston.sh -- ./scripts/smoke/gpu-preview-wayland.sh

wayland-headless:
	@./scripts/smoke/with-headless-weston.sh -- bash -c './scripts/smoke/smoke-wayland.sh && ./scripts/smoke/integration-wayland.sh'

swiftbuild-smoke:
	@./scripts/ci/swiftbuild-smoke.sh

release-check:
	@./scripts/ci/release-check.sh

install-pre-commit:
	@cp scripts/dev/pre-commit.sh .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
