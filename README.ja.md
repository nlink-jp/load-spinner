# load-spinner

システム負荷に比例して回転する macOS メニューバーインジケーター。マシンが忙しいほど、
アイコンの点灯部分が速く周回し、アイドル時はゆっくり回ります。「今どのくらい忙しいか」を
体感的に把握することが目的で、メニューバーへの数値表示は意図的に持ちません。

> English: [README.md](README.md)

## ステータス

開発中。CPU/GPU 監視、メニューバーの回転インジケーター（1〜2個）、クリックで開くパネル
（ライブ値ゲージ＋履歴グラフ＋設定）まで実装済み。残りは署名/notarize とリリース（Phase 3）。
詳細は [docs/ja/load-spinner-rfp.ja.md](docs/ja/load-spinner-rfp.ja.md)。

## 動作要件

- macOS 13 (Ventura) 以降
- Apple Silicon (arm64)

## ビルド

必ず Makefile 経由でビルドします。`dist/` 配下に `.app` バンドルを組み立てます
（リリース用途で `swift build` を直接叩かないこと）。

```sh
make build     # -> dist/load-spinner.app
make test      # テスト実行
make run       # ビルドして起動
make clean
```

## 使い方

`dist/load-spinner.app` を起動すると、メニューバーに回転インジケーターが表示されます。
クリックするとパネルが開き、CPU/GPU のライブ負荷・直近の履歴グラフ・設定を確認できます:

- 表示モード: 高い方（CPU/GPUの高い方）／ CPUのみ ／ GPUのみ ／ 2つ表示
- シンボル: 丸 ／ 四角（2つ表示時は CPU・GPU 個別）
- 色（CPU・GPU 個別）
- ログイン時に起動

システムで GPU 使用率が取得できない場合、GPU 関連の選択肢は自動的に無効化され、CPU のみで
動作します。設定は再起動をまたいで保持されます。

### CLI

同一バイナリに診断用サブコマンドを同居させています:

```sh
load-spinner doctor      # CPU/GPU メトリクス取得の可否を診断
load-spinner --version   # バージョン表示
load-spinner --help      # 使い方
```

## 仕組み

- CPU 負荷は Mach カーネル（`host_statistics`, `HOST_CPU_LOAD_INFO`）から取得。
  公開 API で特権不要。
- メニューバーアイコンは AppKit `NSStatusItem` 上のレイヤーバックビュー。枠は固定で、
  `CAShapeLayer` の `lineDashPhase` をアニメーションさせ、点灯部分1つが周囲を周回します。
  回転速度は負荷から線形にマッピング
  （[docs/adr/0001-menubar-animation-appkit.md](docs/adr/0001-menubar-animation-appkit.md) 参照）。

## ライセンス

MIT — [LICENSE](LICENSE) を参照。
