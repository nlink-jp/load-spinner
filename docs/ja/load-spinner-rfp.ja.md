# RFP: load-spinner

> Generated: 2026-07-13
> Status: Draft

## 1. Problem Statement

macOS で作業しているとき、CPU / GPU の負荷を「数値を読み取る」のではなく感覚的に把握したい。
`load-spinner` はメニューバーに常駐し、負荷に比例して回転（点灯部分が周回）するインジケーターを表示する。
負荷が高いほど速く、低いほどゆっくり回るため、一目で現在の負荷状態が分かる。
対象ユーザーは開発者／パワーユーザー（当面は作者本人）で、正確な数値よりも「今どのくらい忙しいか」の
体感的な把握を主目的とする。

## 2. Functional Specification

### Commands / API Surface

GUI アプリ（メニューバー常駐）を主体とし、同一バイナリに診断用 CLI サブコマンドを同居させる
（組織規約の GUI + CLI 一体パターン）。

- `load-spinner`（引数なし）: GUI をメニューバー常駐で起動
- `load-spinner doctor`: CPU / GPU メトリクス取得の可否を診断。CPU 取得結果、GPU の IOKit
  `PerformanceStatistics` キー検出結果、取得できた利用率値を表示し、GPU が利用不可なら理由を明示
- `load-spinner --version`: `git describe` 由来のバージョンを表示

### Input / Output

- 入力: システムメトリクス（CPU: Mach カーネル統計、GPU: IOKit）。ユーザー入力は GUI 操作のみ
- 出力（GUI）:
  - メニューバー: アイコンのみ（数値表示なし）。枠（丸／四角）は固定で、点灯部分が枠に沿って周回。
    周回速度は負荷に比例（低=ゆっくり／高=高速）
  - クリックで開くパネル: 現在の CPU / GPU 値のライブ表示、直近一定期間の履歴グラフ
    （Swift Charts）、設定 UI を 1 枚に集約
- 出力（CLI）: `doctor` は人間可読テキストを stdout に出力

### 表示モード

- `高い方（合成）`: CPU と GPU の高い方を 1 個のインジケーターで表示。形・色は一択
- `CPUのみ`: CPU のみを 1 個表示
- `GPUのみ`: GPU のみを 1 個表示
- `2つ表示`: CPU と GPU を並べて表示。形（丸／四角）・色を **それぞれ個別に** 指定可能
  （例: CPU=丸・青、GPU=四角・緑）

### Configuration

- 設定は `@AppStorage`（UserDefaults）に永続化: 表示モード、シンボル形状（CPU/GPU/合成）、
  色（CPU/GPU/合成）、ログイン項目 ON/OFF
- 履歴グラフのデータはメモリ上のリングバッファのみ（例: 直近 3 分 × 1Hz ≈ 180 点）。
  再起動をまたいでの永続化は行わない
- 自動起動: `SMAppService` によるログイン項目登録。パネルにトグルを置き、デフォルト OFF

### External Dependencies

- 外部 API / サービス / 認証情報は一切なし（すべてローカルのシステム API）
- CPU: Mach `host_statistics64`（`HOST_CPU_LOAD_INFO`）/ `host_processor_info`
  （`PROCESSOR_CPU_LOAD_INFO`）
- GPU: IOKit `IOAccelerator` サービスの `PerformanceStatistics` プロパティ辞書
  （`"Device Utilization %"` 等）

## 3. Design Decisions

- **言語 / フレームワーク**: Swift / SwiftUI。`MenuBarExtra(.window)` でメニューバー常駐 +
  クリックパネルを SwiftUI で描画し、履歴グラフは Swift Charts。既存の観測系 GUI
  `active-lens-gui` / `claude-usage-lens-gui` / `quick-translate` と同型
- **対象プラットフォーム**: darwin/arm64 専用
- **CPU メトリクス**: Mach カーネル統計（公開 API・権限不要・root 不要）。前回サンプルとの
  tick 差分で使用率算出。サンプリングは 1〜2 回/秒
- **GPU メトリクス**: IOKit `PerformanceStatistics`。公開 API が存在しないため半公開の
  IOKit キーに依存する。iStat Menus / asitop / mactop 等が用いる実績ある手法で、root・
  entitlement 不要。ただしキー名は非公開で OS バージョン間で変わりうるため、キー未検出時は
  GPU 表示を自動的に disable し、CPU のみで動作を継続する（degrade 設計）
- **自身の負荷抑制**: メトリクスサンプリングは 1〜2 回/秒に抑え、回転描画は Core Animation
  （GPU コンポジット）に委ねて軽量化する
- **補完関係**: util-series の観測系メニューバー常駐アプリ群（`active-lens-gui` =操作時間、
  `claude-usage-lens-gui` =トークン/コスト）に、システム負荷という軸を加える
- **Out of scope**:
  - Intel Mac / Windows / Linux（darwin/arm64 専用）
  - ネットワーク送信・テレメトリ
  - 履歴データの永続保存（メモリのみ）
  - メニューバーへの数値（%）表示（感覚値把握が主目的のため意図的に非対応）
  - CPU/GPU 以外のメトリクス（メモリ、ネットワーク、温度等）

## 4. Development Plan

### Phase 1: Core

- Mach カーネル統計による CPU 使用率取得（純関数化・テスト可能設計）
- メニューバー常駐（`MenuBarExtra`）と周回アニメーション（枠固定・点灯部分が周回、
  速度が負荷に比例）
- `高い方（合成）` / `CPUのみ` モードと、丸／四角のシンボル・色選択
- 単体テスト（使用率算出ロジック、負荷→速度マッピング）
- レビュー単位: 独立レビュー可能（CPU 監視 + 基本アニメーションで完結）

### Phase 2: Features

- GPU 使用率取得（IOKit `PerformanceStatistics`）と取得不可時の自動 disable（degrade）
- `GPUのみ` / `2つ表示` モード、CPU/GPU 個別の形・色指定
- クリックパネル: 現在値ライブ表示 + 履歴グラフ（Swift Charts）+ 設定 UI
- 設定の永続化（`@AppStorage`）、`SMAppService` によるログイン項目登録トグル
- `load-spinner doctor` サブコマンド
- レビュー単位: GPU 対応 / パネル UI / 永続化・自動起動 で分割レビュー可能

### Phase 3: Release

- README.md / README.ja.md、CHANGELOG.md 整備
- 署名 + notarize（Developer ID）、`.app` の zip 配布
- Homebrew tap（arm64 prebuilt-binary、署名保持）への登録
- umbrella submodule ポインタ更新、org profile / web-site catalog 反映
- `check-org.sh` 実行で全 green 確認

## 5. Required API Scopes / Permissions

None（外部サービス連携なし）。

- 特別なエンタイトルメントや TCC（プライバシー）権限は不要。CPU（Mach）・GPU（IOKit）とも
  ローカルかつ非特権で取得できる
- `SMAppService` のログイン項目登録はユーザー操作トグルで完結し、追加権限を必要としない

## 6. Series Placement

Series: util-series

Reason: システムメトリクスをローカルで可視化する常駐 GUI アプリであり、util-series の観測系
GUI 群（`active-lens-gui`、`claude-usage-lens-gui`）と同カテゴリ。外部サービス認証を伴わず、
ローカル完結・単一バイナリ・darwin/arm64 という util-series GUI アプリの型に合致する。

## 7. External Platform Constraints

- **GPU 利用率 API の非公開性**: macOS には GPU 利用率の完全な公開 API が存在せず、IOKit
  `PerformanceStatistics` の非公開キーに依存する。キー名・存在は OS バージョン間で変わりうる
  ため、キー未検出時は GPU 表示を disable する degrade 設計を必須とする
- **macOS バージョン要件**: `MenuBarExtra` および `SMAppService` は macOS 13 (Ventura) 以降。
  最低対応 OS を macOS 13 とする
- **メニューバー幅**: `2つ表示` モードではアイコン 2 個分の幅を占有する
- **メニューバー描画の制約**: 常駐アニメーションが自身の CPU を消費しないよう、サンプリング頻度
  と描画方式（Core Animation コンポジット）に留意する

---

## Discussion Log

- 発端: メニューバー上で CPU/GPU 負荷に合わせて回転するインジケーター（高負荷=高速回転、
  低負荷=低速回転）の実現可否を検討。技術的に可能と確認（メニューバー常駐 = `NSStatusItem`/
  `MenuBarExtra`、CPU = Mach 統計、GPU = IOKit）
- インタラクティブなデモを段階的に提示し、以下を合意:
  - 表示モードの切り替え（高い方 / CPUのみ / GPUのみ / 2つ表示）
  - シンボルは丸／四角を選択可能、色も変更可能
  - 2つ表示時は CPU/GPU で形・色を個別指定、合成モードは一択
  - 四角は「図形自体が回転する」のではなく「枠は固定で点灯部分が周回する」方式に統一
    （丸も同様に色が周回する方式）
- クリック時の挙動を追加合意: パネルを開き、現在値のライブ表示 + 履歴グラフ + 設定を集約。
  数値のメニューバー表示は不要（感覚値把握が主目的）
- GPU 監視は含めるが、値が取れなければ GPU 表示を自動 disable する方針を確定
- UI は「モダンでかっこよく」を方針とし、パネルモックで方向性を合意
- 命名: -lens ファミリー案（load-lens）も検討したが、用途が一目で分かる `load-spinner` を採用
- 決定事項:
  - 自動起動: `SMAppService` でログイン項目登録、パネルにトグル、デフォルト OFF
  - CLI 同居: `doctor` サブコマンドのみ（GPU 取得可否のトラブルシュート用）
  - 履歴: メモリのみ（再起動でリセット）
- シリーズ: util-series（観測系常駐 GUI 群と同カテゴリ）で合意
