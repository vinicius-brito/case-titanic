#!/bin/bash

# Executa o script build_and_push.sh
./build_and_push.sh

# Verifica se o build_and_push.sh foi executado com sucesso
if [ $? -ne 0 ]; then
  echo "Erro ao executar build_and_push.sh. Abortando o deploy."
  exit 1
fi

# Executa o terraform apply
terraform apply -auto-approve

# Verifica se o terraform apply foi executado com sucesso
if [ $? -ne 0 ]; then
  echo "Erro ao executar terraform apply. Verifique os logs para mais detalhes."
  exit 1
fi

echo "Deploy concluído com sucesso."