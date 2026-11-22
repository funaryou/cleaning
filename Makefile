.PHONY: help web cli

help:
	@printf '%s\n' \
		'make help                  コマンド一覧を表示' \
		'make web                   Web を起動' \
		'make cli                   掃除スクリプトを対話モードで実行' \
		'make cli ARGS="--dry-run"   削除せずに確認' \
		'make cli ARGS="--help"      掃除スクリプトのオプションを表示'

web:
	./web/start.sh

cli:
	./cli/clean.sh $(ARGS)
