# ADR 0001: メニューバーのアニメーションは SwiftUI MenuBarExtra ではなく AppKit NSStatusItem を使う

- Status: Accepted
- Date: 2026-07-13

## Context

load-spinner の中心的な価値は、システム負荷に比例した速度でなめらかに連続してアニメーション
するメニューバーインジケーターである。RFP では当初 SwiftUI の `MenuBarExtra(.window)` アプリを
前提としていた。

`MenuBarExtra` のラベル内容は静止画像としてレンダリングされ、状態が変わったときだけ更新される。
毎フレームの連続アニメーションのために設計されたものではなく、状態を書き換えて ~30 fps で駆動
するとぎこちなく無駄も多く、フレームワークと戦うことになる。

## Decision

ボタンにレイヤーバックの `NSView`（`SpinnerView`）を載せた AppKit の `NSStatusItem` を使う。
インジケーターは `CAShapeLayer` で描く: 固定のトラックと、`lineDashPattern` で点灯部分 1 つを
定義したハイライトである。`lineDashPhase` をアニメーションさせるとその点灯部分が固定された外周を
移動する — 丸でも角丸四角でも「枠は固定で色が周回する」という仕様に一致する。軽量なタイマーが
phase を進め、回転速度は `LoadSpinnerCore` の負荷→RPM マッピングで決まる。

クリックで開くパネル（Phase 2）は引き続き SwiftUI で作り、`NSPopover`/`NSWindow` の中に
`NSHostingView` で載せる。こうして SwiftUI は得意な場所（宣言的なパネル UI、Swift Charts）に、
AppKit は必要な場所（信頼できるメニューバーのアニメーション）に置く。

## Consequences

- なめらかなアニメーションを完全に制御でき、自身に課す CPU 消費も低く抑えられる（実測 ~0.3%）。
- 純粋な SwiftUI の `App` ではなく、AppKit の定型コード（ステータス項目、メニュー）が少量必要に
  なる。
- アニメーションするビューはアプリの生存期間を通じて生きている（ステータス項目は 1 つ）ため、
  `deinit` でのタイマー破棄を意図的に持たない（Swift 6 の main-actor 隔離された `deinit` の
  制約も避けられる）。
- AppKit + SwiftUI のハイブリッドはメニューバーアプリでは踏み固められた型であり、Phase 2 の
  パネル作業を妨げない。
