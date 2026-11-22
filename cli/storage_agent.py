#!/usr/bin/env python3
"""Read-only storage investigation agent.

The program reads filesystem metadata only. It never deletes, moves,
compresses, or changes settings.
"""

from __future__ import annotations

import argparse
import json
import os
import shlex
import sys
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable


@dataclass
class Entry:
    path: str
    size: int
    kind: str
    note: str = ""


@dataclass
class ScanResult:
    root: str
    scanned_at: str
    total_bytes: int
    directories: list[Entry]
    files: list[Entry]
    warnings: list[str]


def human_size(value: int) -> str:
    amount = float(value)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if amount < 1024 or unit == "TB":
            return f"{int(amount)} B" if unit == "B" else f"{amount:.1f} {unit}"
        amount /= 1024
    return f"{value} B"


def note_for(path: Path, kind: str) -> str:
    text = str(path).lower()
    if "downloads" in text:
        return "ダウンロード済み。不要なアーカイブや重複を確認"
    if ".cache" in text or "/cache" in text:
        return "キャッシュ候補。使用中のアプリと再生成可否を確認"
    if "huggingface" in text or "models--" in text:
        return "ローカルAIモデル候補。現在使っているか確認"
    if "application support" in text:
        return "アプリデータ。履歴・設定・ログイン情報を含む可能性あり"
    if kind == "file" and path.suffix.lower() in {".zip", ".tar", ".gz", ".dmg", ".iso", ".pkg"}:
        return "大容量の配布物・アーカイブ候補"
    return ""


def scan(root: Path, depth: int, top: int, include_hidden: bool = True) -> ScanResult:
    root = root.expanduser().resolve(strict=False)
    warnings: list[str] = []
    files: list[Entry] = []
    directory_sizes: dict[Path, int] = {}
    try:
        root_dev = root.stat().st_dev
    except OSError as exc:
        return ScanResult(str(root), datetime.now().astimezone().isoformat(timespec="seconds"), 0, [], [], [str(exc)])

    def walk(path: Path) -> int:
        total = 0
        try:
            children = list(os.scandir(path))
        except OSError as exc:
            warnings.append(f"アクセスできません: {path} ({exc.strerror or exc})")
            return 0
        for item in children:
            child = Path(item.path)
            if not include_hidden and child.name.startswith("."):
                continue
            try:
                stat = item.stat(follow_symlinks=False)
            except OSError:
                warnings.append(f"メタデータを取得できません: {child}")
                continue
            if stat.st_dev != root_dev or item.is_symlink():
                continue
            if item.is_file(follow_symlinks=False):
                total += stat.st_size
                files.append(Entry(str(child), stat.st_size, "file", note_for(child, "file")))
            elif item.is_dir(follow_symlinks=False):
                child_size = walk(child)
                total += child_size
                directory_sizes[child] = child_size
        directory_sizes[path] = total
        return total

    total = walk(root)
    directories = [
        Entry(str(path), size, "directory", note_for(path, "directory"))
        for path, size in directory_sizes.items()
        if path != root and len(path.relative_to(root).parts) <= depth
    ]
    directories.sort(key=lambda entry: entry.size, reverse=True)
    files.sort(key=lambda entry: entry.size, reverse=True)
    return ScanResult(
        str(root),
        datetime.now().astimezone().isoformat(timespec="seconds"),
        total,
        directories[:top],
        files[:top],
        sorted(set(warnings))[:50],
    )


def print_result(result: ScanResult) -> None:
    print(f"\n調査対象: {result.root}\n合計: {human_size(result.total_bytes)}")
    print("\n容量の大きいフォルダ")
    for entry in result.directories:
        note = f" — {entry.note}" if entry.note else ""
        print(f"  {human_size(entry.size):>10}  {entry.path}{note}")
    print("\n容量の大きいファイル")
    for entry in result.files:
        note = f" — {entry.note}" if entry.note else ""
        print(f"  {human_size(entry.size):>10}  {entry.path}{note}")
    if result.warnings:
        print(f"\n注意: {len(result.warnings)}件のアクセス警告があります。")
        for warning in result.warnings[:8]:
            print(f"  - {warning}")
    print("\n※ 読み取り専用です。削除・移動・圧縮・設定変更は行いません。")


def run_once(path: str, args: argparse.Namespace) -> None:
    result = scan(Path(path), args.depth, args.top, not args.no_hidden)
    if args.json:
        print(json.dumps(asdict(result), ensure_ascii=False, indent=2))
    else:
        print_result(result)


def interactive(args: argparse.Namespace) -> None:
    print("Storage Investigation Agent（読み取り専用）")
    print("scan [path] / focus [path] / help / quit を入力できます。")
    current = str(Path.home())
    run_once(current, args)
    while True:
        try:
            raw = input("\nagent> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return
        if not raw:
            continue
        try:
            parts = shlex.split(raw)
        except ValueError as exc:
            print(f"入力を解釈できません: {exc}")
            continue
        command = parts[0].lower()
        if command in {"quit", "exit", "q"}:
            return
        if command == "help":
            print("scan [path]  指定場所を調査（省略時は現在の場所）")
            print("focus [path] scan と同じ意味です")
            print("quit         終了")
        elif command in {"scan", "focus"}:
            current = parts[1] if len(parts) > 1 else current
            run_once(current, args)
        else:
            print("不明なコマンドです。help と入力してください。")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="削除を行わず、容量の大きい場所を調査します。")
    parser.add_argument("path", nargs="?", default=str(Path.home()), help="調査対象。既定値はホームフォルダ")
    parser.add_argument("--depth", type=int, default=2, help="フォルダ表示の深さ（既定: 2）")
    parser.add_argument("--top", type=int, default=20, help="上位何件を表示するか（既定: 20）")
    parser.add_argument("--no-hidden", action="store_true", help="隠しファイル・フォルダを除外")
    parser.add_argument("--json", action="store_true", help="JSONで出力")
    parser.add_argument("--interactive", "-i", action="store_true", help="agent風の対話モード")
    return parser


def main(argv: Iterable[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.depth < 0 or args.top < 1:
        print("--depth は0以上、--top は1以上で指定してください。", file=sys.stderr)
        return 2
    if args.interactive:
        interactive(args)
    else:
        run_once(args.path, args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
