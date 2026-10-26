import json
import os
import signal
import socket
import stat
import sys
import threading
import time


def record(text):
    path = os.environ.get("WCK_EVENTS")
    if path:
        with open(path, "a") as output:
            output.write(text + "\n")


def ready(path):
    with open(path, "w") as output:
        output.write(str(os.getpid()))


def wait_forever():
    while True:
        signal.pause()


def weston():
    runtime = os.environ["XDG_RUNTIME_DIR"]
    mode = os.environ.get("WCK_WESTON_MODE", "ready")
    record("runtime=" + runtime)
    record("permissions=" + oct(stat.S_IMODE(os.stat(runtime).st_mode)))
    record("weston-pid=" + str(os.getpid()))

    def stop(signum, frame):
        child_alive = False
        path = os.environ["WCK_EVENTS"] + ".child"
        if os.path.exists(path):
            with open(path) as source:
                pid = int(source.read())
            try:
                os.kill(pid, 0)
                child_alive = True
            except ProcessLookupError:
                pass
        record("weston-stop child-alive=" + str(int(child_alive)))
        record("runtime-at-weston-stop=" + str(int(os.path.isdir(runtime))))
        print("late weston diagnostic", flush=True)
        if mode != "resistant":
            sys.exit(0)

    signal.signal(signal.SIGTERM, stop)
    record("weston-started")
    if mode == "early":
        print("early weston diagnostic", flush=True)
        sys.exit(23)
    address = os.path.join(runtime, os.environ["WAYLAND_DISPLAY"])
    if mode == "nonsocket":
        with open(address, "w") as output:
            output.write("not a socket")
    elif mode != "never":
        listener = socket.socket(socket.AF_UNIX)
        listener.bind(address)
        listener.listen(1)
    wait_forever()


def child():
    mode = os.environ.get("WCK_CHILD_MODE", "success")
    record("child-pid=" + str(os.getpid()))
    record("child-cwd=" + os.getcwd())
    record("child-wayland-socket=" + str("WAYLAND_SOCKET" in os.environ))
    record("child-args=" + json.dumps(sys.argv[1:]))

    def stop(signum, frame):
        record("child-stop")
        record("runtime-at-child-stop=" + str(int(os.path.isdir(os.environ["XDG_RUNTIME_DIR"]))))
        print("late child diagnostic", flush=True)
        if mode == "delayed":
            time.sleep(0.3)
        if mode != "resistant":
            sys.exit(0)

    signal.signal(signal.SIGTERM, stop)
    ready(os.environ["WCK_EVENTS"] + ".child")
    record("child-started")
    if mode == "success":
        sys.exit(0)
    if mode == "failure":
        print("child stdout diagnostic", flush=True)
        print("child stderr diagnostic", file=sys.stderr, flush=True)
        sys.exit(7)
    wait_forever()


def process():
    mode = sys.argv[1]
    if mode == "report":
        info = os.fstat(0)
        print(json.dumps({"environment": dict(os.environ), "cwd": os.getcwd(),
                          "stdinDevice": info.st_dev, "stdinInode": info.st_ino}))
    elif mode == "streams":
        count = int(sys.argv[2])
        def emit(fd, byte):
            data = byte * 8192
            for _ in range(count // len(data)):
                os.write(fd, data)
        writer = threading.Thread(target=emit, args=(2, b"e"))
        writer.start()
        emit(1, b"o")
        writer.join()
    elif mode == "invalid":
        os.write(1, b"valid-prefix\xff")
        os.write(2, b"valid-error\xfe")
    elif mode == "signal":
        os.kill(os.getpid(), signal.SIGTERM)
    elif mode == "wait":
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        ready(sys.argv[2])
        wait_forever()
    elif mode == "read-stdin":
        sys.stdout.buffer.write(sys.stdin.buffer.read())
    elif mode == "exit":
        print("visible-output", flush=True)
        print("visible-error", file=sys.stderr, flush=True)
        sys.exit(int(sys.argv[2]))


name = os.path.basename(sys.argv[0])
if name == "weston":
    weston()
elif name in ("child", "swift"):
    child()
else:
    process()
