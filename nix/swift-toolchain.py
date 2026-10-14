"""Set up the selected Swift compiler's SDK and tool wrappers for nix develop."""

import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys


def version_tuple(text):
    match = re.search(r"^Swift version (\d+)\.(\d+)(?:\.(\d+))?(?:\s|$)", text, re.MULTILINE)
    if not match:
        raise ValueError(f"could not parse Swift version: {text.strip()}")
    return tuple(int(value or 0) for value in match.groups())


def write_text(path, value):
    if not path.exists() or path.read_text() != value:
        path.write_text(value)


def write_json(path, value):
    write_text(path, json.dumps(value, indent=2) + "\n")


def main():
    config = json.loads(Path(sys.argv[1]).read_text())
    environment = dict(os.environ)
    selected = environment.get("SWIFT_BIN")
    if selected == environment.get("WAYLAND_CLIENT_KIT_WRAPPED_SWIFT"):
        selected = environment.get("WAYLAND_CLIENT_KIT_REAL_SWIFT")
    if not selected:
        home = Path(environment.get("SWIFTLY_HOME_DIR", environment.get(
            "SWIFTLY_HOME", str(Path.home() / ".local/share/swiftly"))))
        swiftly = home / "toolchains" / config["minimumVersion"] / "usr/bin/swift"
        selected = str(swiftly) if swiftly.is_file() else shutil.which("swift")
    if not selected:
        raise ValueError(f"install Swift {config['minimumVersion']} with Swiftly or set SWIFT_BIN")
    executable = Path(shutil.which(selected) or selected).absolute()
    if not executable.is_file() or not os.access(executable, os.X_OK):
        raise ValueError(f"SWIFT_BIN is not executable: {executable}")
    toolchain = executable.parent
    required = ["swiftc", "swift-frontend", "clang", "clang++", "swift-format",
                "swift-symbolgraph-extract", "swift-package", "swift-build-tool"]
    for name in required:
        if not (toolchain / name).is_file():
            raise ValueError(f"selected Swift toolchain is missing {toolchain / name}")

    identity = hashlib.sha256(
        json.dumps(config, sort_keys=True).encode() + str(executable).encode()
        + str((toolchain / "swift-frontend").stat().st_mtime_ns).encode()
        + Path(__file__).read_bytes()).hexdigest()[:20]
    cache = Path(environment.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
    root = cache / "waylandclientkit/swift-sdk" / identity
    root.mkdir(parents=True, exist_ok=True)
    lock = (root / ".lock").open("a")
    fcntl.flock(lock, fcntl.LOCK_EX)
    wrappers = root / "usr/bin"
    wrappers.mkdir(parents=True, exist_ok=True)
    sysroot = root / "sysroot"
    (sysroot / "usr/lib").mkdir(parents=True, exist_ok=True)
    headers = sysroot / "usr/include"
    if not headers.is_symlink():
        headers.symlink_to(config["libcHeaders"])
    libc_directory = sysroot / "lib"
    if not libc_directory.is_symlink():
        libc_directory.symlink_to("usr/lib")
    store = sysroot / config["nixStore"].lstrip("/")
    store.parent.mkdir(parents=True, exist_ok=True)
    if not store.is_symlink():
        store.symlink_to(config["nixStore"])
    for library_root in config["libcLibraryPaths"]:
        for source in Path(library_root).iterdir():
            destination = sysroot / "usr/lib" / source.name
            if not destination.exists() and not destination.is_symlink():
                destination.symlink_to(source)

    # Set the loader's search path per tool, leaving the child environment unchanged.
    # Swift's multicall tools need their original argv[0] and selected frontend.
    def invocation(name):
        binary = toolchain / name
        return [config["dynamicLinker"], "--library-path", config["runtimeLibraryPath"],
                "--argv0", str(binary), str(binary)]

    def wrapper(name, extra=(), prefix=""):
        command = shlex.join(invocation(name) + list(extra))
        destination = wrappers / name
        write_text(destination, f"#!{config['bash']}\nset -e\n{prefix}exec {command} \"$@\"\n")
        destination.chmod(0o755)

    original_resources = toolchain.parent / "lib/swift"
    resource_hint = root / "resources"
    resource_hint.mkdir(exist_ok=True)
    for source in original_resources.iterdir():
        destination = resource_hint / source.name
        if source.name != "linux" and not destination.is_symlink():
            destination.symlink_to(source)
    linux_resources = resource_hint / "linux"
    linux_resources.mkdir(exist_ok=True)
    # Swift runtime libraries resolve $ORIGIN-relative dependencies through their RUNPATHs.
    # Put symlinks to their Nix dependencies alongside the libraries.
    for library_root in [str(original_resources / "linux")] + config["librarySearchPaths"]:
        directory = Path(library_root)
        if not directory.is_dir():
            continue
        for source in directory.iterdir():
            destination = linux_resources / source.name
            if not destination.exists() and not destination.is_symlink():
                destination.symlink_to(source)
    swift_resources = sysroot / "usr/lib/swift"
    if not swift_resources.is_symlink():
        swift_resources.symlink_to(resource_hint)
    scanner = original_resources / "host/lib_InternalSwiftScan.so"
    if not scanner.is_file():
        raise ValueError(f"selected Swift toolchain is missing {scanner}")
    scanner_environment = f"export SWIFT_DRIVER_SWIFTSCAN_LIB={shlex.quote(str(scanner))}\n"
    frontend_modes = (
        'if [ "${1:-}" = -frontend ]; then shift; fi\n'
        'case "${1:-}" in\n'
        '  -modulewrap|-emit-supported-features) exec '
        + shlex.join(invocation("swift-frontend")) + ' "$@" ;;\nesac\n')
    wrapper("swift-frontend", ["-frontend", "-resource-dir", str(resource_hint)], frontend_modes)
    compiler_environment = scanner_environment + (
        'if [ "${1:-}" = -frontend ]; then shift; exec '
        + shlex.quote(str(wrappers / "swift-frontend")) + ' "$@"; fi\n')
    compiler_flags = ["-driver-use-frontend-path", str(wrappers / "swift-frontend"),
                      "-resource-dir", str(resource_hint), "-sdk", str(sysroot)]
    for path in config["librarySearchPaths"]:
        compiler_flags += ["-L", path]
    compiler_flags += ["-Xclang-linker", f"--gcc-toolchain={config['gccRoot']}",
                       "-Xlinker", "--disable-new-dtags",
                       "-Xlinker", "--dynamic-linker", "-Xlinker", config["dynamicLinker"],
                       "-Xlinker", "-rpath", "-Xlinker", config["runtimeLibraryPath"]]
    wrapper("swiftc", compiler_flags, compiler_environment)
    clang_resources = sorted((toolchain.parent / "lib/clang").iterdir())
    if len(clang_resources) != 1:
        raise ValueError(f"expected one selected Clang resource directory: {clang_resources}")
    clang_flags = [f"--gcc-toolchain={config['gccRoot']}", "--sysroot", str(sysroot),
                   "-resource-dir", str(clang_resources[0])]
    wrapper("clang", clang_flags)
    wrapper("clang++", clang_flags)
    probe_environment = dict(environment, PATH=f"{wrappers}:{toolchain}:{environment.get('PATH', '')}")
    probe_environment.pop("LD_LIBRARY_PATH", None)
    probe_environment.pop("SDKROOT", None)
    probe_environment["SWIFT_EXEC"] = str(wrappers / "swiftc")
    version = subprocess.check_output([str(wrappers / "swiftc"), "--version"],
                                      env=probe_environment, text=True)
    actual_version = version_tuple(version)
    minimum_version = tuple(map(int, config["minimumVersion"].split(".")))
    if actual_version < minimum_version or actual_version[0] >= 100:
        raise ValueError(f"Swift {'.'.join(map(str, actual_version))} is too old; requires {config['minimumVersion']}")
    info = json.loads(subprocess.check_output([str(wrappers / "swiftc"), "-print-target-info"],
                                             env=probe_environment, text=True))
    triple = info["target"]["unversionedTriple"]
    arch = info["target"]["arch"]
    if triple != config["targetTriple"]:
        raise ValueError(f"selected Swift targets {triple}, but Nix SDK targets {config['targetTriple']}")
    resources = Path(info["paths"]["runtimeResourcePath"])
    for name in ["glibc.modulemap", "swiftrt.o"]:
        if not (resources / "linux" / arch / name).is_file():
            raise ValueError(f"selected Swift toolchain is missing {resources / 'linux' / arch / name}")
    libraries = root / "usr/lib"
    libraries.mkdir(exist_ok=True)
    for source in (toolchain.parent / "lib").iterdir():
        destination = libraries / source.name
        if not destination.is_symlink():
            destination.symlink_to(resources if source.name == "swift" else source)
    # Swift Build reads compiler capability records relative to usr/bin.
    for name in ["share", "include", "libexec", "local"]:
        source = toolchain.parent / name
        destination = root / "usr" / name
        if source.is_dir() and not destination.is_symlink():
            destination.symlink_to(source)
    for name in ["swift-format", "swift-build-tool", "swift-autolink-extract", "swift-plugin-server",
                 "llvm-ar", "llvm-ranlib", "llvm-cov", "llvm-profdata", "llvm-symbolizer", "docc"]:
        if (toolchain / name).is_file():
            wrapper(name)
    wrapper("swift-symbolgraph-extract", ["-sdk", str(sysroot), "-resource-dir", str(resources)])

    sdks = root / "sdks"
    bundle = sdks / "waylandclientkit.artifactbundle"
    sdk = bundle / "sdk"
    sdk.mkdir(parents=True, exist_ok=True)
    identifier = "waylandclientkit-nix"
    write_json(bundle / "info.json", {
        "schemaVersion": "1.0", "artifacts": {identifier: {
            "type": "swiftSDK", "version": ".".join(map(str, actual_version)),
            "variants": [{"path": "sdk", "supportedTriples": [triple]}]}}})
    write_json(sdk / "swift-sdk.json", {
        "schemaVersion": "4.0", "targetTriples": {triple: {
            "sdkRootPath": str(sysroot), "swiftResourcesPath": str(resources),
            "swiftStaticResourcesPath": str(original_resources.parent / "swift_static"),
            "includeSearchPaths": config["includeSearchPaths"],
            "librarySearchPaths": config["librarySearchPaths"],
            "toolsetPaths": ["toolset.json"]}}})
    write_json(sdk / "toolset.json", {
        "schemaVersion": "1.0", "rootPath": str(wrappers),
        "linker": {"path": config["linker"], "extraCLIOptions": [
            "--disable-new-dtags",
            "-rpath-link", config["runtimeLibraryPath"],
            "-rpath", config["runtimeLibraryPath"],
            "--dynamic-linker", config["dynamicLinker"]]},
        "cCompiler": {"path": str(wrappers / "clang")},
        "cxxCompiler": {"path": str(wrappers / "clang++")},
        "swiftCompiler": {"path": str(wrappers / "swiftc"), "extraCLIOptions": [
            "-Xcc", f"--gcc-toolchain={config['gccRoot']}",
            "-Xclang-linker", f"--gcc-toolchain={config['gccRoot']}"]}})

    sdk_flags = shlex.join(["--toolchain", str(root), "--swift-sdks-path", str(sdks),
                            "--swift-sdk", identifier])
    # Call SwiftPM directly to avoid the driver's toolchain lookup.
    swift = wrappers / "swift"
    dispatch = []
    for name in ["build", "run", "test", "package"]:
        # Swift Build calls /usr/bin/touch for resource bundles. Bind Nix coreutils
        # there in the child mount namespace only.
        command = shlex.join([
            config["bubblewrap"], "--bind", "/", "/", "--dev-bind", "/dev", "/dev",
            "--proc", "/proc", "--ro-bind", "/sys", "/sys",
            "--ro-bind", config["hostTools"], "/usr/bin", "--"]
            + invocation(f"swift-{name}"))
        dispatch.append(f"  {name}) shift; exec {command} {sdk_flags} \"$@\" ;;\n")
    for name in ["sdk", "experimental-sdk", "help", "format", "package-collection", "package-registry"]:
        if (toolchain / f"swift-{name}").is_file():
            command = shlex.join(invocation(f"swift-{name}"))
            dispatch.append(f"  {name}) shift; exec {command} \"$@\" ;;\n")
    write_text(swift, f"#!{config['bash']}\nset -e\n{compiler_environment}case \"${{1:-}}\" in\n"
               + "".join(dispatch) + "esac\nexec "
               + shlex.join(invocation("swift") + compiler_flags) + ' "$@"\n')
    swift.chmod(0o755)
    exports = {
        "SWIFT_BIN": str(swift), "WAYLAND_CLIENT_KIT_WRAPPED_SWIFT": str(swift),
        "WAYLAND_CLIENT_KIT_REAL_SWIFT": str(executable),
        "SWIFT_EXEC": str(wrappers / "swiftc"), "CC": str(wrappers / "clang"),
        "CXX": str(wrappers / "clang++"), "SWIFT_FORMAT_BIN": str(wrappers / "swift-format"),
        "SWIFT_SYMBOLGRAPH_EXTRACT": str(wrappers / "swift-symbolgraph-extract"),
        "WAYLAND_CLIENT_KIT_SWIFT_SDKS": str(sdks), "WAYLAND_CLIENT_KIT_SWIFT_SDK": identifier,
        "WAYLAND_CLIENT_KIT_SWIFT_SYSROOT": str(sysroot),
        "WAYLAND_CLIENT_KIT_SWIFT_TOOL_LOADER": config["dynamicLinker"],
        "WAYLAND_CLIENT_KIT_SWIFT_TOOL_LIBRARIES":
            f"{config['runtimeLibraryPath']}:{libraries}:{linux_resources}",
        "LINUX_SOURCEKIT_LIB": str(toolchain.parent / "lib"),
        "PATH": f"{wrappers}:{environment.get('PATH', '')}",
    }
    print("unset SDKROOT LD_LIBRARY_PATH")
    for name, value in exports.items():
        print(f"export {name}={shlex.quote(value)}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"error: WaylandClientKit Swift toolchain: {error}", file=sys.stderr)
        sys.exit(1)
