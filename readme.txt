PSP PBP Tools by Perl

=== [概要] ================================================
PSPのPBPファイルに対するいくつかの操作を行うためのPerlスクリプトです。
このスクリプトはコマンドラインから実行します。
以下のようなことができます。

    1. ファームウェア1.00用の自作アプリケーションを1.50で起動できるように変換する(KXploit)。
           指定されたEBOOT.PBPに対してKXploitを行います。
           ディレクトリを DIR と DIR% に分けて、PBPファイルを分割します。

    2. PBPファイルの中身を差し替える。
           PBPファイルの中身を表示したり差し替えることができます。
           アイコンファイルを差し替えたり、背景画像を挿入したり、
           BGMを削除するなどの操作を行えます。

Windowsにおいてはこの手のツールはいくつも存在するのですが、
これがMacintoshやPC-UNIXとなると急に困ってしまいます。
このスクリプトはそれを解決します。

基本的に自分用として作成したので、自己責任で使用してください。


=== [ pkx.pl : KXploit toolの使い方 ] =====================

    perl pkx.pl [options] Install_PBP_File

Install_PBP_Fileは、インストールしたいアプリケーションのEBOOT.PBPで、この引数は必須です。
以下はオプションです。
   options:
     -o PATH    インストール先のディレクトリを指定します。
                (例 /mnt/PSP/GAME)
                省略した場合は、カレントディレクトリと見なします。

     -d DIRNAME インストール先に作成するディレクトリ名を指定します。
                省略した場合は、現在の時間をディレクトリ名にします。

     -h         ヘルプドキュメントを表示します。
                英語の成績は悪かったので多分悲惨です。見逃してください。

     -n         破損ファイル非表示を行いません。
                希に破損ファイル非表示を行うとうまく動作しない場合があるようです。

<使用例>

    perl pkx.pl -o /mnt/PSP/GAME -d Appl /here/is/install/pbp/EBOOT.PBP


=== [ ppe.pl : PBP editorの使い方 ] =======================

    perl ppe.pl [operation] Target_PBP_File

Target_PBP_Fileは、operationに依存します。この引数は必須です。
以下はオペレーションです。
    operation:
      list            Target_PBP_Fileに含まれているファイルをリストで表示します。

      help | -h       ヘルプドキュメントを表示します。
                      英語の成績は悪かったので多分悲惨です。見逃してください。

      extract CONTROL NAMEに指定されたファイルをPATHに展開します。
                      NAMEを省略した場合は、"-all"。
                      PATHを省略した場合は、カレントディレクトリと見なされます。
                      NAMEは後述。

      create CONTROL  CONTROLに従ってPBPファイルを作成します。
                      この場合、Target_PBP_FileはPBPファイルの作成場所です。
                      CONTROLは後述。

      rewrite CONTROL CONTROLに従って既存のPBPファイルの中身を差し替えます。
                      CONTROLで指定されなかったものは既存のPBPファイルのものを維持します。
                      Target_PBP_Fileは、書き換える既存のPBPを指定します。
                      CONTROLは後述。

<CONTROL>
	CONTROLではPBPファイルに使用するファイルのパスを指定します。
	以下は、各オペレーションでの動作の詳細です。
	
	[注意]
	このスクリプトは、rewrite時にオプションによっては一時ファイルを作成します。
	この作成場所は、実行したppe.plが存在するディレクトリになるため、
	ppe.plが書き込めないディレクトリに存在するとうまく動作しません。
	必ず実効ユーザで書き込み可能なディレクトリ、あるいは書き込み可能なデバイス上で使用してください。
	(そのうち一時ファイルの出力先を指定できるようにします。)
	
	create/rewrite:
		これらのオペレーションでは、PATHにHTTP-URIを指定することもできます。
        PATHが「http://」から開始されている場合は、HTTP-URIと見なしてダウンロードを試みます。
		ダウンロードされた一時ファイルは使用後に自動的に削除されます。
        (-o CONTROLには、いかなる場合もHTTP-URIは指定できません。)
    extract:
        PATHにはファイルを展開するローカルファイルパスを指定します。
        HTTP-URIは指定できません。
	
    CONTROL:
      -p PATH  PARAM.SFO    PBPメタデータファイル。
      -m PATH  ICON0.PNG    メインアイコンファイル。
      -a PATH  ICON1.PMF    アニメーションアイコンファイル。
      -f PATH  PIC0.PNG     フロート背景画像。
      -b PATH  PIC1.PNG     背景画像。
      -s PATH  SND0.AT3     BGMファイル。
      -0 PATH  DATA.PSP
      -1 PATH  DATA.PSAR

    ( rewriteオペレーションでは PATH に対して "none" を指定するとそのファイルを取り除きます )

    以下のCONTROLはrewrite/extractオペレーションでのみ使用できます。
    オペレーションによって、若干意味が変わります。
      -o PATH  出力ディレクトリを指定。
               rewrite:
                 ファイルパスを指定します。そのパスへファイルを書き出します。
                 (デフォルトでは、Target_PBP_Fileに上書きされます)
               extract:
                 ディレクトリパスを指定します。そのパスへ全てのファイルを展開します。
                 (このオプションがある場合、他のオプションは全て無視されます)

<使用例>
	例えば、とあるEBOOT.PBPを自分のホームディレクトリに展開するには以下のようにします。

	    * すべて展開
	    ppe.pl extract -o /here/is/your/home /here/is/any/EBOOT.PBP

	特定のファイルのみを展開する場合は、展開先のパスをファイル名まで含めて指定します。

	    * ICON0.PNGのみ展開
	    ppe.pl extract -m /here/is/your/home/ICON0.PNG /here/is/any/EBOOT.PBP

	    * ICON0.PNGとPIC1.PNGの二つを展開
	    ppe.pl extract -m /here/is/your/home/ICON0.PNG -b /here/is/your/home/PIC0.PNG /here/is/any/EBOOT.PBP

	カレントディレクトリに展開する場合は、単に出力先を指定しないようにすることでもできます。

	    * すべて展開
	    ppe.pl extract /here/is/any/EBOOT.PBP
	    ppe.pl extract -o /here/is/any/EBOOT.PBP

	    * ICON0.PNGとPIC1.PNGの二つを展開
	    ppe.pl extract -m -b /here/is/any/EBOOT.PBP

	あるEBOOT.PBPの中身を差し替えるには以下のようにします。

	    * ICON0.PNGを変更する
	    ppe.pl rewrite -m /here/is/spec/ICON0.PNG /here/is/any/EBOOT.PBP

	    * ICON0.PNGとPIC1.PNGを変更する
	    ppe.pl rewrite -m /here/is/spec/ICON0.PNG -b /here/is/spec/PIC0.PNG /here/is/any/EBOOT.PBP

	    * SND0.AT3を取り除く
	    ppe.pl rewrite -s none /here/is/any/EBOOT.PBP

		* ICON0.PNGをとあるWebサーバ上にあるファイルに差し替える
		ppe.pl rewrite -m http://www.example.com/image/ICON0.PNG /here/is/any/EBOOT.PBP

=== [履歴] ================================================
2006/03/31
  ppe.pl 1.2.1:
    -create/rewriteで、エラーで処理が中断された際に一時ファイルが残留する現象を修正。

2006/03/30
  ppe.pl 1.2.0:
    -create/rewriteで、HTTP-URIを指定できるようにした。
  PSP::PBPh     1.1.0
  PSP::PBPMaker 1.0.1

2006/03/14
  pkx.pl 2.0.2:
    -前回の修正で更に発生したバグの修正。
  ppe.pl 1.1.1:
    -KXploit済みのEBOOT.PBPに対して操作しようとすると破損ファイルになってしまうのを修正。
    -rewriteの-oオプションを変更。
    -extract専用のオプションを廃止。
    -extractの引数を、create/rewriteの引数と統一。

2006/03/13
  pkx.pl 2.0.1:
    -KXploit変換に失敗する場合があるのを修正。

2006/03/12
  pkx.pl         2.0.0
  ppe.pl         1.0.0
  PSP::PBPh      1.0.0
  PSP::PBPMaker  1.0.0
  PSP::PBPParser 1.0.0

2006/03/09
  pkx.pl 1.0.0