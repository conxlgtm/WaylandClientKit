SWIFT_FORMAT := ./Scripts/swift-format.sh
SWIFTLINT := ./Scripts/swiftlint.sh
SWIFT := ./Scripts/swift.sh

.PHONY: format lint verify-generated verify-shims verify-docs strict-concurrency test check smoke-wayland release-check install-pre-commit

format:
	@$(SWIFT_FORMAT) format --configuration .swift-format --in-place Package.swift
	@$(SWIFT_FORMAT) format --configuration .swift-format --in-place --parallel --recursive Sources Tests

lint:
	@$(SWIFT_FORMAT) lint --configuration .swift-format --strict Package.swift
	@$(SWIFT_FORMAT) lint --configuration .swift-format --strict --parallel --recursive Sources Tests
	@$(SWIFTLINT) lint --strict --no-cache --force-exclude --config .swiftlint.yml Package.swift Sources Tests

verify-generated:
	@./Scripts/verify-generated.sh

verify-shims:
	@./Scripts/verify-shims.sh

verify-docs:
	@./Scripts/verify-docs.sh

strict-concurrency:
	@$(SWIFT) build -Xswiftc -strict-concurrency=complete -Xswiftc -warn-concurrency

test:
	@$(SWIFT) test

check: lint verify-generated verify-shims verify-docs strict-concurrency test

smoke-wayland:
	@./Scripts/smoke-wayland.sh

release-check:
	@./Scripts/release-check.sh

install-pre-commit:
	@cp Scripts/pre-commit.sh .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
