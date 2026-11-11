# school-utforsk-2026

SPADI の `user-daq` / `devel-daq` / `full` コンテナ内で実行する、RARiS AC-LGAD の再生例です。
`STFBFilePlayer` 3個 → `TimeFrameBuilder` 1個を起動します。
Redis、web-ctrl、xterm、tmux は起動しません。FileSink は含みません。

## 実行

このディレクトリをコンテナから見える場所に clone / mount してください。
Redis と web-ctrl を先に起動し、他の DAQ プロセスが停止している状態で実行します。

```bash
cd /path/to/exp-config/school-utforsk-2026
./run.sh
```

Redis の既定値は `127.0.0.1:6379`、DB は daq_service=0、metrics=1、parameters=2 です。
web-ctrl も同じ Redis の daq_service DB に接続してください。
`run.sh` は再生用のパラメータとトポロジーの対象キーを書き込みます。
DB の flush は行いませんが、同名サービスの設定を更新するため、他の DAQ と同時使用しないでください。
別構成の古い topology キーが残っていない専用の Redis DB を使用してください。

web-ctrl で `STFBFilePlayer-0`〜`2` と `TimeFrameBuilder-0` を選び、run number を設定し、
**Init Device and Connection → Init Task → Run** の順に操作します。
各段階で全プロセスの状態遷移を確認してください。
出力は `tcp://127.0.0.1:5501`（PUSH）です。受信・保存する場合は PULL の consumer を別途接続してください。
consumer がないと出力待ちになる場合があります。

終了時は web-ctrl で **Stop → Reset Task → Reset Device → End**。
`run.sh` はいずれかのプロセスが終了すると残りも停止します。
端末で Ctrl+C を押しても起動した4プロセスを停止します。Redis と web-ctrl はそのままです。
ログは `logs/<device-id>.log` に保存され、再起動すると上書きされます。

環境変数で接続先やポートを変更できます（`config.sh` 参照）。例:

```bash
REDIS_HOST=redis REDIS_PORT=6379 NESTDAQ_HOST_IP=192.168.1.10 ./run.sh
```

`127.0.0.1` はコンテナ自身を指します。別コンテナの Redis を使う場合は、到達できるホスト名を指定してください。
`NESTDAQ_PLUGIN_LIBDIR` で NestDAQ plugin のディレクトリを指定できます。
パラメータだけ書き込む場合は `./configure.sh` を使います。

## raw データと実装の出典

同梱データは SPADI の `raris-ac-lgad` recipe と同じ公開サンプル（run 20）です。
3本は同じ run の別ソースなので、組み合わせを維持してください。

- データ: [nobukoba/container-interfacing-nestdaq-eicrecon](https://github.com/nobukoba/container-interfacing-nestdaq-eicrecon/tree/ccf94e725389b5d32b2cd167312deb88c6461eba/example_rawdata/raris_ac_lgad_202603)
- 元パス: `example_rawdata/raris_ac_lgad_202603/{00,01,02}/run000020.dat`
- サイズ: 00=496,048 bytes、01=1,056,632 bytes、02=496,048 bytes
- `sha256sum --check SHA256SUMS` で検証可能。`run.sh` も起動前に検証します。
- 参考実装: [spadi-containers-second-trial](https://github.com/nobukoba/spadi-containers-second-trial/tree/2932ddddad9624cd7ed33504318b3f68664a018f/scripts/nestdaq)
  の `raris-ac-lgad` と `common`。`start-device.sh` / `config-common.sh` は同コミットから同梱しています。

この環境では DAQ バイナリがないため、実データのエンドツーエンド再生は未検証です。
