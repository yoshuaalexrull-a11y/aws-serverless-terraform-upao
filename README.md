# AWS Serverless Architecture with Terraform (UPAO)

Este proyecto implementa una arquitectura serverless escalable y segura en AWS utilizando **Terraform**. Se enfoca en el procesamiento de imágenes mediante eventos, integrando servicios de red, computación y mensajería.

##  Arquitectura
La infraestructura se despliega dentro de una VPC personalizada con subredes públicas y privadas en múltiples zonas de disponibilidad.

**Optimización de Costos:** Se implementaron **VPC Endpoints** (S3 Gateway e Interface SQS) para permitir la comunicación privada entre las Lambdas y los servicios de AWS sin incurrir en los costos por hora de un NAT Gateway.

### Tecnologías Utilizadas
-Infraestructura: Terraform (v5.0+)

-Nube: AWS (Región us-east-1)

-Computación: AWS Lambda (Node.js 20.x)

-Mensajería: Amazon SQS (Standard + DLQ)

-Almacenamiento: Amazon S3

-API: API Gateway (HTTP API v2)

### Instrucciones de Despliegue
Inicializar el proyecto:

-terraform init

### Gestión de Entornos (Workspaces):

Este proyecto utiliza workspaces para separar los entornos de dev, qa y prod.

-terraform workspace new dev

### Despliegue para los entornos:

-terraform apply -var="environment=dev" -auto-approve

### Limpieza (Destrucción):
Para evitar costos innecesarios, destruya el entorno al finalizar:

-terraform destroy -var="environment=dev" -auto-approve

##  Autor
-Josué Ruiz Ulloa
