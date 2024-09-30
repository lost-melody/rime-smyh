# Wafel Changelog

## 提示

> 每次編碼更新後, 相關智能詞可能受影響.
    可執行 `/smart` 先清空再重新載入, 載入的詞典文件在 `smyh.smart.txt`.

> 使用 `/addsmart` 和 `/delsmart` 可以增删詞組.
    例如對於編碼 `fmx`, 其三選爲「踽」.
    使用 `/addsmart/fmx3/fmx3` 可添加「fmxfmx踽踽」詞組,
    而用 `/delsmart/fmxfmx` 可再删除之.

## 更新日誌

### 雞蛋餅 2024-10-01 更新:

- 字根調整:
    - `隶 (Sl->Rl)`: 影響 `逮`, `康`, `慷` 等.
    - `㔾 (Vv->Kj)`: 影響 `仓`, `卷`, `宛`, `厄`, `卮` 等.
- 移除字根 `龜 (Em)`, 設 `<龜中> (Jv)`:
    - `龜` 拆作 `丿<龜中>彐彐コ乂`.
- 新增字根:
    - `正 (Lz)`: 影響 `整`, `征`, `焉` 等.
    - `曲 (Hq)`: 影響 `豊`, `農` 等.
    - `页 (Ei)`, `頁 (Gi)`: 影響 `颤顫`, `颐頤`, `领領`, `嚣囂` 等.
    - `<曹上> (Rv)`: 影響 `曹`, `嘈`, `遭` 等.
    - `<南下> (Hy)`: 影響 `南`, `丵`, `凿`, `幸` 等.
    - `<亜下> (Qy)`: 影響 `亜`, `壷` 等.
    - `<曾中> (Jz)`: 影響 `曾`, `蹭` 等.
    - `<奐上> (Pv)`: 影響 `奐`, `換`, `煥` 等.
- 除以上字根變動外, 還有以下拆分調整:
    - `匹` 由 `兀乚` 改爲 `匚儿`.
- 訪問 [宇浩輸入法 - 更新日誌](https://shurufa.app/docs/updates.html#_2024-%E5%B9%B4-9-%E6%9C%88-17-%E6%97%A5-%E7%94%B2%E8%BE%B0%E5%B9%B4%E5%85%AB%E6%9C%88%E5%8D%81%E4%BA%94%E6%97%A5) 查看詳細拆分變更.

### 雞蛋餅 2024-05-27 更新:

- 新增字根 `隶 (Sl)`, 受影響常用字爲 `隶逮康慷` 等.
- 修正 *README* 方案發佈頁鏈接.
- 修正 `smyh.custom` 主頁鏈接.
- 修復 `smyh.custom` 錯誤的開關引用索引.

### 雞蛋餅 2024-03-24 更新:

- 主要拆分調整:
    - `亚 = 一业`, `严 = 一业丿`
    - `垂 = 千龷一`, `華 = 艹<冓上>十`
- 增補一些漢字的拼音註解, 如 `丬`, `龶` 等.

### 雞蛋餅 2023-01-31 更新:

- 移除 `smyh_tc` 方案文件, 移除 `/trad` 命令.
- 文件名調整:
    - `smyh.yuhaofull.dict.yaml` -> `smyh.full.dict.yaml`.
    - `smyh.yuhaowords.dict.yaml` -> `smyh.yuhaowords.dict.yaml`.
    - `smyh.yuhaowords.schema.yaml` -> `smyh.yuhaowords.schema.yaml`.

### 雞蛋餅 2023-12-28 更新:

- 主要拆分調整:
    - `丝 = <纟上><纟上>一`.
    - `卞 = 丶下`.
    - `垂 = 千龷一`.
    - `華 = 艹一龷十`.
- 大字集錯碼修正若幹.

### 雞蛋餅 2023-12-06 更新:

- 爲 `ascii_mode` 增加狀態描述, 以便在 `Hamster` 中正確顯示中文切換狀態.
- 增加 *IVD (異體字選擇器)* 功能, 當前僅附帶了 *Moji Joho* 異體字數據.
    - 功能通過上屏歷史實現, 需要先打出原字. 例如先打出 `丑` 字, 再按下 `grave` 鍵, 卽可選擇其相關的異體字.
    - 需要配合相應字體查看效果, 普通用户無須關注.
    - 異體字數據來源於 [Unicode IVD](https://www.unicode.org/ivd/).

### 雞蛋餅 2023-11-24 更新:

- *Lua* 中對 `LevelDb` 詞典的調取作出修正, 優先使用 `LevebDB(db_name)`, 當發生錯誤時再嘗試 `LevelDb(db_path, db_name)`.

### 雞蛋餅 2023-11-17 更新:

- 調整「禹」字拆分：「丿虫冂」→「丿口冂丄」.
- 受影響的漢字：「属」「禹」及其組合「瞩」「龋」等.

### 雞蛋餅 2023-11-15 更新:

- `yuhao_pinyin.{dict,schema}.yaml` 重命名为 `smyh.pinyin.{dict,schema}.yaml`.
- 增加 `default.custom.yaml`, 请注意覆盖.
- 移除无用文件 `symbols_yuhao.yaml`.
- `mappings_table.txt` 更名为 `smyh.mappings_table.txt`.
- *吉旦饼·Into* 成为主要维护版, 并已加入「仓输入法」开源方案列表.

### 雞蛋餅 2023-11-13 更新:

- 拆分變化：新增字根「甶」「鬼-厶」作爲「鬼」的附屬根, GBK範圍内僅影響「甶」字；

![wafel1113a.png](https://i.postimg.cc/TPXKrc8m/wafel1113a.png)
![wafel1113b.png](https://i.postimg.cc/6pxWS5Hx/wafel1113b.png)
