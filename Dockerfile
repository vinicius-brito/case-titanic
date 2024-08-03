FROM public.ecr.aws/lambda/python:3.8

# Copie o arquivo requirements.txt para o contêiner
COPY requirements.txt ./

# Atualize o pip
RUN pip install --upgrade pip

# Instale as dependências do requirements.txt
RUN pip install -r requirements.txt

# Defina o diretório de trabalho
WORKDIR /var/task

# Copie o arquivo lambda_handler.py para o diretório de trabalho
COPY lambda_handler.py /var/task/

# Copie o arquivo model.pkl para o diretório de trabalho
COPY model.pkl /var/task/

# Comando para iniciar o lambda_handler
CMD ["lambda_handler.lambda_handler"]
