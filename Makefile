SWIFT_FORMAT := ./Scripts/swift-format.sh
SWIFTLINT := ./Scripts/swiftlint.sh
SWIFT := ./Scripts/swift.sh

.PHONY: format lint verify-generated test check install-pre-commit

format:
	@$(SWIFT_FORMAT) format --configuration .swift-format --in-place Package.swift
	@$(SWIFT_FORMAT) format --configuration .swift-format --in-place --parallel --recursive Sources Tests

lint:
	@$(SWIFT_FORMAT) lint --configuration .swift-format --strict Package.swift
	@$(SWIFT_FORMAT) lint --configuration .swift-format --strict --parallel --recursive Sources Tests
	@$(SWIFTLINT) lint --strict --no-cache --force-exclude --config .swiftlint.yml Package.swift Sources Tests

verify-generated:
	@./Scripts/verify-generated.sh

test:
	@$(SWIFT) test

check: lint verify-generated test

install-pre-commit:
	@cp Scripts/pre-commit.sh .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
