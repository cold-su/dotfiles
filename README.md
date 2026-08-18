# dotfiles

```bash
git clone https://github.com/cold-su/dotfiles.git --recurse-submodules
cd ./dotfiles
./quick_start.sh
```
## ly

[黑洞]

将[黑洞]文件放到 `/etc/ly/` 中并修改 `config.ini`，参考下面（实际文件中这三行没有看起来那么近，善用搜索）：
```ini
animate = true
animation = dur_file
dur_file_path = /etc/ly/blackhole-smooth-240x67.dur
```


## dwl

有一个 `config.h` 文件，是 dwl 的配置文件。

复制到 dwl 源码目录后 make 即可。

[黑洞]: https://codeberg.org/fairyglade/ly-community/src/branch/main/animations/dur/blackhole-smooth-240x67.dur
