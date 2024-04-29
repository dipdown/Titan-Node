#!/bin/bash
echo "--------------------------- Konfigurasi Server ---------------------------"
echo "Jumlah Core CPU: " $(nproc --all) "CORE"
echo -n "Kapasitas RAM: " && free -h | awk '/Mem/ {sub(/Gi/, " GB", $2); print $2}'
echo "Kapasitas Penyimpanan:" $(df -B 1G --total | awk '/total/ {print $2}' | tail -n 1) "GB"
echo "------------------------------------------------------------------------"


echo "--------------------------- BASH SHELL TITAN ---------------------------"
# Dapatkan nilai hash dari terminal
echo "Masukkan kode Hash Anda (Kode identitas): "
read hash_value

# Periksa jika hash_value adalah string kosong (pengguna hanya menekan Enter), maka hentikan program
if [ -z "$hash_value" ]; then
    echo "Tidak ada nilai hash yang dimasukkan. Menghentikan program."
    exit 1
fi


read -p "Masukkan jumlah core CPU (default adalah 1 CORE): " cpu_core
cpu_core=${cpu_core:-1}

read -p "Masukkan kapasitas RAM (default adalah 2 GB): " memory_size
memory_size=${memory_size:-2}

read -p "Masukkan kapasitas penyimpanan (default adalah 72 GB): " storage_size
storage_size=${storage_size:-72}


service_content="
[Unit]
Description=Titan Node
After=network.target
StartLimitIntervalSec=0

[Service]
User=root
ExecStart=/usr/local/titan/titan-edge daemon start
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
"

sudo apt-get update
sudo apt-get install -y nano

wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.16/titan_v0.1.16_linux_amd64.tar.gz

sudo tar -xf titan_v0.1.16_linux_amd64.tar.gz -C /usr/local

sudo mv /usr/local/titan_v0.1.16_linux_amd64 /usr/local/titan

rm titan_v0.1.16_linux_amd64.tar.gz


if [ ! -f ~/.bash_profile ]; then
    echo 'export PATH=$PATH:/usr/local/titan' >> ~/.bash_profile
    source ~/.bash_profile
elif ! grep -q '/usr/local/titan' ~/.bash_profile; then
    echo 'export PATH=$PATH:/usr/local/titan' >> ~/.bash_profile
    source ~/.bash_profile
fi

# Jalankan titan-edge daemon di latar belakang
(titan-edge daemon start --init --url https://test-locator.titannet.io:5000/rpc/v0 &) &
daemon_pid=$!

echo "PID dari titan-edge daemon: $daemon_pid"

# Tunggu selama 10 detik untuk memastikan daemon telah berhasil dimulai
sleep 15

# Jalankan titan-edge bind di latar belakang
(titan-edge bind --hash="$hash_value" https://api-test1.container1.titannet.io/api/v2/device/binding &) &
bind_pid=$!

echo "PID dari titan-edge bind: $bind_pid"

# Tunggu proses bind selesai
wait $bind_pid

sleep 15

# Lakukan pengaturan lainnya

config_file="/root/.titanedge/config.toml"
if [ -f "$config_file" ]; then
    sed -i "s/#StorageGB = 2/StorageGB = $storage_size/" "$config_file"
    echo "Kapasitas penyimpanan basis data telah diubah menjadi $storage_size GB."
    sed -i "s/#MemoryGB = 1/MemoryGB = $memory_size/" "$config_file"
    echo "Kapasitas memory telah diubah menjadi $memory_size GB."
    sed -i "s/#Cores = 1/Cores = $cpu_core/" "$config_file"
    echo "Jumlah core CPU telah diubah menjadi $cpu_core Core."
else
    echo "Error: File konfigurasi $config_file tidak ditemukan."
fi

echo "$service_content" | sudo tee /etc/systemd/system/titand.service > /dev/null

# Hentikan proses yang terkait dengan titan-edge
pkill titan-edge

# Muat ulang systemd
sudo systemctl daemon-reload

# Aktifkan dan mulai titand.service
sudo systemctl enable titand.service
sudo systemctl start titand.service

sleep 8
# Tampilkan informasi dan konfigurasi titan-edge
sudo systemctl status titand.service && titan-edge config show && titan-edge info

echo "==============================Semua Node Sudah Diatur dan Dimulai===================================."
