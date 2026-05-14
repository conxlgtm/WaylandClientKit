SWIFT_FORMAT := ./scripts/dev/swift-format.sh
SWIFTLINT := ./scripts/dev/swiftlint.sh
SWIFT := ./scripts/dev/swift.sh

.PHONY: format lint verify-generated verify-shims verify-release-shim-symbols verify-docs verify-unsafe-allowlist strict-concurrency test test-public-api-client check-base check check-wayland-smoke-if-available smoke-wayland smoke-wayland-headless integration-wayland integration-wayland-headless wayland-headless release-check install-pre-commit

format:
	@$(SWIFT_FORMAT) format --configuration .swift-format --in-place Package.swift
	@$(SWIFT_FORMAT) format --configuration .swift-format --in-place IntegrationTests/PublicAPIClient/Package.swift
	@$(SWIFT_FORMAT) format --configuration .swift-format --in-place --parallel --recursive Sources Tests Examples IntegrationTests/PublicAPIClient/Tests

lint:
	@$(SWIFT_FORMAT) lint --configuration .swift-format --strict Package.swift
	@$(SWIFT_FORMAT) lint --configuration .swift-format --strict IntegrationTests/PublicAPIClient/Package.swift
	@$(SWIFT_FORMAT) lint --configuration .swift-format --strict --parallel --recursive Sources Tests Examples IntegrationTests/PublicAPIClient/Tests
	@$(SWIFTLINT) lint --strict --no-cache --force-exclude --config .swiftlint.yml

verify-generated:
	@./scripts/protocols/verify-generated.sh

verify-shims:
	@./scripts/shims/verify-shims.sh

verify-release-shim-symbols:
	@./scripts/shims/verify-release-shim-symbols.sh

verify-docs:
	@./scripts/ci/verify-docs.sh

verify-unsafe-allowlist:
	@bash ./scripts/safety/verify-unsafe-allowlist.sh

strict-concurrency:
	@$(SWIFT) build --disable-index-store -Xswiftc -strict-concurrency=complete -Xswiftc -warn-concurrency

test:
	@./scripts/ci/test-with-warnings-as-errors.sh

test-public-api-client:
	@./scripts/ci/test-public-api-client.sh

check-base: lint verify-generated verify-shims verify-docs verify-unsafe-allowlist strict-concurrency test test-public-api-client

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

wayland-headless:
	@./scripts/smoke/with-headless-weston.sh -- bash -c './scripts/smoke/smoke-wayland.sh && ./scripts/smoke/integration-wayland.sh'

release-check:
	@./scripts/ci/release-check.sh

install-pre-commit:
	@cp scripts/dev/pre-commit.sh .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
