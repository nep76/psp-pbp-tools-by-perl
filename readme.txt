PSP PBP tools by Perl (061228)

This document was stored in EUC-JP.

1.0用のPSP自作ソフトにKXploit変換を行う
-------------------------------------------------
  kxploit.pl [オプション] PBP_FILE

    オプション:
      -o パス    インストール先ディレクトリを指定します。 (例: /mnt/PSP/GAME)
                 指定されなかった場合は、カレントディレクトリになります。

      -d ディレクトリ名
                 基本となるディレクトリ名です。 (例: hello_psp_world)
                 指定されなかった場合は、現在時刻が使用されます。

      -n         破損ファイル非表示を行いません。

      -r         古い破損ファイル非表示の方法を使用します。
                 (長い名前のディレクトリ名は短くされます。)

  使用例
      perl kxploit.pl -o /mnt/PSP/GAME -d SNES_TYL /home/me/EBOOT.PBP


PBPファイルの中身を表示する
-------------------------------------------------
  pbplist.pl PBP_FILE


PBPファイルの中身を取り出す
-------------------------------------------------
  pbpextract.pl [オプション] PBP_FILE

    オプション:
      -p パス    PARAM.SFO の展開先を指定します。
      -i パス    ICON0.PNG の展開先を指定します。
      -a パス    ICON1.PNG の展開先を指定します。
      -t パス    PIC0.PNG  の展開先を指定します。
      -b パス    PIC1.PNG  の展開先を指定します。
      -s パス    SND0.AT3  の展開先を指定します。
      -0 パス    DATA.PSP  の展開先を指定します。
      -1 パス    DATA.PSAR の展開先を指定します。
  
    特殊なオプション:
      -o ディレクトリパス
                 ディレクトリパスを指定します。
                 これが指定されると、その他のオプションを全て無視して
                 指定されたディレクトリへ含まれている構成ファイルを
                 全て展開します。

  使用例
    - ICON0.PNG をホームディレクトリへ取り出す
      perl pbpextract.pl -i ~/ /here/is/any/EBOOT.PBP
    
    - ICON0.PNG をファイル名を指定してホームディレクトリに取り出す
      perl pbpextract.pl -i ~/EXAMPLE.PNG /here/is/any/EBOOT.PBP
    
    - 全てのファイルをホームディレクトリへ取り出す
      perl pbpextract.pl -o ~/ /here/is/any/EBOOT.PBP


PBPファイルの作成/編集を行う
-------------------------------------------------
  pbpmake.pl [オプション] [構成ファイル] PBP_FILE

    オプション:
      -e - | パス    読み込み元のPBPファイルを指定します。
                     これは編集モードで、これが指定されている場合は、
                     未指定の構成ファイルについてのみ、
                     読み込み元のPBPファイルから引き継ぎます。

                     "パス"は通常のファイルパスですが、
                     "-" は特殊な値です。.
                     これは、読み込み元として PBP_FILE と
                     同じ物を指定するという意味になります。
                     しかし、このままでは上書きできないので、この値を使用する場合は
                     -f オプションも同時に指定してください。

      -f             もし PBP_FILE が既に存在していても無視して上書きします。

      -d ディレクトリパス
                     一時ファイルの出力先を指定します。
                     デフォルトではカレントディレクトリを使用します。
                     もしカレントディレクトリが書き込み可能ではない場合は、
                     このオプションを使って出力先を変更してください。

   構成ファイル:
      -p remove | パス | URI    PARAM.SFO
      -i remove | パス | URI    ICON0.PNG
      -a remove | パス | URI    ICON1.PNG
      -t remove | パス | URI    PIC0.PNG
      -b remove | パス | URI    PIC1.PNG
      -s remove | パス | URI    SND0.AT3
      -0 remove | パス | URI    DATA.PSP
      -1 remove | パス | URI    DATA.PSAR
   
   使用例
     - 新しいPBPファイルをホームディレクトリに作成する
       perl pbpmake.pl -p ./PARAM.SFP -p ./ICON0.PNG -0 ./DATA.PSP ~/EBOOT.PBP
     
     - ホームディレクトリにある既存のPBPファイルのICON0.PNGをimage.pngに差し替える
       perl pbpmake.pl -e - -i ./image.png ~/EBOOT.PBP
     
     - ホームディレクトリにある既存のPBPファイルからSND0.AT3を取り除く
       perl pbpmake.pl -e - -s remove ~/EBOOT.PBP
     
     - ホームディレクトリにある既存のPBPファイルのPIC1.PNGをbg.pngに変更し、
       ICON1.PNGを取り除いて、変更後のPBPファイルを/mnt/umass/EBOOT.PBPへ保存する
       perl pbpmake.pl -e ~/EBOOT.PBP -b ./bg.png -a remove /mnt/umass/EBOOT.PBP
     
     - ホームディレクトリにある既存のPBPファイルのICON0.PNGを
       ネットワーク上にある http://example.com/psp_icon.png に変更する。
       perl pbpmake.pl -e - -i http://example.com/psp_icon.png ~/EBOOT.PBP


Dark_Alex氏によるカスタムファームウェア OE-B で、
手持ちのPS1ソフトのディスクイメージを使えるようにする
-------------------------------------------------
  psxconv.pl [オプション] BASE_PBP ISO_IMAGE
  
    オプション:
      -o パス        変換後のPS1ゲームファイルの出力先を指定します。
                     デフォルトでは "./EBOOT.PBP" へ出力します。

      -f             もし PBP_FILE が既に存在していても無視して上書きします。

      -d ディレクトリパス
                     一時ファイルの出力先を指定します。
                     デフォルトではカレントディレクトリを使用します。
                     もしカレントディレクトリが書き込み可能ではない場合は、
                     このオプションを使って出力先を変更してください。

      -n セーブデータディレクトリ名
                     PS1ゲームのセーブデータが保存されるディレクトリ名を指定します。
                     ただし、"_XXXX_YYYYY" というフォーマットに従わなければなりません。
                     "X" は大文字のアルファベットです。
                     "Y" は数値です。
                     (例 _SLPS_12345 => ms0:/PSP/SAVEDATA/SLPS12345 )

                     デフォルトでは "_SLPS_10000" が使用されます。

      -t セーブデータタイトル
                     セーブデータのタイトルを指定します。
                     デフォルトでは "PSX SAVEDATA" が使用されます。

      -s PNGファイル PSXエミュレータが起動するときのスプラッシュスクリーンを指定します。
                     デフォルトでは、BASE_PBPが持っているスプラッシュスクリーンを使用します。

  概要
    基本的には、Dark_Alex氏のpopstation.exeと同じ使い方ですが、
    BASE.PBPが、カレントディレクトリのものを暗黙で使用するのではなく、指定できます。
    
    また、セーブディレクトリ名やセーブデータタイトルも変更できますが、
    セーブデータは仮想メモリーカードファイルとして保存されるので変更する必要はほぼありません。
    
  注意
    ここでは詳しく触れませんが、このスクリプトによる変換だけではPS1を起動出来るようにはなりません。
    まず、ファームウェアがDark_Alex氏の OE-B である必要があります。
    さらに、PLAYSTATION Storeで販売されているPSP用PS1ソフトに含まれているKEY.BINが必要なため、
    PS3を使って最低一本はソフトを購入する必要があります。
    
    また、popstation.exeの結果を見比べて、似たような動作をするようにしているだけなので、
    popstation.exeでは動くのにこれでは動かない、ということが起こるかもしれません。
    よくわからない数値は0x00で埋めてしまっていたりするので。
