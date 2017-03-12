# Minetest MOD: Debug helper
このMODは、MOD開発を補助するためのノードやツールを提供します。

## 注意点
MODの目的があくまで開発補助のため、下記の点にご注意ください。
-  テスト用のワールド以外ではできる限り使用しないでください。使用する場合は自己責任でお願いします。
-  通常のMODほど細かくデバッグをしていないのでエラーやバグが発生する可能性は残っています。
-  いろいろな意味で**重い**ノードやツールがあります。
-  ツールによって得られる情報がバグにより正しくない可能性があります。疑わしい場合は`minetest.log()`等を使用してチェックしてください。

## 使い方

### ItemList フォーム
`/dh`コマンドで表示されるフォームです。  
このMODによって提供されるツールは、全てレシピが存在していません。取得するためにはこのフォームのリストからアイテムを選択して `+1` `+10` `+99` のボタンを押してください。  
また、クリエイティブモードや`/giveme`コマンドを使用しても取得することができます。  

`debughelper_itemlist.conf`というファイルがWorldPathまたはModPathに存在する場合、その内容を元にリストにアイテムを追加登録します。

### Inspector
左クリックで使用することで、対象となるノードやエンティティの各種データをチェックすることができます。  
チェックできるデータの種別は以下のとおりです。
- ノード
  1. `minetest.get_meta()`で取得できるメタデータ。
  2. `minetest.registered_nodes[]から取得できるノード定義データ`
- エンティティ(ObjectRef)
  1. `get_luaentity()`で取得できるluaentityテーブルの内容
  2. 各種オブジェクトメソッドの戻り値
  3. `get_properties()`で取得できるオブジェクトプロパティの内容

### Inventory Viewer
左クリックで使用することで、対象のインベントリー内のアイテムをチェックすることができます。  
また、Shift+左クリックや空をクリックすることでプレイヤー自身のインベントリー内のアイテムをチェックすることもできます。  
主にアイテムのメタデータやwearの内容を確認するために使用します。

### Node Watcher
このツールはWallmountedタイプのノードで、貼り付けたノードのメタデータから選択したものを指定したプレイヤーの画面に表示します。  
データは1秒間隔で表示回数と共に表示されます。

### Mesecon Signal Checker
**このツールを使用するためにはMeseconsが必要です。**  
Meseconsに含まれるLightstoneと同様に、Mesecon信号がONになると光ります。  
Lightstoneとの違いはMesecon信号の受信範囲がMesecon Signal Checkerを中心とした9x9x9であることです。  
Lightstoneではチェックできない真下への信号も確認できます。

### Mesecon Signal Emitter
**このツールを使用するためにはMeseconsが必要です。**  
Meseconsに含まれるSwitchと同様に、Mesecon信号を発信します。左クリックによりON/OFFの切替えが可能です。  
発信範囲はMesecon Signal Checkerと同様の9x9x9です。

### Digilines Message Logger
**このツールを使用するためにはDigilinesが必要です。**  
Digilinesのネットワークに接続することにより、そのネットワーク内に流れるメッセージのロギングを行います。  
メッセージを受信すると音が鳴り、またノードが一時的に変化します。  
ロギングされたメッセージはフォームを開くことで確認することができます。  
またメッセージをダブルクリックすることで、そのメッセージの詳細表示を行います。  
Minetestを終了すると、ロギングされていたメッセージは全て破棄されます。
