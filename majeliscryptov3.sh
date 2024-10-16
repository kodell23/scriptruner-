#!/bin/bash
# MyScripts.sh - Peluncur script untuk mengelola script bot Telegram langsung di Termux atau Tmux

# Mendefinisikan path lengkap ke file scripts.txt relatif terhadap lokasi script
SCRIPT_FILE="$(pwd)/scripts.txt"

# Inisialisasi file script jika belum ada
if [[ ! -f "$SCRIPT_FILE" ]]; then
  echo "Membuat 'scripts.txt'..."
  touch "$SCRIPT_FILE"
  echo "'scripts.txt' telah dibuat."
else
  echo "'scripts.txt' ditemukan. Melanjutkan..."
fi

# Fungsi untuk mengonversi angka menjadi huruf kecil (1 -> a, 2 -> b, dst.)
number_to_letter() {
  local num=$1
  printf "\\$(printf '%03o' $((96 + num)))"
}

# Fungsi untuk menampilkan script
display_scripts() {
  echo "Pilih opsi:"
  echo

  i=1  # Inisialisasi penomoran untuk script

  # Periksa apakah scripts.txt kosong
  if [[ ! -s "$SCRIPT_FILE" ]]; then
    echo "Tidak ada script yang tersedia. Tambahkan script baru terlebih dahulu."
    echo  # Tetap menampilkan opsi di bawah
  else
    while IFS=: read -r path name; do
      echo -e "\033[1;33m$i\033[0m. Jalankan $name"  # Nomor script dalam warna kuning
      i=$((i + 1))
    done < "$SCRIPT_FILE"
  fi

  # Menggunakan huruf untuk opsi lainnya (a, b, c, dst.)
  letter=1
  echo  # Baris kosong untuk spasi
  echo -e "\033[1;32m$(number_to_letter $letter)\033[0m. Tambah Script Baru"  # Tambah Script Baru
  letter=$((letter + 1))
  echo -e "\033[1;32m$(number_to_letter $letter)\033[0m. Hapus Script"        # Hapus Script
  letter=$((letter + 1))
  echo -e "\033[1;32m$(number_to_letter $letter)\033[0m. Hapus Semua Script"   # Hapus Semua Script
  letter=$((letter + 1))
  echo -e "\033[1;32m$(number_to_letter $letter)\033[0m. Keluar"               # Keluar
  echo
}

# Fungsi untuk menjalankan script di Termux
start_script_termux() {
  local path="$1"
  local extension="${path##*.}"
  local script_dir
  local script_name
  script_dir=$(dirname "$path")
  script_name=$(basename "$path")

  echo "Mencoba berpindah ke direktori: $script_dir"

  if ! cd "$script_dir"; then
    echo "Gagal berpindah ke direktori $script_dir. Periksa apakah path sudah benar."
    return
  fi

  clear  # Bersihkan layar sebelum menjalankan script

  case "$extension" in
    py)
      python3 "$script_name"
      ;;
    js)
      node "$script_name"
      ;;
    *)
      echo "Jenis script tidak didukung: $path"
      ;;
  esac

  read -p "Script selesai. Tekan Enter untuk kembali ke menu..."
}

# Fungsi untuk menjalankan script di Tmux
start_script_tmux() {
  local path="$1"
  local script_name=$(basename "$path")
  local script_dir=$(dirname "$path")
  local extension="${path##*.}"

  # Buat sesi tmux baru jika belum ada
  if ! tmux has-session -t mysession 2>/dev/null; then
    tmux new-session -d -s mysession
  fi

  # Jalankan script di jendela baru dalam sesi tmux
  tmux new-window -t mysession -n "$script_name" "cd $script_dir; bash -c 'case \"$extension\" in py) python3 \"$script_name\" ;; js) node \"$script_name\" ;; *) echo \"Jenis script tidak didukung: $path\" ;; esac; read -p \"Script selesai. Tekan Enter untuk menutup jendela...\"'"

  echo "Script dijalankan di jendela Tmux baru bernama '$script_name'."
  read -p "Tekan Enter untuk kembali ke menu..."
}

# Fungsi untuk menambahkan script baru
add_new_script() {
  echo
  echo -e "\033[1;92mMasukkan path lengkap script:\033[0m "
  read -p "" new_path
  if [[ ! -f "$new_path" ]]; then
    echo "File script tidak ditemukan pada path yang diberikan."
    read -p "Tekan Enter untuk melanjutkan..."
    return
  fi
  echo -e "\033[1;92mMasukkan nama untuk script ini:\033[0m "
  read -p "" new_name
  if grep -q ":$new_name$" "$SCRIPT_FILE"; then
    echo "Script dengan nama ini sudah ada."
    read -p "Tekan Enter untuk melanjutkan..."
    return
  fi
  echo "$new_path:$new_name" >> "$SCRIPT_FILE"
  echo "Script berhasil ditambahkan."
  read -p "Tekan Enter untuk melanjutkan..."
}

# Fungsi untuk menghapus script tertentu
delete_script() {
  if [[ ! -s "$SCRIPT_FILE" ]]; then
    echo "Tidak ada script yang tersedia untuk dihapus."
    read -p "Tekan Enter untuk melanjutkan..."
    return
  fi

  echo
  echo "Pilih script untuk dihapus:"
  echo
  i=1
  declare -a scripts
  while IFS=: read -r path name; do
    echo -e "\033[1;33m$i\033[0m. $name"
    scripts+=("$path:$name")
    i=$((i + 1))
  done < "$SCRIPT_FILE"
  echo
  echo -e "\033[1;92mMasukkan nomor script yang akan dihapus:\033[0m "
  read -p "" del_choice
  echo

  if [[ "$del_choice" =~ ^[0-9]+$ ]] && [[ "$del_choice" -ge 1 && "$del_choice" -le "${#scripts[@]}" ]]; then
    selected="${scripts[$((del_choice - 1))]}"
    selected_path=$(echo "$selected" | cut -d: -f1)
    selected_name=$(echo "$selected" | cut -d: -f2)
    extension="${selected_path##*.}"
    script_name=$(basename "$selected_path")

    case "$extension" in
      py|js)
        pkill -f "$script_name"
        echo "Berhenti '$script_name'."
        ;;
    esac

    sed -i "${del_choice}d" "$SCRIPT_FILE"
    echo "Script '$selected_name' berhasil dihapus."
  else
    echo "Pilihan tidak valid. Kembali ke menu."
  fi
  echo
  read -p "Tekan Enter untuk melanjutkan..."
}

# Fungsi untuk menghapus semua script
delete_all_scripts() {
  echo
  echo -e "\033[1;92mApakah Anda yakin ingin menghapus semua script? (y/n):\033[0m "
  read -p "" confirm
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    > "$SCRIPT_FILE"
    echo "Semua script telah dihapus."
  else
    echo "Operasi dibatalkan."
  fi
  read -p "Tekan Enter untuk melanjutkan..."
}

# Fungsi untuk menampilkan ASCII art menggunakan figlet dengan gradien hijau dan pesan khusus
display_ascii_art() {
  if ! command -v figlet &> /dev/null; then
    echo "figlet tidak terpasang. Silakan pasang untuk melihat ASCII art."
    echo
    return
  fi

  echo -e "\033[1;32m$(figlet -f slant 'Majelis')\033[0m"
  echo -e "\033[1;92m$(figlet -f slant 'Crypto')\033[0m"
  echo -e "\033[1;92mScript ini di Buat Oleh ChatGPT\033[0m"
  echo
}

# Loop utama
while true; do
  clear
  display_ascii_art
  display_scripts
  read -p "Masukkan pilihan Anda: " choice

  num_scripts=$(wc -l < "$SCRIPT_FILE")
  num_scripts=$((num_scripts + 0))

  echo

  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    if [[ "$choice" -ge 1 && "$choice" -le "$num_scripts" ]]; then
      script_entry=$(sed -n "${choice}p" "$SCRIPT_FILE")
      script_path=$(echo "$script_entry" | cut -d: -f1)
      script_name=$(echo "$script_entry" | cut -d: -f2)

      # Memilih mode eksekusi (Termux atau Tmux)
      echo -e "\033[1;92mPilih mode eksekusi untuk $script_name:\033[0m"
      echo "1. Jalankan di Termux"
      echo "2. Jalankan di Tmux"
      read -p "Masukkan pilihan Anda (1/2): " mode_choice

      case "$mode_choice" in
        1)
          start_script_termux "$script_path"
          ;;
        2)
          if ! command -v tmux &> /dev/null; then
            echo "Tmux tidak terpasang. Silakan pasang Tmux untuk menggunakan mode ini."
            read -p "Tekan Enter untuk melanjutkan..."
          else
            start_script_tmux "$script_path"
          fi
          ;;
        *)
          echo "Pilihan mode tidak valid."
          read -p "Tekan Enter untuk kembali ke menu..."
          ;;
      esac
    else
      echo "Pilihan tidak valid. Silakan coba lagi."
      sleep 2
    fi
  elif [[ "$choice" =~ ^[a-zA-Z]$ ]]; then
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
    case "$choice" in
      a)
        add_new_script
        ;;
      b)
        delete_script
        ;;
      c)
        delete_all_scripts
        ;;
      d)
        echo "Keluar..."
        exec bash  # Menjaga terminal tetap terbuka
        ;;
      *)
        echo "Pilihan tidak valid. Silakan coba lagi."
        sleep 2
        ;;
    esac
  else
    echo "Input tidak valid. Masukkan angka atau huruf."
    sleep 2
  fi
done
