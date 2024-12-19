可以构建的架构
- `linux/riscv64`


有问题的 
- `linux/arm/v7(需要加入 linux-armv4 进行编译)` [问题连接](https://github.com/openssl/openssl/issues/21630)`


https://github.com/just-containers/s6-overlay/issues/501


# 支持架构

- i686-linux-gnu

- s390x-ibm-linux-gnu

- powerpc64le-unknown-linux-gnu

- riscv64-unknown-linux-gnu

- armv7l-unknown-linux-gnueabihf

- aarch64-unknown-linux-gnu

- x86_64-pc-linux-gnu

# aria2 依赖包

Libraries: zlib/1.3.1 expat/2.6.3 sqlite3/3.46.1 OpenSSL/3.4.0 c-ares/1.34.2 libssh2/1.11.1


# 环境变量

| 变量              | 意思                       | 默认值                                        | 
|-----------------|--------------------------|--------------------------------------------|
| BT_TRACKER_CRON | 更新 bt tracker 的 cron 表达式 | 0 8 * * *                                  |
| BT_TRACKER_URLS | 获取 bt 服务器列表的 url         | https://cf.trackerslist.com/best_aria2.txt |


**注意： `BT_TRACKER_URLS` 使用 `,` 分割 url, 里面的内容只支持使用 `空行` 分割或者 `,` 分割**



# `http` 请求格式
```json
{
  "id": "base64",
  "jsonrpc": "2.0",
  "method": "aria2.changeGlobalOption",
  "params": [
    "token:12345678",
    {"bt-tracker":""}
  ]
}
```