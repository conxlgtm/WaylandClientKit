check:
    swift run wck ci check

cheap:
    swift run wck ci cheap

release:
    swift run wck ci release

examples:
    swift run wck examples build

toolchain:
    swift run wck tools toolchain-smoke

evidence:
    swift run wck compositor evidence-summary

generate-protocols:
    swift run wck protocols generate

verify-protocols:
    swift run wck protocols verify-generated

generate-identities:
    swift run wck identity generate

verify-identities:
    swift run wck identity verify-generated

doctor:
    swift run wck tools doctor

bootstrap:
    swift run wck bootstrap check

swiftlint-tool:
    swift run wck tools install-swiftlint --destination .build/tools

nix-check:
    nix develop -c swift run wck ci check

nix-cheap:
    nix develop -c swift run wck ci cheap
