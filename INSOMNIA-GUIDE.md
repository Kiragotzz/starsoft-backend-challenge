# Guia de Importação - Insomnia Collection

## 📦 Como Importar

### 1. Abrir o Insomnia

Se ainda não tem instalado:
- Download: https://insomnia.rest/download
- Ou via terminal: `sudo snap install insomnia` (Linux)

### 2. Importar o Arquivo

**Método 1 - Arrastar e Soltar:**
- Abra o Insomnia
- Arraste o arquivo `insomnia-collection.json` para dentro da janela
- Clique em "Import"

**Método 2 - Menu:**
- No Insomnia, clique em **Application** → **Preferences** → **Data** → **Import Data**
- Ou use o atalho: `Ctrl+Shift+I` (Linux/Windows) ou `Cmd+Shift+I` (Mac)
- Selecione **From File**
- Navegue até `/home/luis/Documentos/Projetos/starsoft-backend-challenge/insomnia-collection.json`
- Clique em "Scan" e depois "Import"

### 3. Workspace Importado

Você verá um workspace chamado: **"Cinema Ticketing System"**

---

## 🗂️ Estrutura das Pastas

A collection está organizada em 4 pastas:

### 📁 **1. Sessions**
- ✅ `1. Create Session` - Criar sessão de cinema
- ✅ `2. List All Sessions` - Listar sessões
- ✅ `3. Get Available Seats` - Ver assentos disponíveis

### 📁 **2. Reservations**
- ✅ `4. Reserve Seats (Alice)` - Reservar assentos para user-alice
- ✅ `5. Test Race Condition (Bob - DEVE FALHAR)` - Testar race condition
- ✅ `6. Reserve Seats (Bob)` - Reservar outros assentos
- ✅ `7. Confirm Payment (Alice)` - Confirmar pagamento
- ✅ `8. Test Idempotency (Confirm Again)` - Testar idempotência

### 📁 **3. Purchases**
- ✅ `9. Purchase History (Alice)` - Histórico de compras
- ✅ `10. Purchase History (Bob)` - Histórico vazio (não pagou)

### 📁 **4. Concurrency Tests**
- ✅ `Concurrent Request 1 (Charlie)` - Para testar race condition
- ✅ `Concurrent Request 2 (Diana)` - Execute simultaneamente com Request 1

---

## 🔧 Configurar Variáveis de Ambiente

### 1. Acessar Environments

No canto superior esquerdo do Insomnia:
- Clique no dropdown de ambientes
- Selecione **"Base Environment"**

### 2. Configurar Variáveis

Você verá 4 variáveis:

```json
{
  "base_url": "http://localhost:3000",
  "session_id": "COLE_AQUI_O_ID_DA_SESSAO_CRIADA",
  "reservation_id_alice": "COLE_AQUI_O_ID_DA_RESERVA_DE_ALICE",
  "reservation_id_bob": "COLE_AQUI_O_ID_DA_RESERVA_DE_BOB"
}
```

**Deixe `base_url` como está** (a menos que sua API esteja em outra porta).

---

## 🚀 Fluxo de Teste Completo

### Passo 1: Criar Sessão

1. Execute **"1. Create Session"**
2. Copie o **`id`** da resposta (exemplo: `"id": "550e8400-e29b-41d4-a716-446655440000"`)
3. Vá em **Environments** → **Base Environment**
4. Cole o ID em `session_id`
5. Clique em **Done**

### Passo 2: Ver Assentos Disponíveis

Execute **"3. Get Available Seats"**

Resposta esperada:
```json
{
  "totalSeats": 16,
  "availableSeats": 16,
  "seats": [
    {"seatNumber": "A1", "status": "AVAILABLE"},
    {"seatNumber": "A2", "status": "AVAILABLE"},
    ...
  ]
}
```

### Passo 3: Reservar Assentos (Alice)

1. Execute **"4. Reserve Seats (Alice)"**
2. Copie o **`data.reservationId`** da resposta
3. Cole em `reservation_id_alice` nas variáveis de ambiente

### Passo 4: Testar Race Condition

Execute **"5. Test Race Condition (Bob - DEVE FALHAR)"**

Resultado esperado: ❌ **Erro 409 Conflict** (assento A2 já está reservado)

### Passo 5: Reservar Outros Assentos (Bob)

1. Execute **"6. Reserve Seats (Bob)"** (assentos B1, B2)
2. Copie o `reservation_id` da resposta
3. Cole em `reservation_id_bob` nas variáveis

### Passo 6: Confirmar Pagamento (Alice)

Execute **"7. Confirm Payment (Alice)"**

Resposta esperada:
```json
{
  "success": true,
  "data": {
    "saleId": "abc123...",
    "totalPrice": 90
  }
}
```

### Passo 7: Testar Idempotência

Execute **"8. Test Idempotency (Confirm Again)"**

O **`saleId`** deve ser **o mesmo** da etapa anterior (não cria venda duplicada).

### Passo 8: Ver Históricos

- **"9. Purchase History (Alice)"** → Deve mostrar 1 compra
- **"10. Purchase History (Bob)"** → Deve mostrar 0 compras (não confirmou pagamento)

### Passo 9: Aguardar Expiração da Reserva de Bob

1. Aguarde **40 segundos** (30s TTL + 10s do job)
2. Execute **"3. Get Available Seats"** novamente
3. Assentos **B1 e B2** devem voltar para `"status": "AVAILABLE"`

---

## 🏃 Teste de Concorrência Real

Para testar **race condition** com requests simultâneos:

### Opção 1: No Insomnia (manualmente)

1. Abra **"Concurrent Request 1 (Charlie)"**
2. Abra **"Concurrent Request 2 (Diana)"** em outra aba (Ctrl+T)
3. **Pressione Ctrl+Enter em AMBAS as abas ao mesmo tempo**
4. Resultado: Uma request sucede (201), outra falha (409 ou 400)

### Opção 2: Via Script Automatizado

Use o script de teste:
```bash
chmod +x test-api.sh
./test-api.sh
```

---

## 📋 Dicas de Uso

### Atalhos Úteis do Insomnia

- `Ctrl+Enter` - Enviar request
- `Ctrl+T` - Nova aba
- `Ctrl+W` - Fechar aba
- `Ctrl+K` - Busca rápida de requests
- `Ctrl+E` - Gerenciar environments

### Visualizar Respostas

- **Preview** - Formatação JSON bonita
- **Raw** - JSON bruto
- **Header** - Ver cabeçalhos HTTP

### Copiar IDs Rapidamente

Na resposta JSON:
1. Clique no campo `id` ou `reservationId`
2. Clique com botão direito → **Copy Value**
3. Cole direto nas variáveis de ambiente

---

## 🐛 Troubleshooting

### Erro: "Cannot POST /reservations/sessions//reserve"

**Causa:** Variável `session_id` está vazia.

**Solução:**
1. Execute **"1. Create Session"** primeiro
2. Copie o ID da resposta
3. Cole em **Environments** → `session_id`

### Erro 404: "Sessão não encontrada"

**Causa:** ID da sessão está errado ou expirou.

**Solução:** Crie uma nova sessão e atualize o `session_id`.

### Erro 409: "Assentos não estão disponíveis"

**Causa:** Assentos já foram reservados/vendidos.

**Solução:**
- Ver assentos disponíveis: **"3. Get Available Seats"**
- Escolher outros assentos ou aguardar expiração (40s)

### API não responde

Verifique se o Docker está rodando:
```bash
docker-compose ps
```

Se não estiver:
```bash
docker-compose up
```

---

## 🌐 Links Úteis

- **Swagger UI**: http://localhost:3000/api-docs
- **RabbitMQ Management**: http://localhost:15672 (cinema_user / cinema_pass)
- **API Base URL**: http://localhost:3000

---

## 📝 Notas Importantes

1. **Sempre execute as requests na ordem** para ter os IDs necessários
2. **Reservas expiram em 30 segundos** + 10s do background job = 40s total
3. **Race condition** só funciona se executar requests **verdadeiramente simultâneas**
4. **Idempotência** garante que confirmar pagamento 2x não cria venda duplicada
5. **Session ID muda** a cada nova sessão criada - sempre atualize a variável

---

Pronto! Agora você tem uma collection completa para testar toda a API. 🚀
