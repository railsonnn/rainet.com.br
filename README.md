# MikroTik PPPoE Monitor API

## 📋 Descrição

Aplicação MuleSoft 4.9 completa para monitoramento de conexões PPPoE de roteador MikroTik usando RouterOS API, com autenticação JWT e painéis diferenciados para administradores e clientes.

## 🏗️ Arquitetura

### Componentes Principais

- **global.xml**: Configurações globais (HTTP Listener, Configuration Properties, Secure Properties)
- **security.xml**: Autenticação JWT e validação de tokens
- **mikrotik-integration.xml**: Integração com MikroTik RouterOS API
- **api.xml**: Endpoints REST para admin e clientes

### Tecnologias

- **Mule Runtime**: 4.9.3
- **Java**: 17
- **MikroTik RouterOS API**: 3.0.8
- **JWT**: Auth0 Java JWT 4.4.0

## 🚀 Endpoints da API

### Autenticação

#### POST /api/auth/login
Autentica usuário e retorna JWT token.

**Request:**
```json
{
  "username": "admin",
  "password": "admin123"
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "role": "ADMIN"
}
```

### Endpoints Admin (Requer role ADMIN)

#### GET /api/admin/system/resource
Retorna informações do sistema MikroTik (CPU, memória, uptime).

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
{
  "uptime": "1d 2h 30m",
  "cpu-load": 5,
  "free-memory": 512000000,
  "total-memory": 1024000000
}
```

#### GET /api/admin/pppoe/overview
Retorna visão geral de todos os clientes PPPoE.

**Response:**
```json
[
  {
    "username": "cliente1",
    "plan_profile": "10MB",
    "comment": "Cliente teste",
    "online": true,
    "ip_address": "10.0.0.10",
    "uptime": "2h30m",
    "rx_bytes": 1048576,
    "tx_bytes": 524288
  }
]
```

#### GET /api/admin/logs?topic=pppoe&limit=100
Retorna logs do MikroTik com filtros opcionais.

**Query Parameters:**
- `topic`: pppoe | error | warning | all (default: all)
- `limit`: número de logs (default: 100)

### Endpoints Cliente (Requer role CLIENT)

#### GET /api/client/pppoe/me
Retorna dados do cliente autenticado.

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
{
  "username": "cliente1",
  "plan_profile": "10MB",
  "online": true,
  "ip_address": "10.0.0.10",
  "uptime": "2h30m",
  "rx_bytes": 1048576,
  "tx_bytes": 524288
}
```

#### GET /api/client/logs?limit=100
Retorna logs relacionados ao cliente autenticado.

#### GET /api/client/traffic
Retorna tráfego em tempo real do cliente.

**Response:**
```json
{
  "username": "cliente1",
  "online": true,
  "rx_bytes": 1048576,
  "tx_bytes": 524288
}
```

## ⚙️ Configuração Local

### 1. Pré-requisitos

- Java 17
- Maven 3.9+
- Anypoint Studio 7.x (opcional)
- MikroTik RouterOS com API habilitada

### 2. Configurar Propriedades

Edite `src/main/resources/config-dev.yaml`:

```yaml
http:
  port: "8081"

mikrotik:
  api:
    host: "192.168.88.1"  # IP do seu MikroTik
    port: "8728"
    user: "admin"

jwt:
  secret: "dev-secret-key-change-in-production"
  expiration:
    minutes: "1440"

users:
  admin:
    password: "admin123"
    role: "ADMIN"
  cliente1:
    password: "cliente123"
    role: "CLIENT"
```

### 3. Configurar Senha Segura do MikroTik

#### Opção A: Usar senha em texto (apenas desenvolvimento)

Edite `src/main/resources/config-secure.yaml`:
```yaml
mikrotik:
  api:
    password: "![senha_mikrotik]"
```

#### Opção B: Encriptar senha (recomendado)

```bash
# Gerar senha encriptada
java -cp mule-secure-configuration-property-module-1.3.0.jar \
  com.mulesoft.modules.secure.tools.SecurePropertiesTool \
  string encrypt AES CBC mulesoft123456 "sua_senha_mikrotik" --use-random-iv

# Copiar o resultado (ex: ![encrypted_value]) para config-secure.yaml
```

### 4. Executar Localmente

```bash
# Compilar
mvn clean package

# Executar
mvn mule:run
```

A API estará disponível em: `http://localhost:8081/api`

### 5. Testar Endpoints

```bash
# Login como admin
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Usar token retornado
export TOKEN="eyJhbGc..."

# Testar endpoint admin
curl -X GET http://localhost:8081/api/admin/system/resource \
  -H "Authorization: Bearer $TOKEN"

# Login como cliente
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"cliente1","password":"cliente123"}'

# Testar endpoint cliente
curl -X GET http://localhost:8081/api/client/pppoe/me \
  -H "Authorization: Bearer $TOKEN"
```

## ☁️ Deploy no CloudHub 2.0

### 1. Preparar Propriedades de Produção

Crie `src/main/resources/config-prod.yaml`:

```yaml
http:
  port: "8081"

mikrotik:
  api:
    host: "${MIKROTIK_HOST}"
    port: "${MIKROTIK_PORT}"
    user: "${MIKROTIK_USER}"

jwt:
  secret: "${JWT_SECRET}"
  expiration:
    minutes: "1440"
```

### 2. Configurar Variáveis de Ambiente no Runtime Manager

No Anypoint Platform > Runtime Manager > Application > Settings > Properties:

```properties
# Environment
mule.env=prod

# MikroTik Configuration
MIKROTIK_HOST=seu-mikrotik.exemplo.com
MIKROTIK_PORT=8728
MIKROTIK_USER=api-user

# JWT Configuration
JWT_SECRET=seu-secret-super-seguro-aqui-min-256-bits

# Secure Key
secure.key=sua-chave-de-encriptacao-aqui
```

### 3. Configurar Propriedades Seguras

No Runtime Manager > Application > Settings > Properties > Secure:

```properties
mikrotik.api.password=![valor_encriptado_aqui]
```

Para gerar o valor encriptado:

```bash
java -cp mule-secure-configuration-property-module-1.3.0.jar \
  com.mulesoft.modules.secure.tools.SecurePropertiesTool \
  string encrypt AES CBC sua-chave-de-encriptacao-aqui "senha_mikrotik" --use-random-iv
```

### 4. Deploy via Maven

```bash
# Configurar credenciais no ~/.m2/settings.xml
<server>
  <id>anypoint-exchange-v3</id>
  <username>seu-username</username>
  <password>sua-senha</password>
</server>

# Deploy
mvn clean deploy -DmuleDeploy \
  -Dmule.version=4.9.3 \
  -Danypoint.platform.client_id=seu-client-id \
  -Danypoint.platform.client_secret=seu-client-secret \
  -Dcloudhub.environment=Production \
  -Dcloudhub.region=us-east-2 \
  -Dcloudhub.workers=1 \
  -Dcloudhub.workerType=MICRO
```

### 5. Deploy via Anypoint Studio

1. Right-click no projeto > Anypoint Platform > Deploy to CloudHub
2. Selecione:
   - **Environment**: Production
   - **Runtime version**: 4.9.3
   - **Worker size**: 0.1 vCores (MICRO)
   - **Workers**: 1
3. Configure as propriedades na aba "Properties"
4. Click "Deploy Application"

### 6. Configurar Recursos CloudHub

#### vCores Recomendados

- **Desenvolvimento/Teste**: 0.1 vCores (MICRO)
- **Produção (baixo tráfego)**: 0.2 vCores (SMALL)
- **Produção (médio tráfego)**: 1 vCore (MEDIUM)

#### Workers

- **Desenvolvimento**: 1 worker
- **Produção**: 2+ workers (para alta disponibilidade)

### 7. Verificar Deploy

```bash
# Obter URL da aplicação
# Ex: https://mikrotik-monitor.us-e2.cloudhub.io

# Testar health
curl https://mikrotik-monitor.us-e2.cloudhub.io/api/auth/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

## 🔒 Segurança

### Boas Práticas

1. **JWT Secret**: Use uma chave forte (mínimo 256 bits) em produção
2. **Senhas**: Sempre encripte senhas usando Secure Properties
3. **HTTPS**: Configure HTTPS no CloudHub ou use API Gateway
4. **Rate Limiting**: Implemente rate limiting no API Manager
5. **IP Whitelist**: Restrinja acesso ao MikroTik por IP

### Políticas Recomendadas (API Manager)

- **Rate Limiting**: 100 requests/minuto por cliente
- **Client ID Enforcement**: Para controle de acesso
- **IP Whitelist**: Apenas IPs confiáveis
- **CORS**: Configure para frontend específico

## 📊 Monitoramento

### Logs

Os logs estão estruturados com prefixo `[FLOW_NAME]` para fácil rastreamento:

```
[flow-auth-login] - Login attempt for user: admin
[subflow-validate-jwt] - JWT validated successfully for user: admin, role: ADMIN
[flow-admin-pppoe-overview-get] - Response sent successfully with 5 clients
```

### Métricas CloudHub

Monitore no Runtime Manager:

- **CPU Usage**: Deve ficar abaixo de 70%
- **Memory Usage**: Deve ficar abaixo de 80%
- **Response Time**: Endpoints devem responder em < 2s
- **Error Rate**: Deve ser < 1%

### Alertas Recomendados

- CPU > 80% por 5 minutos
- Memory > 90% por 5 minutos
- Error rate > 5% por 1 minuto
- Application down

## 🧪 Testes

### Testar Autenticação

```bash
# Admin
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Cliente
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"cliente1","password":"cliente123"}'
```

### Testar Autorização

```bash
# Cliente tentando acessar endpoint admin (deve retornar 403)
curl -X GET http://localhost:8081/api/admin/system/resource \
  -H "Authorization: Bearer $CLIENT_TOKEN"
```

### Testar Integração MikroTik

```bash
# Verificar se MikroTik está acessível
telnet 192.168.88.1 8728

# Testar endpoint que usa MikroTik
curl -X GET http://localhost:8081/api/admin/pppoe/overview \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## 🐛 Troubleshooting

### Erro: "Connection refused" ao conectar no MikroTik

**Solução:**
1. Verifique se a API está habilitada no MikroTik: `/ip service print`
2. Verifique se a porta 8728 está aberta
3. Teste conectividade: `telnet <mikrotik-ip> 8728`

### Erro: "Invalid credentials" no login

**Solução:**
1. Verifique as credenciais em `config-dev.yaml`
2. Para clientes PPPoE, verifique se o username existe no MikroTik
3. Verifique logs para detalhes: `[flow-auth-login]`

### Erro: "Authorization token is required"

**Solução:**
1. Verifique se o header `Authorization` está presente
2. Formato correto: `Authorization: Bearer <token>`
3. Verifique se o token não expirou (validade: 24h)

### Erro: "Failed to retrieve PPPoE overview"

**Solução:**
1. Verifique conectividade com MikroTik
2. Verifique credenciais do MikroTik em `config-secure.yaml`
3. Verifique logs: `[subflow-mikrotik-connect]`

## 📝 Estrutura do Projeto

```
.
├── pom.xml
├── mule-artifact.json
├── README.md
├── src/
│   ├── main/
│   │   ├── mule/
│   │   │   ├── global.xml
│   │   │   ├── security.xml
│   │   │   ├── mikrotik-integration.xml
│   │   │   └── api.xml
│   │   └── resources/
│   │       ├── api/
│   │       │   └── mikrotik-monitor-api.raml
│   │       ├── dwl/
│   │       │   ├── jwt-utils.dwl
│   │       │   └── pppoe-mapper.dwl
│   │       ├── config-dev.yaml
│   │       ├── config-prod.yaml
│   │       ├── config-secure.yaml
│   │       └── log4j2.xml
│   └── test/
│       └── resources/
│           └── log4j2-test.xml
```

## 🤝 Contribuindo

Para adicionar novos endpoints ou funcionalidades:

1. Adicione o endpoint em `api.xml`
2. Crie subflows necessários em `mikrotik-integration.xml`
3. Atualize o RAML em `src/main/resources/api/mikrotik-monitor-api.raml`
4. Teste localmente antes de fazer deploy

## 📄 Licença

Este projeto é proprietário e confidencial.

## 📞 Suporte

Para suporte técnico, contate a equipe de desenvolvimento.

---

**Desenvolvido com MuleSoft 4.9** 🚀
