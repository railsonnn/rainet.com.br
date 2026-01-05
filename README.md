*** Begin Patch
*** Update File: c:\Users\railson.nogueira\OneDrive - Corporativo\Documentos\rainet.com.br\README.md
@@
# Rainet — MikroTik PPPoE Monitor (Mule 4)

Breve: API para monitoramento de conexões PPPoE em roteadores MikroTik, implementada em Mule 4 com integração RouterOS e autenticação JWT.

Status do repositório
- Branch principal enviado: `dev1` → https://github.com/railsonnn/rainet.com.br (branch dev1)

Principais arquivos
- `src/main/mule/global.xml` — propriedades, HTTP Listener, secure properties
- `src/main/mule/security.xml` — autenticação JWT e roles
- `src/main/mule/mikrotik-integration.xml` — integração com RouterOS
- `src/main/mule/api.xml` — endpoints REST (admin / client)

Requisitos
- Java 17
- Maven 3.8+ (3.9 recomendado)
- Mule Runtime 4.9.x (prod: 4.9.3)

Build e execução local
1. Compilar:

```bash
mvn -U clean package
```

2. Executar (desenvolvimento):

```bash
mvn mule:run
# ou execute via Anypoint Studio
```

A API ficará disponível em `http://localhost:8081/api` (ver `config-dev.yaml`).

Configuração
- Arquivos de configuração: `src/main/resources/config-dev.yaml`, `config-prod.yaml`, `config-secure.yaml`.
- Nunca commite segredos em texto claro. Use Secure Properties (`${secure::...}`) ou variáveis de ambiente.

Testes
- Executar MUnit (quando adicionados):

```bash
mvn test
```

Deploy
- Deploy via Maven/CloudHub ou Anypoint Studio; ver `pom.xml` e `IMPLEMENTATION-NOTES.md` para parâmetros de deploy.

Segurança — pontos importantes
- Troque `JWT_SECRET` por valor de produção (≥ 32 chars).  
- Encripte senha do MikroTik com `SecurePropertiesTool` e use `${secure::...}`.  
- Habilite HTTPS e rate limiting no API Manager.

Problemas conhecidos
- `mule-java-module` está em versão antiga no projeto; revisar `pom.xml` antes de atualizar.  
- Integração MikroTik abre/fecha a conexão por requisição — implementar connection pooling para melhorar latência.

Contato / manutenção
- Documentação RAML: `src/main/resources/api/mikrotik-monitor-api.raml`  
- Notas de implementação: `IMPLEMENTATION-NOTES.md`

Contribuição
- Para contribuir, crie branch a partir de `dev1`, faça commits claros e abra PR para revisão.

Licença
- (adicionar licença aqui, se aplicável)

---

Arquivo atualizado e commitado na branch `dev1`.

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
