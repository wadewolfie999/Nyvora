from __future__ import annotations

import json
import os
import sqlite3
import sys
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from importlib.metadata import version
from pathlib import Path
from typing import Any, TypedDict

from langgraph.checkpoint.sqlite import SqliteSaver
from langgraph.graph import END, START, StateGraph


CONTROLLER_URL = os.environ.get("CONTROLLER_URL", "http://127.0.0.1:8080").rstrip("/")
LISTEN_ADDR = os.environ.get("LISTEN_ADDR", "0.0.0.0:8081")
CHECKPOINT_PATH = Path(os.environ.get("CHECKPOINT_PATH", "/state/checkpoints.sqlite"))
RUNTIME_MODE = os.environ.get("NODE_CONTROL_RUNTIME", "live")
if RUNTIME_MODE not in {"live", "tracer"}:
    raise RuntimeError("NODE_CONTROL_RUNTIME must be 'live' or 'tracer'")


def load_controller_token() -> str | None:
    path = os.environ.get("CONTROLLER_TOKEN_FILE", "")
    if RUNTIME_MODE == "tracer" and not path:
        return None
    if not path:
        raise RuntimeError("CONTROLLER_TOKEN_FILE is required in live mode")
    token = Path(path).read_text().strip()
    if len(token) < 32 or any(character.isspace() for character in token):
        raise RuntimeError("CONTROLLER_TOKEN_FILE must contain exactly one token of at least 32 bytes")
    return token


CONTROLLER_TOKEN = load_controller_token()
CHECKPOINT_PATH.parent.mkdir(parents=True, exist_ok=True)


class DispatchState(TypedDict, total=False):
    target: str
    idempotency_key: str
    operation_id: str
    operation: dict[str, Any]


def controller_request(method: str, path: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
    body = None if payload is None else json.dumps(payload).encode()
    headers = {"Content-Type": "application/json"} if body is not None else {}
    if CONTROLLER_TOKEN is not None:
        headers["Authorization"] = f"Bearer {CONTROLLER_TOKEN}"
    request = urllib.request.Request(
        CONTROLLER_URL + path,
        data=body,
        method=method,
        headers=headers,
    )
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.load(response)


def plan_operation(state: DispatchState) -> DispatchState:
    operation = controller_request(
        "POST",
        "/api/v1alpha1/operations/plan",
        {
            "target": state["target"],
            "action": "observe",
            "idempotency_key": state["idempotency_key"],
        },
    )
    return {"operation_id": operation["id"], "operation": operation}


def apply_operation(state: DispatchState) -> DispatchState:
    operation = controller_request(
        "POST", f"/api/v1alpha1/operations/{state['operation_id']}/apply"
    )
    return {"operation": operation}


def wait_for_result(state: DispatchState) -> DispatchState:
    deadline = time.monotonic() + 15
    operation: dict[str, Any] = state["operation"]
    while time.monotonic() < deadline:
        operation = controller_request(
            "GET", f"/api/v1alpha1/operations/{state['operation_id']}"
        )
        if operation["state"] in {"verified", "failed"}:
            return {"operation": operation}
        time.sleep(0.25)
    raise TimeoutError("controller operation did not complete")


builder = StateGraph(DispatchState)
builder.add_node("plan", plan_operation)
builder.add_node("apply", apply_operation)
builder.add_node("wait", wait_for_result)
builder.add_edge(START, "plan")
builder.add_edge("plan", "apply")
builder.add_edge("apply", "wait")
builder.add_edge("wait", END)

connection = sqlite3.connect(CHECKPOINT_PATH, check_same_thread=False)
checkpointer = SqliteSaver(connection)
graph = builder.compile(checkpointer=checkpointer)
graph_lock = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    server_version = "NodeControlLangGraph/0.1"

    def do_GET(self) -> None:
        if self.path != "/healthz":
            self.send_error(404)
            return
        self.write_json(
            200,
            {
                "status": "ok",
                "langgraph_version": version("langgraph"),
                "checkpoint": "sqlite",
                "runtime": RUNTIME_MODE,
            },
        )

    def do_POST(self) -> None:
        if self.path != "/dispatch":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 1_048_576:
                raise ValueError("invalid request length")
            payload = json.loads(self.rfile.read(length))
            target = payload["target"]
            key = payload["idempotency_key"]
            if not isinstance(target, str) or not isinstance(key, str) or len(key) < 8:
                raise ValueError("target and idempotency_key are required")
            with graph_lock:
                result = graph.invoke(
                    {"target": target, "idempotency_key": key},
                    config={"configurable": {"thread_id": key}},
                )
            self.write_json(200, result["operation"])
        except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
            self.write_json(400, {"error": str(error)})
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")
            self.write_json(error.code, {"error": detail})
        except Exception as error:  # boundary converts failures to explicit workflow evidence
            self.write_json(502, {"error": f"workflow failed: {error}"})

    def write_json(self, status: int, payload: dict[str, Any]) -> None:
        encoded = json.dumps(payload, sort_keys=True).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, format: str, *args: object) -> None:
        print(json.dumps({"component": "langgraph", "message": format % args}))


def main() -> None:
    if sys.argv[1:] == ["--healthcheck"]:
        with urllib.request.urlopen(f"http://127.0.0.1:{LISTEN_ADDR.rsplit(':', 1)[1]}/healthz", timeout=3) as response:
            if response.status != 200:
                raise RuntimeError(f"workflow health returned HTTP {response.status}")
        return
    if sys.argv[1:]:
        raise RuntimeError("unsupported arguments")
    host, port = LISTEN_ADDR.rsplit(":", 1)
    server = ThreadingHTTPServer((host, int(port)), Handler)
    print(json.dumps({"component": "langgraph", "listen": LISTEN_ADDR}))
    server.serve_forever()


if __name__ == "__main__":
    main()
