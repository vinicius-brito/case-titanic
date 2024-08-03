#!/bin/bash

# Variáveis
REPOSITORY_NAME="case_itau"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TAG="v10"
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPOSITORY_NAME}:${TAG}"

# Criar repositório ECR se não existir
aws ecr describe-repositories --repository-names ${REPOSITORY_NAME} --region ${REGION} > /dev/null 2>&1

if [ $? -ne 0 ]; then
  aws ecr create-repository --repository-name ${REPOSITORY_NAME} --region ${REGION}
  echo "Repositório ECR ${REPOSITORY_NAME} criado."
else
  echo "Repositório ECR ${REPOSITORY_NAME} já existe."
fi

# Login no ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# Construir a imagem Docker
docker build -t ${REPOSITORY_NAME} .

# Taggear a imagem Docker
docker tag ${REPOSITORY_NAME}:latest ${IMAGE_URI}

# Fazer push da imagem para o ECR
docker push ${IMAGE_URI}

# Exibir a URL da imagem
echo "Imagem Docker enviada para: ${IMAGE_URI}"