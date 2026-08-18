# 屏蔽
sudo systemctl mask getty@tty3.service
sudo systemctl mask sddm.service
sudo systemctl mask plasmalogin.service
# 开机自启
sudo systemctl enable ly@tty3.service
# 立即启动
sudo systemctl start ly@tty3.service

