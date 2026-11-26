# 概要

Terraform + AnsibleでAWS上に使い捨てのEDR回避のためのペイロード作成環境を構築します。

# ラボ構成

ラボは以下のホスト郡で構成されます。

## DEV

OS: Windows Server 2025
グローバルIP: 有り

主にペイロードを作成する環境。
ローカルの端末からこのホストのグローバルIPに向けてSSHで接続する。
Claude CodeとRust,Goがプリインストール済み

ELK、VICTIM、ATTACKERに接続するためのSSH鍵が配置されている

## ELK

OS: ubuntu
グローバルIP: 有り（外からの通信はSGで全拒否、ElasticSearch用に外に出るときのみ使用）

ElasticSearchがインストールされている。
VICTIMに対してインストールしたAgent経由で、Elastic Defendの検知ルールに従ってアラートを発生させる。
トライアルライセンスを有効化しておりMCPサーバーが利用可能。DEVのClaude Codeに設定して検知状況を確認させる想定。

- VICTIM

OS: Windows Server 2025
グローバルIP: 無し(Private subnet内のみ通信可能)

ペイロード実行環境。
Elastic Defendがインストール済。
このホストではペイロードの実行しか行わない想定。

- ATTACKER
OS: Ubuntu
グローバルIP: 無し(Private subnet内のみ通信可能)

攻撃者環境
Sliverがプリインストール済。
Claude CodeにSliverを操作させ、ペイロード実行によるセッション確立状況を確認させる想定。

# 前提条件

playbook実行環境はLinuxを想定。Windowsは対象外。
加えて以下が必要

- ansible
- terraform
- awscliv2

# 使用方法

## 環境構築

まずansible moduleをインストールするため、以下を実行

```bash
ansible-galaxy install -r ansible/requirements.yaml
```

次にaws cliでログインしておく。出力されたURLにアクセスしてログインすればOK。

```
aws login --remote
```

playbook実行でリソースが作成が開始され、終了するとansibleによる構成が始まる。

```bash
./bootstrap.sh
```

## 環境解体

```
cd terraform
terraform destroy
```
