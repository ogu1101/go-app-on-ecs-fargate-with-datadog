# 概要

このリポジトリをクローンし、後述のコマンドを実行すると、以下アーキテクチャ図の AWS リソースが作成され、アプリケーションコンテナおよび Datadog Agent コンテナが ECS Fargate にデプロイされます。

# 前提条件

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) をインストール済みであること。
- [Terraform](https://developer.hashicorp.com/terraform/install) をインストール済みであること。
- [Docker](https://docs.docker.com/engine/install/) をインストール済みであること。

# ビルド方法

## `terraform/terraform.tfvars`　ファイルの修正

- AWS リソース名の重複を避けるため、任意の値を `env` に設定してください。
- セキュリティグループ作成画面の`送信先`に`マイ IP` を選択すると、グローバル IP アドレスが表示されます。それを `global_ip_address` に設定してください。
- Datadog の API キーを `dd_api_key` に設定してください。

## AWS 認証情報の設定

- `AWS access portal` 画面で`アクセスキー`リンクをクリックし、`export` コマンドをコピーしてください。
- ターミナルでその `export` コマンドを実行してください。
- または、以下ドキュメントのいずれかを参考に、AWS 認証情報を設定してください。
  - [Configure the AWS CLI with IAM Identity Center authentication](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html#sso-configure-profile-token-auto-sso)
  - [Environment variables to configure the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html?icmpid=docs_sso_user_portal)
  - [Configuration and credential file settings](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
  - [Authenticate with short-term credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-short-term.html)

## コマンド実行

- 以下コマンドの ${ENV} を `env` の値に置き換えてください。
- 一回目の `terraform apply` コマンド実行時に、AWS アカウント ID ( aws_account_id ) が出力されます。それを以下コマンドの ${AWS_ACCOUNT_ID} に置き換えてください。

```bash
cd terraform

terraform init

terraform apply -target=aws_ecr_repository.repository

aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com

cd ..

docker buildx build . \
    -t ${ENV}-ecr-repository \
    --platform linux/arm64 \
    --build-arg DD_GIT_REPOSITORY_URL=github.com/ogu1101/example-go-app-with-datadog \
    --build-arg DD_GIT_COMMIT_SHA=$(git rev-parse HEAD)

docker tag ${ENV}-ecr-repository:latest ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/${ENV}-ecr-repository:latest

docker push ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/${ENV}-ecr-repository:latest

cd terraform

terraform apply
```

# 動作確認

- 二回目の `terraform apply` コマンド実行時に、ALB の DNS 名 ( alb_dns_name ) が出力されます。それを以下コマンドの ${ALB_DNS_NAME} に設定してください。

```bash
curl http://${ALB_DNS_NAME}:8080/albums \
    --include \
    --header "Content-Type: application/json" \
    --request "POST" \
    --data '{"title": "The Modern Sound of Betty Carter","artist": "Betty Carter","price": 49.99}'

curl http://${ALB_DNS_NAME}:8080/albums/1
```
