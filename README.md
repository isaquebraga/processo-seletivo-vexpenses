# Infraestrutura AWS com Terraform: VPC, EC2, Nginx e Melhorias de Segurança

Este repositório contém um código Terraform para provisionar uma infraestrutura completa na AWS. O código cria uma VPC, uma instância EC2 rodando Debian 12, configurada automaticamente com Nginx, e implementa uma série de boas práticas de segurança. Além disso, o código foi ajustado para melhorar a segurança geral e automatizar a configuração de serviços na instância.

## Descrição Técnica do Código

### 1. **Provedor AWS**
O provedor AWS é configurado para trabalhar na região `us-east-1`. Todos os recursos criados serão provisionados nesta região.

### 2. **Variáveis de Entrada**
Duas variáveis principais são definidas:
- `projeto`: Nome do projeto (padrão: `"VExpenses"`).
- `candidato`: Nome do candidato ou usuário (padrão: `"IsaqueBraga"`).

Essas variáveis são utilizadas para gerar nomes únicos para os recursos criados, facilitando a identificação no console da AWS.

### 3. **Par de Chaves SSH**
O código cria um par de chaves SSH (usando o algoritmo RSA) para ser utilizado na instância EC2. A chave privada é exportada como output sensível para que o usuário possa acessar a instância via SSH.

- **Recurso**: `tls_private_key`
- **Tamanho da Chave**: 4096 bits (configurado para maior segurança).

### 4. **VPC (Virtual Private Cloud)**
O código cria uma VPC com as seguintes características:
- Bloco CIDR: `10.0.0.0/16`.
- DNS habilitado para a VPC, facilitando a resolução de nomes dentro da rede.
- A VPC é tagueada com o nome do projeto e do candidato.

- **Recurso**: `aws_vpc`

### 5. **Subnet**
Dentro da VPC, uma subnet é criada na zona de disponibilidade `us-east-1a`:
- Bloco CIDR: `10.0.1.0/24`.
- A subnet recebe um IP público para cada instância EC2 lançada nela.

- **Recurso**: `aws_subnet`

### 6. **Internet Gateway**
Um internet gateway é associado à VPC para permitir que instâncias dentro da VPC acessem a internet.

- **Recurso**: `aws_internet_gateway`

### 7. **Tabela de Roteamento**
Uma tabela de roteamento é configurada para a VPC, permitindo que todo o tráfego externo (`0.0.0.0/0`) seja roteado através do internet gateway.

- **Recurso**: `aws_route_table`

### 8. **Associação da Tabela de Roteamento**
A tabela de roteamento criada é associada à subnet, garantindo que todo o tráfego da subnet seja roteado através do internet gateway.

- **Recurso**: `aws_route_table_association`

### 9. **Grupo de Segurança (Security Group)**
O grupo de segurança criado permite:
- Acesso SSH (porta 22) apenas de um IP autorizado (definido pelo usuário).
- Tráfego HTTP (porta 80) de qualquer endereço IP, para permitir o acesso ao servidor Nginx.
- Todo o tráfego de saída é permitido para garantir conectividade total da instância.

- **Recurso**: `aws_security_group`

### 10. **Instância EC2**
Uma instância EC2 Debian 12 é criada com as seguintes características:
- Tipo: `t2.micro` (elegível para o nível gratuito da AWS).
- Subnet: Associada à subnet criada na VPC.
- Chave SSH: A chave pública gerada anteriormente é associada à instância.
- Configuração de disco: Um volume EBS com 30GB é configurado como disco raiz, usando o tipo `gp3` para otimizar performance.
- Script de inicialização (user_data): A instância é configurada automaticamente para instalar e iniciar o servidor Nginx.

- **Recurso**: `aws_instance`

### 11. **Outputs**
Dois outputs são configurados:
- A chave privada RSA, necessária para acessar a instância via SSH.
- O IP público da instância EC2, utilizado para acessar o servidor Nginx após a inicialização.

- **Outputs**: `private_key`, `ec2_public_ip`

## Descrição das Alterações Feitas e Resultados Esperados

### 1. **Segurança do Par de Chaves**
- **Alteração 1**: Aumentei o tamanho da chave RSA de 2048 bits para 4096 bits, garantindo uma segurança criptográfica significativamente maior.
  - **Resultado esperado**: Reduzir o risco de quebra da chave por ataques de força bruta, aumentando a segurança no acesso SSH à instância.

### 2. **Restrição de Acesso SSH**
- **Alteração 2**: Modifiquei o grupo de segurança para permitir o acesso SSH (porta 22) apenas de um endereço IP específico (definido pelo usuário).
  - **Resultado esperado**: Limitar o acesso SSH à instância EC2, mitigando a possibilidade de ataques externos.

### 3. **Automação da Instalação do Nginx**
- **Alteração 3**: Adicionei um script de inicialização (user_data) que instala e inicia o servidor Nginx automaticamente quando a instância é criada.
  - **Resultado esperado**: Automatizar a configuração do servidor, economizando tempo e garantindo que o servidor Nginx esteja funcionando imediatamente após a criação da instância.

### 4. **Aumento do Tamanho do Disco**
- **Alteração 4**: Aumentei o tamanho do volume EBS associado à instância EC2 de 20GB para 30GB.
  - **Resultado esperado**: Oferecer mais espaço em disco para armazenar logs e dados de aplicação.

### 5. **Mudança do Tipo de Volume**
- **Alteração 5**: Alterei o tipo de volume de `gp2` para `gp3`, que oferece melhor desempenho a um custo reduzido.
  - **Resultado esperado**: Melhorar a performance de IOPS do volume de armazenamento com custos operacionais mais baixos.

### 6. **Logs do Nginx no CloudWatch**
- **Alteração 6**: Configurei o envio de logs do Nginx (acesso e erro) para o AWS CloudWatch, com streams de logs separados para facilitar o monitoramento.
  - **Resultado esperado**: Melhorar a visibilidade e o monitoramento da aplicação, permitindo a coleta de logs para depuração e análise de tráfego.

### 7. **Segurança Adicional no Grupo de Segurança**
- **Alteração 7**: Removi o acesso SSH via IPv6, mantendo apenas o acesso via IPv4, para restringir ainda mais as superfícies de ataque.
  - **Resultado esperado**: Reduzir as chances de acessos não autorizados via SSH em redes IPv6.

### 8. **Definição da Retenção de Logs**
- **Alteração 8**: Configurei a retenção de logs do CloudWatch para 7 dias.
  - **Resultado esperado**: Garantir que os logs mais antigos sejam removidos automaticamente, economizando espaço e custos no CloudWatch.

### 9. **IP Público para a Instância**
- **Alteração 9**: Atribuí automaticamente um IP público à instância EC2 para permitir acesso externo ao servidor Nginx.
  - **Resultado esperado**: Garantir que o Nginx possa ser acessado de qualquer lugar da internet imediatamente após a criação da instância.

### 10. **Validação da AMI mais Recente**
- **Alteração 10**: Adicionei uma configuração para garantir que a versão mais recente da AMI Debian 12 seja utilizada na criação da instância.
  - **Resultado esperado**: Garantir que a instância sempre seja lançada com as atualizações mais recentes de segurança e correções de bugs.

---

## Como Utilizar

1. **Clone o repositório**:
   ```bash
   git clone https://github.com/isaquebraga/processo-seletivo-vexpenses.git
   cd seurepositorio

2. **Configuração de variáveis: Defina as variáveis no arquivo terraform.tfvars ou diretamente no código, incluindo o IP permitido para acesso SSH.**

3. **Inicialize e aplique o Terraform**:
   ```bash
    terraform init
    terraform apply

4. **Acompanhe os Outputs: O output exibirá a chave privada para acessar a instância EC2 via SSH e o endereço IP público para acessar o Nginx.**