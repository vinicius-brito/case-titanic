# Titanic Case

Repository with the solution for the Titanic case for the Software Engineer vacancy in the PRG Data Team - Itaú.

## Project Description

This project implements an API to predict the survival probability of Titanic passengers using a Machine Learning model. The API is built using Infrastructure as Code (IaC) with Terraform and AWS services, including API Gateway, Lambda and DynamoDB.

### Functionalities

- **POST /sobreviventes**: Receives a JSON with an array of characteristics and returns the passenger's survival probability along with the passenger ID.
- **GET /sobreviventes**: Returns a list of passengers who have already been evaluated. No pagination.
- **GET /sobreviventes/{id}**: Returns the survival probability of the passenger with the given ID.
- **DELETE /sobreviventes/{id}**: Deletes the passenger with the given ID.

### Repository Structure

- `/code/tmp/model.pkl`: Trained Machine Learning model.
- `main.tf`: Terraform configuration file to provision infrastructure.
- `/code`: FastAPI application directory.
- `openapi.json`: OpenAPI 3.1.0 contract specification.

## Setup and Run Instructions

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) installed.
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials.
- [Docker](https://www.docker.com/) installed.
- [Python 3.8](https://www.python.org/downloads/) installed.

### Steps to Deploy

1. Clone the repository:
```sh
git clone https://github.com/vinicius-brito/case-titanic.git
cd case-titanic
```

2. Initialize Terraform:
```sh
terraform init
```

3. Plan the infrastructure:
```sh
terraform plan
```

4. Apply the infrastructure:
```sh
terraform apply
```

### Using the Application

1. Following the steps described above, capture the lambda function url and the API url (API Gateway).

2. Verify that the API Gateway is properly deployed (dev).

3. Use tools such as [Postman](https://www.postman.com/) or [curl](https://curl.se/) to test the API endpoints.

4. To access the project's Swagger, you can access the path <lambda_url>/docs.
