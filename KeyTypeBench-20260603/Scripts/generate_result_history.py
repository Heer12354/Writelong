#!/usr/bin/env python3
"""Generate a Markdown benchmark-history table from committed aggregate.json files."""

import argparse
import json
from pathlib import Path


def percentage(value):
    return f"{value * 100:.1f}%"


def format_benchmark_date(value):
    if len(value) == 8 and value.isdigit():
        return f"{value[:4]}-{value[4:6]}-{value[6:]}"
    return value


def load_rows(repo_root):
    rows = []
    for aggregate_path in sorted(repo_root.glob("KeyTypeBench-*/Results/**/aggregate.json")):
        try:
            aggregates = json.loads(aggregate_path.read_text())
        except (OSError, json.JSONDecodeError) as error:
            raise SystemExit(f"Could not read {aggregate_path}: {error}")
        for aggregate in aggregates:
            rows.append({
                "date": format_benchmark_date(aggregate_path.parts[-4].removeprefix("KeyTypeBench-")),
                "result": aggregate_path.parent.name,
                "suite": aggregate["suite"],
                "rows": aggregate["rowCount"],
                "model": aggregate["modelIdentifier"],
                "quantization": aggregate.get("quantization") or "-",
                "precision": aggregate["precisionWhenShown"],
                "wrong_show": aggregate["wrongShowRate"],
                "path": aggregate_path.relative_to(repo_root),
            })
    return rows


def render(rows):
    lines = [
        "| Date | Result | Suite | Rows | Model / quantization | Precision when shown | Wrong-show rate | Artifact |",
        "| --- | --- | --- | ---: | --- | ---: | ---: | --- |",
    ]
    for row in rows:
        lines.append(
            f"| {row['date']} | {row['result']} | {row['suite']} | {row['rows']} | "
            f"{row['model']} / {row['quantization']} | {percentage(row['precision'])} | "
            f"{percentage(row['wrong_show'])} | `{row['path']}` |"
        )
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path, help="Write Markdown to this file instead of stdout.")
    args = parser.parse_args()

    result = render(load_rows(args.repo_root.resolve()))
    if args.output:
        args.output.write_text(result)
    else:
        print(result, end="")


if __name__ == "__main__":
    main()
