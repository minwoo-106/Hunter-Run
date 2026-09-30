"""Run a CI utility with a deadline so stalled CoreSimulator cannot wait forever."""
import argparse, os, signal, subprocess, sys

parser = argparse.ArgumentParser()
parser.add_argument("--timeout", type=float, required=True)
parser.add_argument("command", nargs=argparse.REMAINDER)
args = parser.parse_args()
command = args.command[1:] if args.command[:1] == ["--"] else args.command
if not command or args.timeout <= 0:
    parser.error("A command and a positive timeout are required")
process = subprocess.Popen(command, start_new_session=True)
try:
    sys.exit(process.wait(timeout=args.timeout))
except subprocess.TimeoutExpired:
    print(f"CI utility exceeded {args.timeout:g}s: {command[0]}", file=sys.stderr, flush=True)
    if os.name == "posix":
        os.killpg(process.pid, signal.SIGTERM)
    else:
        process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        if os.name == "posix":
            os.killpg(process.pid, signal.SIGKILL)
        else:
            process.kill()
        process.wait()
    sys.exit(124)
