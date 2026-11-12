# school-utforsk-2026

SPADI の `user-daq` / `devel-daq` / `full` コンテナ内で実行する、RARiS AC-LGAD の再生例です。
`STFBFilePlayer` 3個 → `TimeFrameBuilder` 1個 → `FileSink` 1個を起動します。
Redis、web-ctrl、xterm は起動しません。既存の tmux セッションに5個の window を追加します。

## 実行

このディレクトリをコンテナから見える場所に clone / mount してください。
Redis と web-ctrl を先に起動し、他の DAQ プロセスが停止している状態で実行します。
Redis は **RedisTimeSeries** の `TS.ADD` が使えることが必要です。SPADI 内で Redis を手動起動する例:

```bash
redis-server --loadmodule /opt/spadi/lib/redistimeseries.so
```

通常の Redis だけでは TimeFrameBuilder が Run 後に終了します。
`run.sh` / `run2.sh` は RedisTimeSeries と他の登録済み DAQ の有無を確認し、
起動した全インスタンスが IDLE になってから成功を表示します。

```bash
tmux new-session -s school
# tmux 内で実行
cd /path/to/exp-config/school-utforsk-2026
./run.sh
```

Redis の既定値は `127.0.0.1:6379`、DB は daq_service=0、metrics=1、parameters=2 です。
web-ctrl も同じ Redis の daq_service DB に接続してください。
`mq-param.sh` がパラメータ、`topology.sh` がトポロジーを設定します。
`run.sh` は両方を実行し、現在の tmux セッションに各デバイス名の window を作って戻ります。
window の切り替えは `Ctrl+b` → `w`。各 window でログを確認できます。
DB の flush は行いませんが、同名サービスの設定を更新するため、他の DAQ と同時使用しないでください。
別構成の古い topology キーが残っていない専用の Redis DB を使用してください。
更新前の構成が動いている場合は、web-ctrl で停止・終了し、古いデバイス window を閉じてから、
`git pull` 後に起動し直してください。対象 endpoint の古い固定 address は再設定時に削除します。

web-ctrl で `STFBFilePlayer-0`〜`2` 、`TimeFrameBuilder-0`、`FileSink-0` を選び、run number を設定し、
**Init Device and Connection → Init Task → Run** の順に操作します。
各段階で全プロセスの状態遷移を確認してください。特に実機の STFBuilder は Sampler からの情報を待つため、Init Task も全デバイスを選んで実行してください。
TimeFrameBuilder の出力を FileSink が受信し、
既定では `output/runNNNNNN.dat`（web-ctrl で指定した run number）に保存します。
固定ポートは指定せず、FairMQ が bind ポートを選び、NestDAQ が Redis 経由で接続先を解決します。
STFBFilePlayer out（connect）→ TimeFrameBuilder in（bind）、
TimeFrameBuilder out（connect）→ FileSink in（bind）の構成です。
FileSink の DQM 出力も自動ポートの PUB で、購読なしでも動作します。
同じ PUSH 出力に別の PULL consumer を接続するとデータが分配されるため、保存中は接続しないでください。

保存先を変更する例（コンテナから書き込める、永続化されたパスを指定）:

```bash
OUTPUT_DIR=/workspace/replay-output ./run.sh
```

入力データは変更しません。`openmode=create` により、同じ出力ファイルがある場合は開かず、上書きを防ぎます。
web-ctrl で未使用の run number を指定してください。保存エラーは `logs/FileSink-0.log` で確認できます。
保存の完了には web-ctrl の **Stop** を使い、FileSink が停止したことを確認してください。
デバイス window 内の Ctrl+C はそのプロセスを中断します。通常の保存完了操作には使わないでください。

終了時は web-ctrl で **Stop → Reset Task → Reset Device → End**。
終了したプロセスの window はログ確認のため残ります。確認後 `Ctrl+b` → `&` で閉じてください。
再起動前に5個のデバイス window を閉じてください。同名 window がある場合は二重起動を拒否します。
Redis と web-ctrl はそのままです。
ログは `logs/<device-id>.log` に保存され、再起動すると上書きされます。

環境変数で Redis の接続先などを変更できます（`config.sh` 参照）。例:

```bash
REDIS_HOST=redis REDIS_PORT=6379 NESTDAQ_HOST_IP=192.168.1.10 ./run.sh
```

`127.0.0.1` はコンテナ自身を指します。別コンテナの Redis を使う場合は、到達できるホスト名を指定してください。
`NESTDAQ_PLUGIN_LIBDIR` で NestDAQ plugin のディレクトリを指定できます。
パラメータだけの更新は `./mq-param.sh`、接続設定だけの更新は `./topology.sh` を使います。
設定変更はデバイス停止・終了後に行ってください。

## 再生速度（STFBFilePlayer）

再生を遅くするための `wait` 設定は削除し、STFBFilePlayer の既定値（待機なし）に戻しています。
入力ファイルの再生が終了すると READY に戻ります。ループ再生はしません。

## 実機取得: run2.sh

`192.168.10.16` の AMANEQ から取得して FileSink に保存する場合は、tmux 内で実行します。
再生用の `run.sh` と同時には動かさないでください。切り替え前に web-ctrl で Stop → Reset Task → Reset Device → End、続いて `./stop.sh` で window を閉じます。

```bash
./run2.sh
```

`config2.sh`、`mq-param2.sh`、`topology2.sh` を使い、次の4 window を作ります。

```text
AmQStrTdcSampler-0 → STFBuilder-0 → TimeFrameBuilder-0 → FileSink-0
```

web-ctrl で4個すべてを選び、未使用の run number を指定して
**Init Device and Connection → Init Task → Run**。
既定の保存先は `output-live/runNNNNNN.dat` です。
正常終了は **Stop → Reset Task → Reset Device → End**、window の片付けは `./stop.sh`。

IP は `AMANEQ_IP=192.168.10.16`、TDC 種別は既存コンテナ recipe と同じ LR-TDC の `TDC_TYPE=1`、
`MAX_HBF=4`、`TFB_DECIMATION_FACTOR=0` です。変更する場合は `config2.sh` または環境変数を使います。

```bash
AMANEQ_IP=192.168.10.16 OUTPUT_DIR=/workspace/live-data ./run2.sh
```

Redis と web-ctrl は自分で起動してください。FEE の初期化・マスク・取得許可は事前に設定済みである必要があります。
`run2.sh` は FEE 設定を書き換えません。コンテナから実機へのネットワーク到達性も必要です。
実機を使った取得・保存はこの環境では未検証です。

## raw データと実装の出典

同梱データは SPADI の `raris-ac-lgad` recipe と同じ公開サンプル（run 20）です。
3本は同じ run の別ソースなので、組み合わせを維持してください。

- データ: [nobukoba/container-interfacing-nestdaq-eicrecon](https://github.com/nobukoba/container-interfacing-nestdaq-eicrecon/tree/ccf94e725389b5d32b2cd167312deb88c6461eba/example_rawdata/raris_ac_lgad_202603)
- 元パス: `example_rawdata/raris_ac_lgad_202603/{00,01,02}/run000020.dat`
- サイズ: 00=496,048 bytes、01=1,056,632 bytes、02=496,048 bytes
- `sha256sum --check SHA256SUMS` で検証可能。`run.sh` も起動前に検証します。
- 参考実装: [spadi-containers-second-trial](https://github.com/nobukoba/spadi-containers-second-trial/tree/2932ddddad9624cd7ed33504318b3f68664a018f/scripts/nestdaq)
  の `raris-ac-lgad` と `common`。`start-device.sh` / `config-common.sh` は同コミットから同梱しています。

## 検証

公開 `spadi-user-daq` イメージ（source commit `c5301bf21ff0fe438a358dba9f5a51a848e54e17`）の
実際の tmux、Redis 6.0.10 + RedisTimeSeries、NestDAQ バイナリで確認しました。

- 実機構成: 4プロセスが IDLE → DEVICE READY → READY。実機アクセスを伴う Run は未検証。
- 再生構成: 生データ3本 → TimeFrameBuilder → FileSink → 正常 Stop。
- 保存結果: 2,106,136 bytes、3ソースを含む完全な TimeFrame 2,815個、正常な FileSink header/trailer。
- 固定ポートなし。FairMQ がチャネルを確実に構築できるよう、起動引数にもチャネル定義を渡します。

同じ確認をコンテナ内で再実行するには:

```bash
bash tests/container-check.sh
```

テストは専用 Redis（既定16380番）・tmux セッション・`/tmp/utforsk-check.*` を使います。
既存の Redis と実機には接続せず、実機構成には Run を送信しません。
ログと保存ファイルはテスト終了後も表示された `/tmp` のディレクトリに残します。

実機取得にはコンテナから TCP/24 への到達性と FEE の適切な初期設定が必要です。
データを取りこぼしにくくする終了順は、Sampler を Stop、STFBuilder を Stop、
TimeFrameBuilder を Stop、最後に FileSink を Stop です。各段階の停止と転送完了を確認してください。
