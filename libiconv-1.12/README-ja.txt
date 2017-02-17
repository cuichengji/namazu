============================================================================
               GNU libiconv 1.12 + 日本語エンコーディングパッチ
                                             -- x86 版ビルド方法 --

                    Copyright (C) 2008 AKANEIROSOFTWARE, Tadamasa Teranishi.
============================================================================
                                                   Last modified: 2008.09.19


■ 1. はじめに
--------------

   GNU libiconv に日本語エンコーディングパッチをあてたものです。
   (libiconv-1.12-ja-4.patch.gz)

   また、Windows + VC++ 環境でコンパイルするために必要な Makefile.msvc を含み
   ます。(--enable-extra-encodings オプション指定)


■ 2. このアーカイブ以外に必要な物
----------------------------------

* Microsoft Visual C++ 2005 または Microsoft Visual C++ 2008


■ 3. 日本語エンコーディングパッチについて
------------------------------------------

* libiconv パッチ集
  <http://www2d.biglobe.ne.jp/~msyk/software/libiconv-patch.html>にあります。


■ 4. GNU libiconv のインストール
---------------------------------

  コマンドプロンプトを開き、コマンドラインでコンパイルを行うために
  vcvarsall.bat を実行します。

  例) Visual C++ 2005 の場合

  ┌───────────────────────────────────┐
  │C:\> cd "\Program Files\Microsoft Visual Studio 8\VC"                 │
  │C:\Program Files\Microsoft Visual Studio 8\VC> vcvarsall              │
  └───────────────────────────────────┘

  libiconv-1.12.zip を解凍し、コマンドラインから nmake を実行します。

  ┌───────────────────────────────────┐
  │C:\> cd \libiconv-1.12                                                │
  │C:\libiconv-1.12> set MFLAGS=-MT                                      │
  │C:\libiconv-1.12> set PREFIX=C:\usr                                   │
  │C:\libiconv-1.12> set NO_NLS=1                                        │
  │C:\libiconv-1.12> nmake /f Makefile.msvc clean                        │
  │C:\libiconv-1.12> nmake /f Makefile.msvc                              │
  │C:\libiconv-1.12> nmake /f Makefile.msvc install                      │
  └───────────────────────────────────┘

  C:\usr\ 以下にインストールされます。


■ 5. 免責
----------

  本アーカイブは無保証です。頒布にあたっては、市場性及び特定目的適合性につい
  ての暗黙の保証を含めて、いかなる保証も行ないません。


============================================================================
                    Copyright (C) 2008 AKANEIROSOFTWARE, Tadamasa Teranishi.
                                               <URI:http://www.akaneiro.jp/>
