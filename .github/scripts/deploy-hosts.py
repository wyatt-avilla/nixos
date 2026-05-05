#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import hmac
import json
import os
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any


HOSTS = ("vps", "homelab")
TERMINAL_STATES = {"success", "failure", "error"}
VALID_STATES = {"queued", "in_progress", "success", "failure", "error"}


def require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"{name} is required")
    return value


def json_bytes(payload: dict[str, Any]) -> bytes:
    return json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()


def truncate_description(description: str) -> str:
    description = " ".join(description.split()) or "Deployment status updated."
    if len(description) <= 140:
        return description
    return f"{description[:137]}..."


@dataclass(frozen=True)
class Deployment:
    host: str
    environment: str
    deployment_id: int


class DeployClient:
    def __init__(self) -> None:
        self.repository = require_env("GITHUB_REPOSITORY")
        self.ref = require_env("GITHUB_REF")
        self.sha = require_env("GITHUB_SHA")
        self.run_id = require_env("GITHUB_RUN_ID")
        self.github_token = require_env("GITHUB_TOKEN")
        self.webhook_secret = require_env("DEPLOY_WEBHOOK_SECRET").encode()
        self.start_url = require_env("DEPLOY_WEBHOOK_START_URL")
        self.status_url = require_env("DEPLOY_WEBHOOK_STATUS_URL")
        self.api_url = os.environ.get(
            "GITHUB_API_URL",
            "https://api.github.com",
        )
        self.run_url = (
            f"https://github.com/{self.repository}/actions/runs/{self.run_id}"
        )
        self.poll_seconds = int(os.environ.get("DEPLOY_POLL_SECONDS", "15"))
        self.timeout_seconds = int(
            os.environ.get("DEPLOY_TIMEOUT_SECONDS", "7800")
        )
        self.last_posted: dict[str, tuple[str, str]] = {}

    def github_request(
        self, method: str, path: str, payload: dict[str, Any]
    ) -> Any:
        body = json.dumps(payload).encode()
        request = urllib.request.Request(
            f"{self.api_url}{path}",
            data=body,
            method=method,
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {self.github_token}",
                "Content-Type": "application/json",
                "User-Agent": "nixos-deploy-action",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                raw = response.read().decode()
        except urllib.error.HTTPError as error:
            raw = error.read().decode(errors="replace")
            raise RuntimeError(
                f"{method} {path} failed with HTTP {error.code}: {raw}"
            ) from error
        return json.loads(raw) if raw else {}

    def signed_webhook_request(
        self, url: str, payload: dict[str, Any], timeout: int = 30
    ) -> str:
        body = json_bytes(payload)
        signature = hmac.new(
            self.webhook_secret,
            body,
            hashlib.sha256,
        ).hexdigest()
        request = urllib.request.Request(
            url,
            data=body,
            method="POST",
            headers={
                "Content-Type": "application/json",
                "User-Agent": "nixos-deploy-action",
                "X-Hub-Signature-256": f"sha256={signature}",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return response.read().decode()
        except urllib.error.HTTPError as error:
            raw = error.read().decode(errors="replace")
            raise RuntimeError(
                f"webhook {url} failed with HTTP {error.code}: {raw}"
            ) from error

    def create_deployment(self, host: str) -> Deployment:
        environment = f"production-{host}"
        response = self.github_request(
            "POST",
            f"/repos/{self.repository}/deployments",
            {
                "ref": self.sha,
                "environment": environment,
                "description": f"Deploy {host} from {self.sha[:7]}.",
                "auto_merge": False,
                "required_contexts": [],
                "production_environment": True,
                "transient_environment": False,
                "payload": {
                    "host": host,
                    "run_id": self.run_id,
                },
            },
        )
        deployment = Deployment(
            host=host,
            environment=environment,
            deployment_id=int(response["id"]),
        )
        self.post_status(deployment, "queued", f"{host} deploy queued.")
        return deployment

    def post_status(
        self, deployment: Deployment, state: str, description: str
    ) -> None:
        if state not in VALID_STATES:
            raise RuntimeError(
                f"invalid deployment state for {deployment.host}: {state}"
            )

        description = truncate_description(description)
        posted = (state, description)
        if self.last_posted.get(deployment.host) == posted:
            return

        payload = {
            "state": state,
            "environment": deployment.environment,
            "description": description,
            "log_url": self.run_url,
        }
        if state == "success":
            payload["auto_inactive"] = True

        self.github_request(
            "POST",
            (
                f"/repos/{self.repository}/deployments/"
                f"{deployment.deployment_id}/statuses"
            ),
            payload,
        )
        self.last_posted[deployment.host] = posted
        print(f"{deployment.host}: {state} - {description}")

    def trigger_deploy(self) -> None:
        self.signed_webhook_request(
            self.start_url,
            {
                "repository": self.repository,
                "ref": self.ref,
                "sha": self.sha,
                "run_id": self.run_id,
                "target": "all",
            },
        )

    def fetch_status(self) -> dict[str, Any]:
        raw = self.signed_webhook_request(
            self.status_url,
            {
                "repository": self.repository,
                "ref": self.ref,
                "run_id": self.run_id,
            },
        )
        return json.loads(raw)

    def apply_statuses(
        self, deployments: dict[str, Deployment], status: dict[str, Any]
    ) -> dict[str, str]:
        if str(status.get("run_id")) != self.run_id:
            raise RuntimeError(
                f"status returned run_id {status.get('run_id')!r}"
            )
        if status.get("sha") and status["sha"] != self.sha:
            raise RuntimeError(f"status returned sha {status.get('sha')!r}")

        host_statuses = status.get("hosts")
        if not isinstance(host_statuses, dict):
            raise RuntimeError("status response is missing hosts")

        states: dict[str, str] = {}
        for host in HOSTS:
            host_status = host_statuses.get(host)
            if not isinstance(host_status, dict):
                continue

            state = host_status.get("state")
            if state not in VALID_STATES:
                raise RuntimeError(f"{host} returned invalid state {state!r}")

            description = str(
                host_status.get("description") or f"{host} is {state}."
            )
            self.post_status(deployments[host], state, description)
            states[host] = state

        return states

    def mark_error(
        self,
        deployments: dict[str, Deployment],
        states: dict[str, str],
        message: str,
    ) -> None:
        for host, deployment in deployments.items():
            if states.get(host) not in TERMINAL_STATES:
                self.post_status(deployment, "error", message)

    def run(self) -> int:
        deployments: dict[str, Deployment] = {}
        states: dict[str, str] = {host: "queued" for host in HOSTS}

        try:
            for host in HOSTS:
                deployments[host] = self.create_deployment(host)

            self.trigger_deploy()

            deadline = time.monotonic() + self.timeout_seconds
            while time.monotonic() < deadline:
                try:
                    states.update(
                        self.apply_statuses(deployments, self.fetch_status())
                    )
                    if all(
                        states.get(host) in TERMINAL_STATES for host in HOSTS
                    ):
                        break
                except Exception as error:
                    print(f"status poll failed: {error}", file=sys.stderr)

                remaining = max(0, deadline - time.monotonic())
                time.sleep(min(self.poll_seconds, remaining))
            else:
                self.mark_error(
                    deployments,
                    states,
                    "Timed out waiting for host deployment status.",
                )
                return 1

            return (
                0
                if all(states.get(host) == "success" for host in HOSTS)
                else 1
            )
        except Exception as error:
            print(f"deployment failed: {error}", file=sys.stderr)
            self.mark_error(deployments, states, str(error))
            return 1


def main() -> int:
    return DeployClient().run()


if __name__ == "__main__":
    raise SystemExit(main())
