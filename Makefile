SWIFT_FORMAT := ./scripts/dev/swift-format.sh
SWIFTLINT := ./scripts/dev/swiftlint.sh
SWIFT := ./scripts/dev/swift.sh

.PHONY: format lint verify-generated verify-shims verify-docs verify-unsafe-allowlist strict-concurrency test test-public-api-client check smoke-wayland integration-wayland release-check install-pre-commit

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

check: lint verify-generated verify-shims verify-docs verify-unsafe-allowlist strict-concurrency test test-public-api-client

smoke-wayland:
	@./scripts/smoke/smoke-wayland.sh

integration-wayland:
	@./scripts/smoke/integration-wayland.sh

release-check:
	@./scripts/ci/release-check.sh

install-pre-commit:
	@cp scripts/dev/pre-commit.sh .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
