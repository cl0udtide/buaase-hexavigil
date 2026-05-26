#!/usr/bin/env python3
"""Sync Beta issue estimates and draw archived Beta burndown charts."""

from __future__ import annotations

import argparse
import datetime as dt
import http.client
import json
import math
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_REPO = "Cl0udTide/BUAASE-HexaVigil"
ESTIMATE_RE = re.compile(r"^estimate:(\d+)$", re.IGNORECASE)

LOCAL_PACKAGES = Path(".local/python-packages")
if LOCAL_PACKAGES.exists():
    sys.path.insert(0, str(LOCAL_PACKAGES.resolve()))


@dataclass
class Issue:
    number: int
    title: str
    body: str
    state: str
    created_at: dt.datetime
    closed_at: dt.datetime | None
    labels: list[str]
    milestone_number: int | None


class GitHubClient:
    def __init__(self, repo: str, token: str | None) -> None:
        self.repo = repo
        self.base_url = f"https://api.github.com/repos/{repo}"
        self.token = token

    def request(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
        params: dict[str, Any] | None = None,
    ) -> Any:
        url = self.base_url + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        data = json.dumps(payload).encode("utf-8") if payload is not None else None
        headers = {
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "hexavigil-beta-burndown",
        }
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"

        last_error: Exception | None = None
        for _ in range(3):
            request = urllib.request.Request(url, data=data, headers=headers, method=method)
            try:
                with urllib.request.urlopen(request, timeout=30) as response:
                    if response.status == 204:
                        return None
                    return json.loads(response.read().decode("utf-8"))
            except urllib.error.HTTPError as exc:
                details = exc.read().decode("utf-8", errors="replace")
                raise RuntimeError(f"GitHub API {method} {url} failed: {exc.code} {details}") from exc
            except (http.client.IncompleteRead, TimeoutError, urllib.error.URLError) as exc:
                last_error = exc
        raise RuntimeError(f"GitHub API {method} {url} failed after retries: {last_error}")

    def paged(self, path: str, params: dict[str, Any] | None = None) -> list[Any]:
        page = 1
        items: list[Any] = []
        while True:
            page_params = {"per_page": 100, "page": page}
            if params:
                page_params.update(params)
            batch = self.request("GET", path, params=page_params)
            if not batch:
                return items
            items.extend(batch)
            if len(batch) < 100:
                return items
            page += 1


def parse_datetime(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def parse_date(value: str) -> dt.date:
    return dt.date.fromisoformat(value)


def get_token() -> str | None:
    for name in ("GITHUB_TOKEN", "GH_TOKEN"):
        if os.environ.get(name):
            return os.environ[name]
    try:
        completed = subprocess.run(
            ["gh", "auth", "token"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return None
    token = completed.stdout.strip()
    return token or None


def label_names(raw_labels: list[dict[str, Any]]) -> list[str]:
    return [str(label["name"]) for label in raw_labels]


def to_issue(raw: dict[str, Any]) -> Issue:
    milestone = raw.get("milestone")
    return Issue(
        number=int(raw["number"]),
        title=str(raw.get("title") or ""),
        body=str(raw.get("body") or ""),
        state=str(raw.get("state") or ""),
        created_at=parse_datetime(raw["created_at"]) or dt.datetime.min.replace(tzinfo=dt.timezone.utc),
        closed_at=parse_datetime(raw.get("closed_at")),
        labels=label_names(raw.get("labels") or []),
        milestone_number=int(milestone["number"]) if milestone else None,
    )


def issue_estimate(issue: Issue) -> int | None:
    for label in issue.labels:
        match = ESTIMATE_RE.match(label)
        if match:
            return int(match.group(1))
    return None


def heuristic_weight(issue: Issue) -> int:
    text = f"{issue.title}\n{issue.body}".lower()
    weight = 6
    keyword_weights = [
        (("architecture", "framework", "scaffold", "initialize"), 12),
        (("combat", "skill", "enemy", "boss", "unit"), 12),
        (("map", "path", "spawn"), 10),
        (("ui", "hud", "panel", "layout"), 8),
        (("data", "json", "schema", "config"), 7),
        (("ci", "export", "build", "workflow"), 6),
        (("bug", "fix", "error", "issue"), 5),
        (("docs", "readme", "document"), 4),
        (("test", "verify", "qa"), 5),
        (("art", "asset", "sprite", "effect", "visual"), 6),
    ]
    for keywords, candidate in keyword_weights:
        if any(keyword in text for keyword in keywords):
            weight = max(weight, candidate)
    if any(marker in text for marker in ("refactor", "complete", "core")):
        weight += 2
    if any(marker in text for marker in ("minor", "polish", "cleanup")):
        weight -= 1
    return max(2, min(weight, 15))


def post_initial_estimate(issue: Issue) -> int:
    text = f"{issue.title}\n{issue.body}".lower()
    if any(marker in text for marker in ("fix", "bug", "regression", "qa")):
        return 2
    if any(marker in text for marker in ("ui", "display", "layout", "asset remediation")):
        return 3
    if any(marker in text for marker in ("art", "effect", "lighting", "transition", "integration")):
        return 4
    if any(marker in text for marker in ("system", "pipeline", "prototype", "environment")):
        return 5
    return 3


def normalized_initial_estimates(issues: list[Issue], total: int) -> dict[int, int]:
    if not issues:
        return {}
    weights = {issue.number: heuristic_weight(issue) for issue in issues}
    weight_total = sum(weights.values())
    exact = {number: weights[number] * total / weight_total for number in weights}
    estimates = {number: max(1, int(math.floor(value))) for number, value in exact.items()}
    delta = total - sum(estimates.values())
    order = sorted(weights, key=lambda number: exact[number] - math.floor(exact[number]), reverse=True)
    while delta > 0:
        for number in order:
            if delta == 0:
                break
            estimates[number] += 1
            delta -= 1
    while delta < 0:
        for number in reversed(order):
            if delta == 0:
                break
            if estimates[number] > 1:
                estimates[number] -= 1
                delta += 1
    return estimates


def find_milestone(client: GitHubClient, title: str) -> dict[str, Any]:
    milestones = client.paged("/milestones", {"state": "all"})
    lowered = title.lower()
    for milestone in milestones:
        if str(milestone.get("title", "")).lower() == lowered:
            return milestone
    for milestone in milestones:
        if lowered in str(milestone.get("title", "")).lower():
            return milestone
    raise RuntimeError(f'Could not find a milestone matching "{title}".')


def fetch_issues(client: GitHubClient) -> list[Issue]:
    raw_issues = client.paged("/issues", {"state": "all"})
    return [to_issue(raw) for raw in raw_issues if "pull_request" not in raw]


def ensure_label(client: GitHubClient, label: str, description: str) -> None:
    payload = {
        "name": label,
        "color": "1d76db",
        "description": description,
    }
    encoded = urllib.parse.quote(label, safe="")
    try:
        client.request("GET", f"/labels/{encoded}")
    except RuntimeError:
        client.request("POST", "/labels", payload)


def sync_milestone_issues(
    client: GitHubClient,
    issues: list[Issue],
    milestone_number: int,
    initial_batch_date: dt.date,
    target_total: int,
    force_estimates: bool,
    label_description: str,
) -> list[Issue]:
    milestone_issues = [
        issue
        for issue in issues
        if issue.milestone_number == milestone_number or issue.created_at.date() <= initial_batch_date
    ]
    initial_issues = [issue for issue in milestone_issues if issue.created_at.date() <= initial_batch_date]
    normalized = normalized_initial_estimates(initial_issues, target_total)

    updated: list[Issue] = []
    for issue in milestone_issues:
        current_estimate = issue_estimate(issue)
        if force_estimates or current_estimate is None:
            estimate = normalized.get(issue.number, post_initial_estimate(issue))
        else:
            estimate = current_estimate

        estimate_label = f"estimate:{estimate}"
        ensure_label(client, estimate_label, label_description)
        next_labels = [label for label in issue.labels if not ESTIMATE_RE.match(label)]
        next_labels.append(estimate_label)
        client.request(
            "PATCH",
            f"/issues/{issue.number}",
            {
                "milestone": milestone_number,
                "labels": next_labels,
            },
        )
        updated.append(
            Issue(
                number=issue.number,
                title=issue.title,
                body=issue.body,
                state=issue.state,
                created_at=issue.created_at,
                closed_at=issue.closed_at,
                labels=next_labels,
                milestone_number=milestone_number,
            )
        )
    return updated


def load_font() -> None:
    import matplotlib.pyplot as plt
    from matplotlib import font_manager

    font_path = Path("assets/fonts/SourceHanSansSC-Normal.otf")
    if font_path.exists():
        font_manager.fontManager.addfont(str(font_path))
        plt.rcParams["font.family"] = "Source Han Sans SC"
    plt.rcParams["axes.unicode_minus"] = False


def burndown_events(
    issues: list[Issue],
    start_date: dt.date,
    end_date: dt.date,
    initial_batch_date: dt.date,
    as_of_date: dt.date,
    target_total: int,
) -> tuple[list[tuple[dt.datetime, int, str]], int]:
    start = dt.datetime.combine(start_date, dt.time.min, tzinfo=dt.timezone.utc)
    end = dt.datetime.combine(end_date, dt.time.max, tzinfo=dt.timezone.utc)
    as_of_end = dt.datetime.combine(as_of_date, dt.time.max, tzinfo=dt.timezone.utc)

    events: list[tuple[dt.datetime, int, str]] = []
    for issue in issues:
        estimate = issue_estimate(issue)
        if estimate is None:
            continue
        created = issue.created_at
        closed = issue.closed_at
        if created > as_of_end:
            continue
        if created.date() <= initial_batch_date:
            events.append((start, estimate, f"#{issue.number} existing"))
        elif start < created <= min(end, as_of_end):
            events.append((created, estimate, f"#{issue.number} opened"))
        if closed and start <= closed <= min(end, as_of_end):
            events.append((closed, -estimate, f"#{issue.number} closed"))

    events.sort(key=lambda item: (item[0], item[1]))
    initial_delta = sum(delta for when, delta, _ in events if when == start)
    events = [event for event in events if event[0] != start]
    current = max(0, initial_delta)
    if current == 0 and any(issue.created_at.date() <= initial_batch_date for issue in issues):
        current = target_total
    if current == 0:
        current = target_total
    return events, current


def density_axis(
    events: list[tuple[dt.datetime, int, str]],
    start_date: dt.date,
    end_date: dt.date,
) -> tuple[dict[dt.date, float], dict[dt.date, float], dict[int, float], list[float], list[str]]:
    dates = [start_date + dt.timedelta(days=offset) for offset in range((end_date - start_date).days + 1)]
    event_counts = {day: 0 for day in dates}
    for when, _, _ in events:
        day = when.date()
        if day in event_counts:
            event_counts[day] += 1

    widths: dict[dt.date, float] = {}
    for day in dates:
        count = event_counts[day]
        widths[day] = 0.55 + min(count, 14) * 0.16
        if count == 0:
            widths[day] = 0.5

    starts: dict[dt.date, float] = {}
    cursor = 0.0
    for day in dates:
        starts[day] = cursor
        cursor += widths[day]

    event_positions: dict[int, float] = {}
    events_by_day: dict[dt.date, list[int]] = {day: [] for day in dates}
    for index, (when, _, _) in enumerate(events):
        if when.date() in events_by_day:
            events_by_day[when.date()].append(index)
    for day, indexes in events_by_day.items():
        if not indexes:
            continue
        width = widths[day]
        for rank, index in enumerate(indexes, start=1):
            event_positions[index] = starts[day] + width * rank / (len(indexes) + 1)

    tick_positions = [starts[day] + widths[day] / 2 for day in dates]
    tick_labels = [day.strftime("%m-%d") for day in dates]
    return starts, widths, event_positions, tick_positions, tick_labels


def actual_points(
    events: list[tuple[dt.datetime, int, str]],
    initial_total: int,
    start_date: dt.date,
    end_date: dt.date,
    as_of_date: dt.date,
) -> tuple[list[float], list[int], list[float], list[str]]:
    starts, widths, event_positions, tick_positions, tick_labels = density_axis(events, start_date, end_date)
    x_values = [starts[start_date]]
    y_values = [initial_total]
    current = initial_total
    for index, (_, delta, _) in enumerate(events):
        current = max(0, current + delta)
        x_values.append(event_positions[index])
        y_values.append(current)
    clamped_as_of = min(max(as_of_date, start_date), end_date)
    as_of_x = starts[clamped_as_of] + widths[clamped_as_of]
    if x_values[-1] < as_of_x:
        x_values.append(as_of_x)
        y_values.append(current)
    return x_values, y_values, tick_positions, tick_labels


def plot_burndown(
    issues: list[Issue],
    output: Path,
    start_date: dt.date,
    end_date: dt.date,
    initial_batch_date: dt.date,
    as_of_date: dt.date,
    target_total: int,
    milestone_title: str,
) -> None:
    try:
        import matplotlib.pyplot as plt
    except ModuleNotFoundError as exc:
        raise RuntimeError("matplotlib is required. Install it with: python -m pip install matplotlib") from exc

    load_font()
    output.parent.mkdir(parents=True, exist_ok=True)
    as_of_date = min(max(as_of_date, start_date), end_date)
    events, initial_total = burndown_events(issues, start_date, end_date, initial_batch_date, as_of_date, target_total)
    actual_x, actual_y, tick_positions, tick_labels = actual_points(
        events,
        initial_total,
        start_date,
        end_date,
        as_of_date,
    )
    starts, widths, _, _, _ = density_axis(events, start_date, end_date)
    ideal_end_x = starts[end_date] + widths[end_date]
    ideal_x = [actual_x[0], ideal_end_x]
    ideal_y = [target_total, 0]

    fig, ax = plt.subplots(figsize=(14, 6.4), dpi=160)
    fig.patch.set_facecolor("#fbfbf8")
    ax.set_facecolor("#fbfbf8")
    ax.plot(ideal_x, ideal_y, color="#9aa0a6", linewidth=2.0, linestyle="--", label="Ideal")
    ax.plot(
        actual_x,
        actual_y,
        color="#0b6b75",
        linewidth=2.8,
        marker="o",
        markersize=4.2,
        markerfacecolor="#fbfbf8",
        markeredgewidth=1.6,
        label="Actual",
    )
    ax.fill_between(actual_x, actual_y, color="#0b6b75", alpha=0.08)
    ax.set_title(f"{milestone_title} Burndown", fontsize=18, pad=16, weight="bold")
    ax.set_ylabel("Estimate Points", fontsize=11)
    ax.set_xlabel("Date", fontsize=11)
    ax.set_xlim(actual_x[0], actual_x[-1])
    upper = max([target_total] + actual_y)
    ax.set_ylim(0, math.ceil((upper + 10) / 10) * 10)
    ax.grid(axis="y", color="#d7d9d2", linewidth=0.8)
    ax.grid(axis="x", color="#eceee7", linewidth=0.6)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color("#c8cbc2")
    ax.spines["bottom"].set_color("#c8cbc2")
    ax.legend(loc="upper right", frameon=False)
    ax.set_xticks(tick_positions)
    ax.set_xticklabels(tick_labels, rotation=0, ha="center")
    fig.tight_layout()
    fig.savefig(output, bbox_inches="tight")
    plt.close(fig)


def write_snapshot(issues: list[Issue], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    payload = [
        {
            "number": issue.number,
            "title": issue.title,
            "state": issue.state,
            "created_at": issue.created_at.isoformat(),
            "closed_at": issue.closed_at.isoformat() if issue.closed_at else None,
            "estimate": issue_estimate(issue),
            "labels": issue.labels,
        }
        for issue in sorted(issues, key=lambda item: item.number)
    ]
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def refresh_latest_copy(dated_output: Path, newest_output: Path) -> None:
    newest_output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(dated_output, newest_output)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=DEFAULT_REPO)
    parser.add_argument("--milestone", default="Beta")
    parser.add_argument("--start-date", default="2026-05-25")
    parser.add_argument("--end-date", default="2026-06-08")
    parser.add_argument("--initial-batch-date", default="2026-05-26")
    parser.add_argument("--target-total", type=int, default=100)
    parser.add_argument(
        "--as-of-date",
        default=dt.datetime.now(dt.timezone.utc).date().isoformat(),
        help="last date included in the actual line; defaults to today",
    )
    parser.add_argument("--output-dir", default="burndowns")
    parser.add_argument("--newest-output", default="burndowns/newest.png")
    parser.add_argument("--json-output", default="burndowns/beta_burndown_issues.json")
    parser.add_argument("--sync", action="store_true", help="write milestone and estimate labels back to GitHub")
    parser.add_argument("--force-estimates", action="store_true", help="replace existing estimate:N labels")
    args = parser.parse_args()

    try:
        token = get_token()
        client = GitHubClient(args.repo, token)
        milestone = find_milestone(client, args.milestone)
        milestone_number = int(milestone["number"])
        issues = fetch_issues(client)

        if args.sync:
            issues = sync_milestone_issues(
                client,
                issues,
                milestone_number,
                parse_date(args.initial_batch_date),
                args.target_total,
                args.force_estimates,
                "Story-point estimate for Beta burndown charts",
            )
        else:
            issues = [issue for issue in issues if issue.milestone_number == milestone_number]

        as_of_date = parse_date(args.as_of_date)
        output_dir = Path(args.output_dir)
        dated_output = output_dir / f"{as_of_date.isoformat()}.png"

        write_snapshot(issues, Path(args.json_output))
        plot_burndown(
            issues,
            dated_output,
            parse_date(args.start_date),
            parse_date(args.end_date),
            parse_date(args.initial_batch_date),
            as_of_date,
            args.target_total,
            str(milestone["title"]),
        )
        refresh_latest_copy(dated_output, Path(args.newest_output))
    except RuntimeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        if "404" in str(exc) or "401" in str(exc):
            print(
                "hint: this usually means the repository is private or your GitHub token is invalid. "
                "Run `gh auth login -h github.com` or set GITHUB_TOKEN with repo/Issues access.",
                file=sys.stderr,
            )
        return 1
    print(f"Wrote {dated_output}")
    print(f"Wrote {args.newest_output}")
    print(f"Wrote {args.json_output}")
    if not args.sync:
        print("Run again with --sync to assign the Beta milestone and estimate:N labels.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
