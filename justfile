check:
    swift run swl ci check

cheap:
    swift run swl ci cheap

release:
    swift run swl ci release

generate-protocols:
    swift run swl protocols generate

verify-protocols:
    swift run swl protocols verify-generated

doctor:
    swift run swl tools doctor

bootstrap:
    swift run swl bootstrap check

nix-check:
    nix develop -c swift run swl ci check

nix-cheap:
    nix develop -c swift run swl ci cheap
