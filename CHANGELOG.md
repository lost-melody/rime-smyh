# Wafel-into Changelog

## 提示

> 每次編碼更新後, 相關智能詞可能受影響.
    可執行 `/smart` 先清空再重新載入, 載入的詞典文件在 `smyh.smart.txt`.

> 使用 `/addsmart` 和 `/delsmart` 可以增删詞組.
    例如對於編碼 `fmx`, 其三選爲「踽」.
    使用 `/addsmart/fmx3/fmx3` 可添加「fmxfmx踽踽」詞組,
    而用 `/delsmart/fmxfmx` 可再删除之.

## 更新日誌

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
