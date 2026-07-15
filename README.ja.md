# load-spinner

システム負荷に比例して回転する macOS メニューバーインジケーター。マシンが忙しいほど、
アイコンの点灯部分が速く周回し、アイドル時はゆっくり回ります。「今どのくらい忙しいか」を
体感的に把握することが目的で、CPU/GPU はメニューバーへの数値表示を意図的に持ちません。

メモリは性質が異なります。これは「レート（流量）」ではなく「レベル（水位）」で、
変化の速さではなく「今どれだけ埋まっているか」を見る指標です。そのためスピナーではなく
**充填ゲージ**（使用率で満ちるリング）で表示します。
回るものはレート、満ちるものはレベル、という使い分けです。

> English: [README.md](README.md)

## ステータス

開発中。CPU/GPU/メモリ監視、メニューバーインジケーター（CPU/GPU はスピナー、メモリは
充填ゲージ）、クリックで開くパネル（ライブ値ゲージ＋メモリドーナツ＋履歴グラフ＋設定）まで
実装済み。残りは署名/notarize とリリース（Phase 3）。
詳細は [docs/ja/load-spinner-rfp.ja.md](docs/ja/load-spinner-rfp.ja.md)。

## 動作要件

- macOS 13 (Ventura) 以降
- Apple Silicon (arm64)

## ビルド

必ず Makefile 経由でビルドします（リリース用途で `swift build` を直接叩かないこと）。

```sh
make build       # リリースバイナリをコンパイル
make build-app   # 署名済み dist/load-spinner.app を組み立て
make package     # build-app + notarize + staple してリリース用 zip を生成
make test        # テスト実行
make run         # ビルドして起動（デバッグ）
make clean
```

`make build-app` は Developer ID Application で署名し、`make package` はさらに
notarize + staple して `dist/load-spinner-v<version>-darwin-arm64.zip` を生成します。

## 使い方

`dist/load-spinner.app` を起動すると、メニューバーに回転インジケーターが表示されます。
クリックするとパネルが開き、CPU/GPU のライブ負荷・メモリドーナツ・直近の履歴グラフ・設定を
確認できます:

- 表示モード: 高い方（CPU/GPUの高い方）／ CPUのみ ／ GPUのみ ／ 2つ表示
- シンボル: 丸 ／ 四角（2つ表示時は CPU・GPU 個別）
- 色: 固定色（CPU・GPU 個別）／ 負荷連動グラデーション（ティール→アンバー→コーラル）
- メモリ: メニューバーへの充填ゲージ表示、枠（丸/四角）、色（単色 ／ 使用率連動グラデ
  ＝ティール→アンバー→コーラルで満ちるほど暖色に）
- ログイン時に起動

パネルはメニューバーのトグルに関わらず常にメモリドーナツ（穴に使用率、使用/総量 GB）を
表示します。システムで GPU 使用率が取得できない場合、
GPU 関連の選択肢は自動的に無効化され CPU のみで動作します（メモリは常時利用可能）。
設定は再起動をまたいで保持されます。

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
- メモリは `host_statistics64`（`HOST_VM_INFO64`）から取得。使用率は Activity Monitor の
  *使用済みメモリ*（App + Wired + Compressed）に相当し、`free` は使いません。macOS は
  空き RAM をファイルキャッシュで埋めるため `free` はほぼ常にゼロ近くで誤解を招くからです
  （[docs/adr/0002-memory-as-filling-gauge.md](docs/adr/0002-memory-as-filling-gauge.md) 参照）。
- メニューバーアイコンは AppKit `NSStatusItem` 上のレイヤーバックビュー。スピナーは枠を固定し、
  `CAShapeLayer` の `lineDashPhase` をアニメーションさせて点灯部分1つが周囲を周回します
  （回転速度は負荷から線形にマッピング。
  [docs/adr/0001-menubar-animation-appkit.md](docs/adr/0001-menubar-animation-appkit.md) 参照）。
  メモリゲージは同じ枠を流用しますが、ストローク（`strokeEnd`）を使用率まで充填し、回転しません。

## ライセンス

MIT — [LICENSE](LICENSE) を参照。
