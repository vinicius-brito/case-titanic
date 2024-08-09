# Case Titanic

Repositório com a solução para o case do Titanic para a vaga de Engenheiro de Software no time de Dados PRG - Itaú.

## Descrição do Projeto

Este projeto implementa uma API para prever a probabilidade de sobrevivência de passageiros do Titanic usando um modelo de Machine Learning. A API é construída utilizando infraestrutura como código (IaC) com Terraform e serviços da AWS, incluindo API Gateway, Lambda e DynamoDB.

### Funcionalidades

- **POST /sobreviventes**: Recebe um JSON com um array de características e retorna a probabilidade de sobrevivência do passageiro junto com o ID do passageiro.
- **GET /sobreviventes**: Retorna uma lista de passageiros que já foram avaliados.
- **GET /sobreviventes/{id}**: Retorna a probabilidade de sobrevivência do passageiro com o ID informado.
- **DELETE /sobreviventes/{id}**: Deleta o passageiro com o ID informado.

### Estrutura do Repositório

- `/modelo/model.pkl`: Modelo de Machine Learning treinado.
- `/terraform`: Arquivos de configuração do Terraform para provisionar a infraestrutura.
- `/lambda`: Código da função Lambda em Python.
- `openapi.yaml`: Especificação do contrato OpenAPI 3.0.

## Instruções para Configuração e Execução

### Pré-requisitos

- [Terraform](https://www.terraform.io/downloads.html) instalado.
- [AWS CLI](https://aws.amazon.com/cli/) configurado com as credenciais apropriadas.
- [Python 3.8.18](https://www.python.org/downloads/) instalado.

### Passos para Iniciar o Terraform

1. Clone o repositório:
    ```sh
    git clone <URL_DO_REPOSITORIO>
    cd <NOME_DO_REPOSITORIO>
    ```

2. Inicialize o Terraform:
    ```sh
    terraform init
    ```

3. Planeje a infraestrutura:
    ```sh
    terraform plan
    ```

4. Aplique a infraestrutura:
    ```sh
    terraform apply
    ```

### Executando a Aplicação

1. Faça o deploy da função Lambda:
    ```sh
    cd lambda
    zip -r function.zip .
    aws lambda update-function-code --function-name <NOME_DA_FUNCAO> --zip-file fileb://function.zip
    ```

2. Verifique se a API Gateway está configurada corretamente e obtenha a URL base da API.

3. Utilize ferramentas como [Postman](https://www.postman.com/) ou [curl](https://curl.se/) para testar os endpoints da API.

### Observações

- Certifique-se de que as permissões do IAM estão configuradas corretamente para permitir que o Terraform crie os recursos necessários.
- O DynamoDB não será provisionado automaticamente devido ao baixo volume de requisições esperado.

## Prazo de Entrega

Você possui o prazo de 7 dias corridos para entrega do case, uma vez recebido o link para este repositório.