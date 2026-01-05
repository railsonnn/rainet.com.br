# 🚀 Plano de Ação - Melhorias da Aplicação

## 🔴 FASE 1: Correções Críticas de Segurança (Esta Semana)

### 1.1 Encriptar Senha do MikroTik

**Status:** ❌ Não implementado  
**Prioridade:** CRÍTICA  
**Tempo estimado:** 30 minutos

#### Passos:

1. **Gerar senha encriptada:**
   ```bash
   # Baixar o JAR do módulo (se não tiver)
   # Localizar: target/repository/com/mulesoft/modules/mule-secure-configuration-property-module/1.3.0/
   
   java -cp mule-secure-configuration-property-module-1.3.0.jar \
     com.mulesoft.modules.secure.tools.SecurePropertiesTool \
     string encrypt AES CBC mulesoft12345678 "10648381" --use-random-iv
   ```

2. **Atualizar config-secure.yaml:**
   ```yaml
   mikrotik:
     api:
       password: "![RESULTADO_DO_COMANDO_ACIMA]"
   ```

3. **Verificar que está funcionando:**
   - Testar conexão com MikroTik
   - Verificar logs para confirmar que não há erros

---

### 1.2 Fortalecer JWT Secret

**Status:** ❌ Não implementado  
**Prioridade:** CRÍTICA  
**Tempo estimado:** 15 minutos

#### Passos:

1. **Gerar chave forte:**
   ```bash
   # Opção 1: OpenSSL
   openssl rand -base64 32
   
   # Opção 2: Python
   python -c "import secrets; print(secrets.token_urlsafe(32))"
   ```

2. **Atualizar config-dev.yaml:**
   ```yaml
   jwt:
     secret: "CHAVE_GERADA_ACIMA"  # Mínimo 32 caracteres
   ```

3. **Para produção (CloudHub):**
   - Adicionar como variável de ambiente: `JWT_SECRET`
   - NUNCA commitar a chave no repositório

---

### 1.3 Remover Senhas Hardcoded

**Status:** ❌ Não implementado  
**Prioridade:** CRÍTICA  
**Tempo estimado:** 1 hora

#### Passos:

1. **Mover senhas de usuários para Secure Properties:**
   ```yaml
   # config-secure.yaml
   users:
     admin:
       password: "![ENCRIPTAR_SENHA_ADMIN]"
     cliente1:
       password: "![ENCRIPTAR_SENHA_CLIENTE]"
   ```

2. **Atualizar security.xml:**
   ```xml
   <!-- Antes -->
   <when expression="#[vars.loginPassword == p('users.admin.password')]">
   
   <!-- Depois -->
   <when expression="#[vars.loginPassword == p('secure::users.admin.password')]">
   ```

3. **Atualizar mule-artifact.json:**
   ```json
   {
     "secureProperties": [
       "mikrotik.api.password",
       "users.admin.password",
       "users.cliente1.password"
     ]
   }
   ```

---

## 🟡 FASE 2: Melhorias de Performance (Próximas 2 Semanas)

### 2.1 Implementar Connection Pooling

**Status:** ❌ Não implementado  
**Prioridade:** ALTA  
**Tempo estimado:** 4-6 horas  
**Impacto:** Redução de 50% no tempo de resposta

#### Abordagem Recomendada:

**Opção A: Singleton Connection Manager (Recomendado)**

1. **Criar novo arquivo: `mikrotik-connection-manager.xml`**
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <mule xmlns="http://www.mulesoft.org/schema/mule/core"
         xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
         xmlns:java="http://www.mulesoft.org/schema/mule/java">
   
     <!-- Object Store para armazenar conexão -->
     <ee:object-store name="MikrotikConnectionStore" />
   
     <!-- Subflow: Get or Create Connection -->
     <sub-flow name="subflow-get-mikrotik-connection">
       <ee:cache key="#['mikrotik-connection']" 
                 cachingStrategy-ref="MikrotikConnectionStore"
                 doc:name="Cache - Get Connection">
         <flow-ref name="subflow-mikrotik-connect" />
       </ee:cache>
     </sub-flow>
   
     <!-- Subflow: Close Connection (para cleanup) -->
     <sub-flow name="subflow-close-mikrotik-connection">
       <ee:remove key="#['mikrotik-connection']" 
                  objectStore-ref="MikrotikConnectionStore" />
     </sub-flow>
   </mule>
   ```

2. **Atualizar `mikrotik-integration.xml`:**
   ```xml
   <!-- Modificar subflow-mikrotik-execute-command -->
   <sub-flow name="subflow-mikrotik-execute-command">
     <!-- Usar conexão do pool em vez de criar nova -->
     <flow-ref name="subflow-get-mikrotik-connection" />
     <set-variable variableName="connection" value="#[payload]" />
     
     <!-- Execute command -->
     <java:invoke instance="#[vars.connection]" 
                  class="me.legrange.mikrotik.ApiConnection" 
                  method="execute(java.lang.String)">
       <java:args>#[{arg0: vars.command}]</java:args>
     </java:invoke>
     
     <!-- NÃO fechar conexão aqui - reutilizar -->
     <set-payload value="#[payload]" />
   </sub-flow>
   ```

3. **Adicionar health check periódico:**
   ```xml
   <scheduler>
     <scheduling-strategy>
       <fixed-frequency frequency="300000" timeUnit="MILLISECONDS"/>
     </scheduling-strategy>
     <flow-ref name="subflow-health-check-mikrotik" />
   </scheduler>
   ```

**Considerações:**
- ⚠️ MikroTik API pode desconectar conexões inativas
- ⚠️ Implementar retry se conexão estiver fechada
- ⚠️ Adicionar timeout para conexões antigas

---

### 2.2 Processamento Paralelo

**Status:** ❌ Não implementado  
**Prioridade:** ALTA  
**Tempo estimado:** 2-3 horas  
**Impacto:** Redução de 40% no tempo de resposta

#### Implementação:

**Atualizar `flow-admin-pppoe-overview-get` em `api.xml`:**

```xml
<!-- Antes: Sequencial -->
<flow-ref name="subflow-get-ppp-secrets" />
<set-variable variableName="secrets" value="#[payload]" />
<flow-ref name="subflow-get-ppp-active" />
<set-variable variableName="active" value="#[payload]" />

<!-- Depois: Paralelo -->
<scatter-gather doc:name="Scatter-Gather - Get PPPoE Data">
  <route>
    <flow-ref name="subflow-get-ppp-secrets" />
    <set-variable variableName="secrets" value="#[payload]" />
  </route>
  <route>
    <flow-ref name="subflow-get-ppp-active" />
    <set-variable variableName="active" value="#[payload]" />
  </route>
</scatter-gather>

<!-- Consolidar resultados -->
<ee:transform>
  <ee:message>
    <ee:set-payload><![CDATA[%dw 2.0
import consolidatePPPoEData from dwl::pppoe_mapper
output application/json
---
consolidatePPPoEData(vars.secrets, vars.active)]]></ee:set-payload>
  </ee:message>
</ee:transform>
```

**Nota:** Scatter-Gather requer Mule Enterprise Edition.

**Alternativa (Community Edition):**
- Usar `async` blocks
- Ou manter sequencial (já que connection pooling já melhora bastante)

---

### 2.3 Otimizar Timeouts

**Status:** ⚠️ Parcialmente implementado  
**Prioridade:** MÉDIA  
**Tempo estimado:** 30 minutos

#### Implementação:

1. **Adicionar property em config-dev.yaml:**
   ```yaml
   mikrotik:
     api:
       timeout: "10000"  # 10 segundos (ajustar conforme necessário)
   ```

2. **Atualizar mikrotik-integration.xml:**
   ```xml
   <java:new class="me.legrange.mikrotik.ApiConnection" 
             constructor="ApiConnection(java.lang.String,int,int)">
     <java:args>#[{
       arg0: p('mikrotik.api.host'),
       arg1: p('mikrotik.api.port') as Number,
       arg2: p('mikrotik.api.timeout') as Number  <!-- Dinâmico -->
     }]</java:args>
   </java:new>
   ```

---

## 🟢 FASE 3: Testes e Qualidade (Próximo Mês)

### 3.1 Criar Suite MUnit Básica

**Status:** ❌ Não implementado  
**Prioridade:** ALTA  
**Tempo estimado:** 8-12 horas

#### Estrutura de Testes:

```
src/test/munit/
├── test-security.xml          # Testes de autenticação
├── test-mikrotik-integration.xml  # Testes de integração MikroTik
└── test-api.xml               # Testes de endpoints
```

#### Testes Críticos a Implementar:

1. **test-security.xml:**
   - ✅ Geração de JWT válido
   - ✅ Validação de JWT válido
   - ✅ Rejeição de JWT inválido
   - ✅ Rejeição de JWT expirado
   - ✅ Validação de role ADMIN
   - ✅ Validação de role CLIENT
   - ✅ Rejeição de token sem role

2. **test-mikrotik-integration.xml:**
   - ✅ Conexão bem-sucedida
   - ✅ Tratamento de erro de conexão
   - ✅ Execução de comando
   - ✅ Tratamento de timeout

3. **test-api.xml:**
   - ✅ Login bem-sucedido
   - ✅ Login com credenciais inválidas
   - ✅ Acesso a endpoint admin sem token
   - ✅ Acesso a endpoint admin com token cliente

#### Exemplo de Teste:

```xml
<munit:test name="test-jwt-generation-success" 
            description="Test JWT generation with valid credentials">
  <munit:execution>
    <set-payload value='{"username":"admin","role":"ADMIN"}' />
    <flow-ref name="subflow-generate-jwt" />
    <munit:assert-that 
        expression="#[payload.access_token != null]" 
        message="JWT token should be generated" />
  </munit:execution>
</munit:test>
```

---

### 3.2 Adicionar Validação de Entrada

**Status:** ❌ Não implementado  
**Prioridade:** MÉDIA  
**Tempo estimado:** 2-3 horas

#### Implementação:

1. **Criar schemas JSON para validação:**
   ```json
   // src/main/resources/schemas/login-request.schema.json
   {
     "type": "object",
     "required": ["username", "password"],
     "properties": {
       "username": {"type": "string", "minLength": 1},
       "password": {"type": "string", "minLength": 1}
     }
   }
   ```

2. **Adicionar validação no flow-auth-login:**
   ```xml
   <validation:is-not-empty 
       value="#[payload.username]" 
       message="Username is required" />
   <validation:is-not-empty 
       value="#[payload.password]" 
       message="Password is required" />
   ```

3. **Validar query parameters:**
   ```xml
   <!-- Em flow-admin-logs-get -->
   <ee:transform>
     <ee:message>
       <ee:set-payload><![CDATA[%dw 2.0
output application/java
---
{
   limit: if ((attributes.queryParams.limit default "100") as Number > 1000)
            then 1000
          else if ((attributes.queryParams.limit default "100") as Number < 1)
            then 1
          else (attributes.queryParams.limit default "100") as Number
}]]></ee:set-payload>
     </ee:message>
   </ee:transform>
   ```

---

## 🔵 FASE 4: Melhorias de Arquitetura (Backlog)

### 4.1 Migrar Autenticação para Banco de Dados

**Status:** ❌ Não implementado  
**Prioridade:** MÉDIA  
**Tempo estimado:** 16-24 horas

#### Abordagem:

1. **Criar tabela de usuários:**
   ```sql
   CREATE TABLE users (
     id SERIAL PRIMARY KEY,
     username VARCHAR(50) UNIQUE NOT NULL,
     password_hash VARCHAR(255) NOT NULL,
     role VARCHAR(20) NOT NULL,
     created_at TIMESTAMP DEFAULT NOW(),
     updated_at TIMESTAMP DEFAULT NOW()
   );
   ```

2. **Usar Database Connector:**
   ```xml
   <db:select config-ref="Database_Config">
     <db:sql>SELECT * FROM users WHERE username = :username</db:sql>
     <db:input-parameters>
       <db:input-parameter key="username" value="#[vars.loginUsername]" />
     </db:input-parameters>
   </db:select>
   ```

3. **Implementar hash de senhas (bcrypt):**
   - Usar biblioteca Java para bcrypt
   - Comparar hash em vez de senha em texto

---

### 4.2 Adicionar Paginação

**Status:** ❌ Não implementado  
**Prioridade:** MÉDIA  
**Tempo estimado:** 4-6 horas

#### Implementação:

```xml
<!-- Adicionar query parameters -->
<!-- GET /admin/pppoe/overview?page=1&size=20 -->

<ee:transform>
  <ee:message>
    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
   page: (attributes.queryParams.page default "1") as Number,
   size: (attributes.queryParams.size default "20") as Number,
   total: sizeOf(payload),
   data: payload[((page - 1) * size) to ((page * size) - 1)]
}]]></ee:set-payload>
  </ee:message>
</ee:transform>
```

---

## 📋 Checklist de Implementação

### Fase 1 - Segurança (Esta Semana)
- [ ] Encriptar senha do MikroTik
- [ ] Fortalecer JWT secret
- [ ] Remover senhas hardcoded
- [ ] Testar todas as funcionalidades após mudanças

### Fase 2 - Performance (Próximas 2 Semanas)
- [ ] Implementar connection pooling
- [ ] Adicionar processamento paralelo (se EE)
- [ ] Otimizar timeouts
- [ ] Medir ganhos de performance

### Fase 3 - Qualidade (Próximo Mês)
- [ ] Criar suite MUnit básica
- [ ] Adicionar validação de entrada
- [ ] Documentar testes
- [ ] Atingir 60% de cobertura

### Fase 4 - Arquitetura (Backlog)
- [ ] Migrar autenticação para BD
- [ ] Adicionar paginação
- [ ] Implementar rate limiting
- [ ] Adicionar audit logging

---

## 📊 Métricas de Sucesso

Após implementar as melhorias:

| Métrica | Antes | Depois | Meta |
|---------|-------|--------|------|
| Tempo de Resposta Médio | 2000ms | <1000ms | ✅ |
| Cobertura de Testes | 0% | >60% | ✅ |
| Vulnerabilidades Críticas | 3 | 0 | ✅ |
| Disponibilidade | N/A | >99.9% | ✅ |

---

**Última atualização:** 2025-12-02  
**Próxima revisão:** Após conclusão da Fase 1

