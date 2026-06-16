#!/bin/bash

echo "[*] Procurando imagens com chaves {} no nome..."
find . -type f -name "*{*}*" | while read file; do
    
    dir=$(dirname "$file")
    old_name=$(basename "$file")
    new_name=$(echo "$old_name" | tr -d '{}')
    
    mv "$file" "$dir/$new_name"
    find . -type f -name "*.md" -exec perl -pi -e "s/\Q$old_name\E/$new_name/g" {} +
    echo "[+] Corrigido: $old_name -> $new_name"
done

echo "[*] Limpeza concluída! Tudo pronto para o deploy."
