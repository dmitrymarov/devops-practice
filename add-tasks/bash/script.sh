#!/bin/bash

set -euo pipefail

input_file="$1"
output_file="a.out"
word_for_search="testbash"
new_user="new_user"
system_prop="system.out"

grep "$word_for_search" "$input_file" | tee "$output_file"
line_count=$(wc -l < "$output_file")

echo -e "\nНайдено строк: $line_count" | tee -a "$output_file"

create_user() { 
    if id "$new_user" &>/dev/null; then
        echo "Пользователь $new_user уже существует и будет удален!!!"
        sudo userdel -rf "$new_user" 2>/dev/null
    fi
    sudo useradd -m -s /bin/bash "$new_user"
    echo "$new_user:pass" | sudo chpasswd
    sudo usermod -aG sudo "$new_user"
    echo "$new_user ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$new_user" >/dev/null
    sudo chmod 0440 "/etc/sudoers.d/$new_user"
    echo "Пользователь $new_user успешно создан и настроен."
    sudo id "$new_user"
}

create_user
sudo lshw > "$system_prop"
echo "
----------------------------
             CPU
----------------------------
" >> "$system_prop"
sudo lscpu >> "$system_prop"
echo "
-----------------------------
            MEMORY 
-----------------------------
" >> "$system_prop"
sudo free -h >> "$system_prop"
echo "
-----------------------------
            VOLUMES 
-----------------------------
" >> "$system_prop"
sudo df -h >> "$system_prop"
echo "
-----------------------------
            SYSTEM 
-----------------------------
" >> "$system_prop"
sudo uname -a >> "$system_prop"
echo "
-----------------------------
            NETWORK 
-----------------------------
" >> "$system_prop"
sudo ip a >> "$system_prop"
