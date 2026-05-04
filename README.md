# Architecture - AWS server with Terraform (UPAO)

Este proyecto implementa una arquitectura - escalable y segura en AWS utilizando Terraform. Se enfoca en el procesamiento de imágenes mediante eventos, integrando servicios de red, computación y mensajería.

## Arquitectura

La infraestructura se despliega dentro de una VPC personalizada con subredes públicas y privadas distribuidas en múltiples zonas de disponibilidad para garantizar alta disponibilidad. 

Para cumplir con los estándares de seguridad y el diseño establecido:
*   **NAT Gateways:** Se implementaron con IPs elásticas en las subredes públicas para permitir la salida segura a internet desde las subredes privadas.
*   **VPC Endpoints:** Se configuraron Endpoints (S3 Gateway e Interface SQS) para asegurar que la comunicación entre las funciones Lambda y los servicios de almacenamiento/mensajería se realice de forma privada a través de la red troncal de AWS, sin exponer los datos al internet público.

## Tecnologías Utilizadas

*   **Infraestructura:** Terraform (v5.0+)
*   **Nube:** AWS (Región us-east-1)
*   **Computación:** AWS Lambda (Node.js 20.x)
*   **Mensajería:** Amazon SQS (Standard + DLQ)
*   **Almacenamiento:** Amazon S3
*   **API:** API Gateway (HTTP API v2)

## Instrucciones de Despliegue:
### Pre-requisitos (Configuración Inicial)
Antes de desplegar la infraestructura, asegúrese de contar con las siguientes herramientas instaladas en su entorno local:
1.  **AWS CLI:** [Guía de instalación](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
2.  **Terraform:** (v5.0 o superior) [Guía de instalación](https://developer.hashicorp.com/terraform/downloads)

Una vez instaladas, configure sus credenciales de acceso a AWS ejecutando:
- aws configure
## Pasos de Despliegue

**1. Inicializar el proyecto:**
Descarga los proveedores (plugins) necesarios para que Terraform interactúe con AWS.
- terraform init

**2. Gestión de Entornos (Workspaces):**
Este proyecto utiliza workspaces para separar los entornos de desarrollo, pruebas y producción. Cree el entorno deseado:
- terraform workspace new dev
- terraform workspace new qa
- terraform workspace new prod

**3. Despliegue de la Infraestructura:**
Ejecute la planificación y aplicación de los recursos en la nube.
- terraform apply -var="environment=dev" -auto-approve
- terraform apply -var="environment=qa" -auto-approve
- terraform apply -var="environment=prod" -auto-approve

**4. Limpieza (Destrucción):**
Para evitar facturación innecesaria (especialmente por los NAT Gateways), asegúrese de destruir el entorno al finalizar las pruebas de la universidad:
- terraform destroy -var="environment=dev" -auto-approve
- terraform destroy -var="environment=qa" -auto-approve
- terraform destroy -var="environment=prod" -auto-approve
