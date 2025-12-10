# Antenna Books & Cafe ココシバ ポイントアプリ

Flutter/Material 3 で構築した、Antenna Books & Cafe ココシバの会員ポイントアプリです。Firebase Authentication を利用してメールアドレスとパスワードでログインし、ホームタブではブランドロゴや仮ポイントカード UI、他タブではプレースホルダーの画面を確認できます。

## 主な機能
- Firebase Email/Password によるアカウント新規作成・ログイン・ログアウト
- 起動画面（AuthChoicePage）からの導線、ログイン/新規作成フォーム
- ホーム/カレンダー/本/アカウントの 4 タブ + 中央 QR コード FAB のボトム UI
- ホームタブのブランドロゴ、ポイントカード、ショートカットボタン（ダミー挙動）
- アカウント情報表示とログアウト操作（プロフィール編集は準備中）
- Firestore に保存したお知らせを全ユーザーへプッシュ通知する仕組み

## Firebase 連携
- プロジェクト ID: `cocoshibaapp`
- バンドル ID / Application ID: `com.groumap.cocoshiba`
- 設定ファイルの配置先
  - `ios/Runner/GoogleService-Info.plist`
  - `android/app/google-services.json`
- `firebase_core`, `firebase_auth`, `cloud_firestore` を `pubspec.yaml` に追加済みです。
  - Firestore 連携画面は未実装ですが、今後の拡張で利用できます。
  - Firestore ルールは `firebase/firestore.rules` に定義しているので、`firebase deploy --only firestore:rules` を実行して反映してください（認証済みユーザーのみ `users/{uid}` を更新可能にするルールです）。
- `firebase_messaging` と `flutter_local_notifications` を導入し、サーバーからの FCM を前景時も表示できるようにしました。
- `functions/` ディレクトリに Cloud Functions（Node.js 20）を追加し、お知らせ作成をトリガーに FCM を送信します。

## ディレクトリ構成（抜粋）
```
lib/
├── app.dart                      # MaterialApp / AuthGate
├── main.dart                     # Firebase 初期化エントリ
├── screens/
│   ├── account_page.dart
│   ├── auth_choice_page.dart
│   ├── books_page.dart
│   ├── calendar_page.dart
│   ├── home_page.dart
│   ├── login_page.dart
│   ├── main_tab_scaffold.dart
│   ├── qr_code_page.dart
│   └── sign_up_page.dart
├── services/
│   └── firebase_auth_service.dart
└── widgets/
    └── point_card.dart
assets/
└── images/
    └── cocoshiba_logo.png
```

## セットアップ
1. Flutter 環境と Firebase CLI を用意し、`flutter pub get` を実行します。
2. ルートに置いた Firebase 設定ファイルが最新か確認します。
3. `flutterfire configure` を使う場合は `com.groumap.cocoshiba` を選択し、必要に応じて `firebase_options.dart` を生成してください（現状はネイティブ設定ファイルで初期化を行っています）。
4. `flutter run` で iOS/Android いずれかのデバイスへデプロイします。
5. プッシュ通知を有効にするには、`firebase deploy --only functions` で Cloud Functions をデプロイし、iOS の APNs 証明書/キーを Firebase コンソールに設定してください。

## 通知機能メモ
- モバイルアプリは初回ログイン時に通知許可をリクエストし、FCM トークンを `users/{uid}` の `fcmTokens` 配列へ保存します。
- `notifications/{notificationId}` ドキュメントを作成すると、`functions/index.js` の `onNotificationCreated` が起動し、全ユーザーのトークンへ FCM を送信します。
- Android は `app_announcements` チャンネルを使用し、iOS/macOS はフォアグラウンド時でもローカル通知で即時表示されます。
- 背景状態でのテストは Firebase コンソールからのテスト送信でも可能ですが、本番と同じ経路を確認する場合はアプリから「新規お知らせ」を投稿してください。

## 開発メモ
- テーマカラー
  - メイン: `#2E9463`
  - サブ: `#FFFBD2`
- `assets/images/cocoshiba_logo.png` はアプリ内で使用するロゴです。差し替える場合は同じパスで上書きしてください。
- 今後の要件に応じて各タブへ Firestore 連携や実際の QR 表示、ポイント加算処理などを追加できます。
