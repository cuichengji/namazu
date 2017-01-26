pltests は、インストール済み Namazu の簡易テストプログラムです。

==============================================================

[[ ファイルリスト ]]

alltests.pl 全テストを実行する Perl スクリプト

env.pl
mknmz-1.pl
mknmz-2.pl
mknmz-3.pl 欠番(ActivePerl の system() の実装の違いによりチェック不可)
mknmz-4.pl
mknmz-5.pl
mknmz-6.pl
mknmz-7.pl
mknmz-8.pl
mknmz-9.pl 欠番(kill が必要なため)
mknmz-10.pl
mknmz-11.pl 欠番(シンボリックリンクのチェックのため)
mknmz-12.pl
mknmz-14.pl
mknmz-15.pl
mknmz-16.pl
mknmz-17.pl
mknmz-18.pl
gcnmz-1.pl
idxdiff-1.pl
idxdiff-2.pl 欠番(idx3 が必要なため)
idxdiff-3.pl
namazu-1.pl
namazu-2.pl
namazu-3.pl
namazu-4.pl
namazu-5.pl
namazu-6.pl
namazu-7.pl
namazu-8.pl
namazu-9.pl
namazu-10.pl
namazu-11.pl
namazu-12.pl
namazu-cgi-1.pl
namazu-cgi-2.pl
namazu-cgi-3.pl
namazu-cgi-4.pl
namazu-cgi-5.pl
namazu-cgi-7.pl
namazu-cgi-8.pl
namazu-cgi-9.pl
namazu-cgi-10.pl
namazu-cgi-12.pl
ja-namazu-cgi-3.pl
chasen-1.pl
chasen-2.pl
chasen-3.pl
mecab-1.pl
mecab-2.pl
mecab-3.pl
kakasi-1.pl
kakasi-2.pl
kakasi-3.pl

pltests.pl テスト用ライブラリ

==============================================================

[[ 実行方法 ]]

- UNIX 環境

  $ make test
  または
  $ perl alltests.pl

- Windows 環境

  C:\namazu\pltests> perl alltests.bat

[[ 注意 ]]

- 事前に Namazu をインストールしている必要があります。
- 環境変数 HOME が設定されている必要があります。
- Windows では、環境変数 pkgdatadir が設定されている必要があります。

  例) C:\> set pkgdatadir=C:\namazu\share\namazu

- 事前に NKF の Perl モジュールをインストールしている必要があります。
