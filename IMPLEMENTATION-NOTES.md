# Notas de Implementação - MikroTik PPPoE Monitor API

## 📌 Decisões Técnicas

### 1. Versões de Dependências

#### Java Module: 1.2.13 (em vez de 1.2.16)
**Motivo:** As versões 1.2.15 e 1.2.16 do mule-java-module têm uma dependência transitiva problemática com `org.springframework:spring-core:5.3.39-spring-framework-5.3.45`, que não existe nos repositórios Maven. A versão 1.2.13 é estável e compatível com Mule 4.9.3 e Java 17.

**Impacto:** Nenhum. A versão 1.2.13 possui todas as funcionalidades necessárias para o projeto.

#### MikroTik Library: 3.0.5 (em vez de 3.0.8)
**Motivo:** Melhor compatibilidade e menos dependências transitivas conflitantes.

**Impacto:** Funcionalidades são idênticas para os comandos utilizados no projeto.

### 2. Chave de Encriptação

**Requisito:** Mínimo de 16 caracteres para AES CBC.

**Desenvolvimento:** `mulesoft12345678` (16 caracteres)

**Produção:** Deve ser alterada para uma chave forte de pelo menos 32 caracteres. Exemplo:
```bash
openssl rand -base64 32
```

### 3. Autenticação JWT

#### Implementação Atual
- **Biblioteca:** Auth0 Java JWT 4.4.0
- **Algoritmo:** HMAC256
- **Validade:** 24 horas (1440 minutos)
- **Claims:** `sub` (username), `role` (ADMIN/CLIENT), `exp` (expiration)

#### Limitações
- Usuários hardcoded em `config-dev.yaml`
- Validação de senha simples (comparação direta)
- Não há refresh token

#### Melhorias Futuras
1. **Integração com Banco de Dados:** Armazenar usuários e senhas hash em banco
2. **Refresh Token:** Implementar refresh token para renovação automática
3. **Validação de Senha:** Usar bcrypt ou argon2 para hash de senhas
4. **Revogação de Token:** Implementar blacklist de tokens revogados
5. **Multi-factor Authentication:** Adicionar suporte a 2FA

### 4. Integração MikroTik

#### Conexão
- **Protocolo:** RouterOS API (porta 8728)
- **Autenticação:** Username/Password
- **Timeout:** 5000ms (5 segundos)

#### Comandos Utilizados
1. `/system/resource/print` - Informações do sistema
2. `/ppp/secret/print` - Lista de usuários PPPoE configurados
3. `/ppp/active/print` - Conexões PPPoE ativas
4. `/log/print` - Logs do sistema

#### Padrão de Conexão
Cada requisição:
1. Abre nova conexão
2. Faz login
3. Executa comando
4. Fecha conexão

**Motivo:** Simplicidade e evita problemas com conexões travadas.

**Melhoria Futura:** Implementar connection pooling para melhor performance.

### 5. Estrutura de Dados

#### PPPoE Overview
Consolidação de dados de duas fontes:
- **PPP Secrets:** Usuários configurados (username, profile, comment)
- **PPP Active:** Conexões ativas (IP, uptime, rx_bytes, tx_bytes)

**DataWeave Module:** `dwl/pppoe-mapper.dwl` - Função `consolidatePPPoEData()`

#### Filtros de Logs
- **pppoe:** `topics="pppoe,info"`
- **error:** `topics="error"`
- **warning:** `topics="warning"`
- **all:** Sem filtro

### 6. Segurança

#### Implementado
- ✅ JWT para autenticação
- ✅ Validação de role (ADMIN/CLIENT)
- ✅ Secure Properties para senha do MikroTik
- ✅ Logs estruturados sem dados sensíveis
- ✅ Error handling padronizado

#### Não Implementado (Recomendações)
- ⚠️ HTTPS (deve ser configurado no CloudHub ou API Gateway)
- ⚠️ Rate Limiting (deve ser configurado no API Manager)
- ⚠️ IP Whitelist (deve ser configurado no API Manager)
- ⚠️ CORS (deve ser configurado conforme necessidade do frontend)
- ⚠️ Audit Log (registrar todas as ações administrativas)

## 🔧 Configurações Importantes

### 1. Variáveis de Ambiente

#### Desenvolvimento (config-dev.yaml)
```yaml
http.port: "8081"
mikrotik.api.host: "192.168.88.1"
mikrotik.api.port: "8728"
mikrotik.api.user: "admin"
jwt.secret: "dev-secret-key-change-in-production"
jwt.expiration.minutes: "1440"
```

#### Produção (CloudHub)
```properties
mule.env=prod
MIKROTIK_HOST=<ip_ou_hostname>
MIKROTIK_PORT=8728
MIKROTIK_USER=<usuario_api>
JWT_SECRET=<chave_forte_256_bits>
secure.key=<chave_encriptacao_16_chars>
mikrotik.api.password=![encrypted_value]
```

### 2. Propriedades Seguras

#### Gerar Senha Encriptada
```bash
# Usando a ferramenta do Mule
java -cp mule-secure-configuration-property-module-1.3.0.jar \
  com.mulesoft.modules.secure.tools.SecurePropertiesTool \
  string encrypt AES CBC <secure.key> "<senha>" --use-random-iv

# Exemplo
java -cp mule-secure-configuration-property-module-1.3.0.jar \
  com.mulesoft.modules.secure.tools.SecurePropertiesTool \
  string encrypt AES CBC mulesoft12345678 "senha123" --use-random-iv

# Output: ![encrypted_value_here]
```

#### Usar no config-secure.yaml
```yaml
mikrotik:
  api:
    password: "![encrypted_value_here]"
```

### 3. Configuração do MikroTik

#### Habilitar API
```routeros
/ip service
set api address=0.0.0.0/0 disabled=no port=8728
```

#### Criar Usuário API (Recomendado)
```routeros
/user add name=api-user password=senha_forte group=read
```

#### Firewall (Opcional - Restringir Acesso)
```routeros
/ip firewall filter
add chain=input protocol=tcp dst-port=8728 src-address=<ip_mulesoft> action=accept
add chain=input protocol=tcp dst-port=8728 action=drop
```

## 📊 Performance

### Benchmarks Esperados

#### Tempo de Resposta (com MikroTik local)
- `/auth/login`: 200-500ms
- `/admin/system/resource`: 500-1000ms
- `/admin/pppoe/overview`: 1000-2000ms
- `/admin/logs`: 500-1500ms
- `/client/pppoe/me`: 1000-1500ms
- `/client/traffic`: 500-1000ms

#### Throughput
- **Desenvolvimento:** 50-100 req/s
- **Produção (0.1 vCore):** 50-100 req/s
- **Produção (1 vCore):** 200-500 req/s

### Otimizações Possíveis

1. **Connection Pooling:** Reutilizar conexões MikroTik
2. **Caching:** Cache de dados que mudam pouco (ex: PPP secrets)
3. **Async Processing:** Processar comandos MikroTik em paralelo
4. **Batch Operations:** Agrupar múltiplas requisições

## 🐛 Problemas Conhecidos e Soluções

### 1. Dependência Spring Framework
**Problema:** mule-java-module 1.2.15+ puxa Spring 5.3.39-spring-framework-5.3.45 (não existe)

**Solução:** Usar mule-java-module 1.2.13

### 2. Chave de Encriptação Curta
**Problema:** Mule 4.9 requer mínimo 16 caracteres para AES CBC

**Solução:** Usar chave com 16+ caracteres

### 3. Timeout de Conexão MikroTik
**Problema:** Conexões podem travar se MikroTik estiver lento

**Solução:** Timeout de 5 segundos configurado no ApiConnection

### 4. Logs Grandes
**Problema:** `/log/print` pode retornar muitos logs

**Solução:** Sempre usar limite (default: 100, max: 1000)

### 5. Clientes Hardcoded
**Problema:** Usuários definidos em YAML, não escalável

**Solução Futura:** Integrar com banco de dados ou LDAP

## 🔄 Fluxo de Dados

### Autenticação
```
Client → POST /auth/login
  ↓
flow-auth-login
  ↓
Validate credentials (YAML)
  ↓
subflow-generate-jwt
  ↓
JWT.create() → withSubject() → withClaim() → sign()
  ↓
Return {access_token, token_type, role}
```

### Admin - PPPoE Overview
```
Client → GET /admin/pppoe/overview + JWT
  ↓
flow-admin-pppoe-overview-get
  ↓
subflow-validate-jwt (extract username, role)
  ↓
subflow-check-admin-role (verify role=ADMIN)
  ↓
Parallel:
  ├─ subflow-get-ppp-secrets → /ppp/secret/print
  └─ subflow-get-ppp-active → /ppp/active/print
  ↓
consolidatePPPoEData(secrets, active)
  ↓
Return consolidated JSON array
```

### Cliente - Meus Dados
```
Client → GET /client/pppoe/me + JWT
  ↓
flow-client-pppoe-me-get
  ↓
subflow-validate-jwt (extract username, role)
  ↓
Verify role=CLIENT
  ↓
Parallel:
  ├─ subflow-get-ppp-secrets
  └─ subflow-get-ppp-active
  ↓
consolidatePPPoEData() → filter by username
  ↓
Return single client object
```

## 📁 Estrutura de Arquivos

```
CurieProject/
├── pom.xml                                 # Maven dependencies
├── mule-artifact.json                      # Mule app config
├── README.md                               # Main documentation
├── TESTING-GUIDE.md                        # Testing instructions
├── IMPLEMENTATION-NOTES.md                 # This file
├── cloudhub-properties-example.txt         # CloudHub config example
│
├── src/main/
│   ├── mule/
│   │   ├── global.xml                      # Global configs
│   │   ├── security.xml                    # Auth & JWT
│   │   ├── mikrotik-integration.xml        # MikroTik API
│   │   └── api.xml                         # REST endpoints
│   │
│   └── resources/
│       ├── api/
│       │   └── mikrotik-monitor-api.raml   # API specification
│       ├── dwl/
│       │   ├── jwt-utils.dwl               # JWT utilities
│       │   └── pppoe-mapper.dwl            # Data consolidation
│       ├── config-dev.yaml                 # Dev properties
│       ├── config-prod.yaml                # Prod properties
│       ├── config-secure.yaml              # Encrypted properties
│       └── log4j2.xml                      # Logging config
│
└── src/test/
    └── resources/
        └── log4j2-test.xml                 # Test logging
```

## 🚀 Roadmap de Melhorias

### Curto Prazo (1-2 semanas)
- [ ] Adicionar mais clientes de teste
- [ ] Implementar testes automatizados (MUnit)
- [ ] Adicionar métricas customizadas
- [ ] Documentar API com exemplos Postman

### Médio Prazo (1-2 meses)
- [ ] Integração com banco de dados para usuários
- [ ] Connection pooling para MikroTik
- [ ] Cache de dados PPP secrets
- [ ] Refresh token JWT
- [ ] Audit log de ações administrativas

### Longo Prazo (3-6 meses)
- [ ] Dashboard web (React/Vue.js)
- [ ] Notificações em tempo real (WebSocket)
- [ ] Relatórios de uso e tráfego
- [ ] Integração com sistemas de billing
- [ ] Multi-tenancy (múltiplos MikroTiks)
- [ ] API para gerenciamento de clientes (CRUD)

## 📞 Contatos e Suporte

### Documentação Oficial
- **MuleSoft Docs:** https://docs.mulesoft.com
- **MikroTik API:** https://wiki.mikrotik.com/wiki/Manual:API
- **Auth0 JWT:** https://github.com/auth0/java-jwt

### Repositórios
- **MikroTik Java Library:** https://github.com/GideonLeGrange/mikrotik-java
- **Auth0 JWT:** https://github.com/auth0/java-jwt

---

**Última atualização:** 2025-12-02  
**Versão:** 1.0.0-SNAPSHOT  
**Mule Runtime:** 4.9.3  
**Java:** 17
