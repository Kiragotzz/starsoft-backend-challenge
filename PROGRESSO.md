# Progresso do Desenvolvimento - Sistema de Cinema

## Resumo do Projeto
Sistema de venda de ingressos para cinema com controle de concorrência usando Node.js, NestJS, PostgreSQL, Redis e RabbitMQ.

---

## ✅ O que está implementado

### 1. Infraestrutura (Docker)
- ✅ Docker Compose configurado
- ✅ PostgreSQL (porta 5432)
- ✅ Redis (porta 6379)
- ✅ RabbitMQ com Management UI (portas 5672, 15672)
- ✅ Healthchecks para todos os serviços
- ✅ Aplicação NestJS configurada

### 2. Arquitetura do Código
- ✅ Clean Architecture implementada
  - `domain/` - Entidades e interfaces de repositórios
  - `infrastructure/` - Implementações concretas (controllers, TypeORM, etc)
  - `usecases/` - Casos de uso (lógica de negócio)
- ✅ TypeORM configurado e conectado ao PostgreSQL
- ✅ ConfigModule global para variáveis de ambiente
- ✅ RedisModule global para locks distribuídos

### 3. Entidades de Domínio
- ✅ **Session** (Sessão de Cinema)
  - Campos: movieName, roomName, sessionTime, ticketPrice, totalSeats
  - Validações: nome do filme, sala, horário, preço > 0, mínimo 16 assentos
  - Entidade TypeORM criada e registrada

- ✅ **Seat** (Assento)
  - Campos: sessionId, seatNumber, status, reservedBy, reservedUntil
  - Enum SeatStatus: AVAILABLE, RESERVED, SOLD
  - Métodos de negócio: `isAvailable()`, `reserve()`, `confirmSale()`, `release()`
  - Lógica de expiração de reserva implementada
  - Entidade TypeORM criada e registrada
  - Geração automática de assentos ao criar sessão (A1, A2, B1, etc)

- ✅ **Reservation** (Reserva Temporária)
  - Campos: id, sessionId, userId, seatIds[], status, expiresAt
  - Status: PENDING, CONFIRMED, EXPIRED, CANCELLED
  - Métodos: `isExpired()`, `isActive()`, `canConfirm()`, `confirm()`, `expire()`, `cancel()`
  - Validação completa
  - Entidade TypeORM criada e registrada

- ✅ **Sale** (Venda Confirmada)
  - Campos: id, reservationId, sessionId, userId, seatIds[], totalPrice, paidAt
  - Validação completa
  - Entidade TypeORM criada e registrada

### 4. Repositórios
- ✅ **SeatRepository** (interface + TypeORM)
  - findById, findBySessionId, findAvailableBySessionId, findBySeatNumbers
  - save, saveMany, update, updateMany

- ✅ **ReservationRepository** (interface + TypeORM)
  - findById, findByUserId, findBySessionId, findExpiredReservations
  - save, update

- ✅ **SaleRepository** (interface + TypeORM)
  - findById, findByUserId, findBySessionId, findByReservationId
  - save

- ✅ **SessionRepository** (interface + TypeORM)
  - findById, findAll, create

### 5. Controle de Concorrência (CRÍTICO!)
- ✅ **RedisLockService** - Serviço de locks distribuídos
  - `acquireLock()` - Adquire lock com retry automático
  - `releaseLock()` - Libera lock com Lua script atômico
  - `withLock()` - Executa função dentro de lock
  - `acquireMultipleLocks()` - Adquire múltiplos locks (ordenados para evitar deadlock)
  - `releaseMultipleLocks()` - Libera múltiplos locks
  - TTL configurável (padrão 10s)
  - Prevenção de deadlocks com ordenação de chaves

### 6. Casos de Uso (UseCases)
- ✅ **CreateSession** - Criar sessão + gerar assentos automaticamente
- ✅ **FindAllSessions** - Listar todas as sessões
- ✅ **ReserveSeats** - Reservar assentos com controle de concorrência
  - Validação de entrada
  - Verificação de sessão
  - Locks distribuídos em TODOS os assentos solicitados
  - Verificação de disponibilidade real dentro do lock
  - Criação de reserva temporária (30s)
  - Atualização de assentos para RESERVED
  - Liberação automática de locks (finally block)
  - Prevenção de race conditions
  - Publicação de evento `reservation.created`

- ✅ **ConfirmPayment** - Confirmar pagamento e converter em venda
  - Validação de reserva (existe, pertence ao usuário, não expirou)
  - Idempotência (retorna venda existente se já confirmada)
  - Criação de venda com preço calculado
  - Atualização de assentos para SOLD
  - Confirmação da reserva
  - Publicação de evento `payment.confirmed`

- ✅ **ExpireReservations** - Expirar reservas não confirmadas (Background Job)
  - Busca reservas PENDING com expiresAt < now
  - Atualiza status para EXPIRED
  - Libera assentos (status = AVAILABLE)
  - Publicação de evento `reservation.expired`
  - Retorna estatísticas (quantas expiradas, assentos liberados)

### 7. Sistema de Mensageria (RabbitMQ)
- ✅ **RabbitMQPublisherService** - Publicação confiável de eventos
  - Conexão automática com retry
  - Configuração de exchanges e queues
  - Dead Letter Queue (DLQ) configurado
  - Métodos tipados: `publishReservationCreated()`, `publishPaymentConfirmed()`, etc

- ✅ **Eventos Publicados**
  - `reservation.created` - Quando reserva é criada (integrado no ReserveSeat UseCase)
  - `payment.confirmed` - Quando pagamento é confirmado (integrado no ConfirmPayment UseCase)
  - `reservation.expired` - Quando reserva expira (integrado no ExpireReservations UseCase)
  - `seat.released` - Quando assento é liberado (preparado)

- ✅ **RabbitMQConsumerService** - Consumer de exemplo
  - Consumo confiável com ACK/NACK
  - Retry automático com backoff exponencial (até 3 tentativas)
  - Mensagens com falha vão para DLQ
  - Demonstra boas práticas de consumo

- ✅ **Filas Configuradas**
  - `cinema.reservations.created` → processa eventos de reserva
  - `cinema.payments.confirmed` → processa eventos de pagamento
  - `cinema.reservations.expired` → processa expiração (preparado)
  - `cinema.seats.released` → processa liberação (preparado)
  - `cinema.events.dead-letter` → DLQ para mensagens com falha

### 8. Background Jobs (Scheduled Tasks)
- ✅ **ReservationExpirationSchedulerService** - Job agendado para expiração
  - Executa a cada 10 segundos (configurável via cron)
  - Chama ExpireReservationsUseCase
  - Previne execução concorrente (lock interno)
  - Logging de estatísticas (quantas reservas expiradas)
  - Tratamento de erros robusto

### 9. API REST (Controllers)
- ✅ **POST /sessions** - Criar sessão
- ✅ **GET /sessions** - Listar sessões
- ✅ **POST /reservations/sessions/:sessionId/reserve** - Reservar assentos
- ✅ **POST /reservations/:reservationId/confirm** - Confirmar pagamento

---

## ⏳ Em Desenvolvimento / Próximos Passos

### 1. Casos de Uso Adicionais - PRÓXIMA PRIORIDADE
- ❌ **GetAvailableSeats** - Buscar assentos disponíveis em tempo real
  - Retornar lista de assentos com status AVAILABLE ou RESERVED mas expirado
- ❌ **GetUserPurchaseHistory** - Histórico de compras do usuário
  - Buscar vendas por userId
  - Retornar com detalhes da sessão
- ❌ **CancelReservation** - Cancelar reserva manualmente
  - Validar que reserva está PENDING
  - Atualizar status para CANCELLED
  - Liberar assentos

### 2. API REST Adicional
- ❌ **GET /sessions/:sessionId/seats** - Ver disponibilidade de assentos
- ❌ **GET /users/:userId/purchases** - Histórico de compras
- ❌ **DELETE /reservations/:id** - Cancelar reserva

### 3. Melhorias de Segurança e Validação
- ❌ Implementar autenticação JWT (opcional)
- ❌ Rate limiting por IP/usuário
- ❌ Validação mais robusta com class-validator nos DTOs
- ❌ Tratamento de erros centralizado (Exception Filters)

### 4. Observabilidade e Melhorias
- ❌ Logging estruturado (Winston ou Pino)
- ❌ Métricas de performance
- ❌ Health check endpoint detalhado
- ❌ Job para limpar dados antigos (opcional)

---

## 🎯 Prioridades Imediatas (Próxima Sessão)

1. **Completar registro de Seats no TypeORM**
2. **Criar entidades Reservation e Sale**
3. **Implementar caso de uso ReserveSeat com lock distribuído**
4. **Configurar RabbitMQ no NestJS**
5. **Implementar endpoint POST /sessions/:sessionId/reserve**

---

## ✅ Pontos Críticos RESOLVIDOS

### Race Conditions ✅ RESOLVIDO
- **Problema**: Múltiplos usuários tentando reservar o mesmo assento simultaneamente
- **Solução Implementada**:
  - Locks distribuídos com Redis (RedisLockService)
  - Método `acquireMultipleLocks()` adquire locks em TODOS os assentos antes de verificar disponibilidade
  - Locks são liberados automaticamente no finally block
  - TTL de 5 segundos para evitar locks eternos em caso de crash
  - Retry automático com backoff

### Deadlocks ✅ RESOLVIDO
- **Problema**: Usuários tentando reservar assentos na mesma sessão simultaneamente podem causar deadlock
- **Solução Implementada**:
  - Ordenação de chaves de lock antes de adquiri-los (sempre na mesma ordem alfabética)
  - Implementado em `acquireMultipleLocks()` com `sort()`
  - Se falhar em adquirir qualquer lock, TODOS os locks já adquiridos são liberados

### Idempotência ✅ PARCIALMENTE RESOLVIDO
- **Problema**: Cliente reenviando mesma requisição por timeout
- **Solução Implementada no ConfirmPayment**:
  - Verifica se já existe venda para a reserva (`findByReservationId`)
  - Se já confirmado, retorna venda existente ao invés de erro
- **Pendente na ReserveSeat**: Request ID único + cache no Redis

### Expiração de Reservas ✅ RESOLVIDO
- **Problema**: Reservas devem expirar automaticamente após 30 segundos
- **Solução Implementada**:
  - Reservas têm campo `expiresAt` (30s após criação)
  - Método `isExpired()` na entidade Reservation
  - Query `findExpiredReservations()` no repositório
  - **Background Job** rodando a cada 10 segundos (ReservationExpirationSchedulerService)
  - ExpireReservationsUseCase processa reservas expiradas
  - Atualiza status para EXPIRED
  - Libera assentos automaticamente (status = AVAILABLE)
  - Publica evento `reservation.expired` no RabbitMQ

---

## 📊 Cobertura dos Requisitos

### Requisitos Obrigatórios
| Requisito | Status | Observações |
|-----------|--------|-------------|
| Docker Compose completo | ✅ | PostgreSQL, Redis, RabbitMQ, App com healthchecks |
| API REST - Gestão de Sessões | ✅ | Criar sessões + gerar assentos automaticamente, listar sessões |
| API REST - Reserva de Assentos | ✅ | POST /reservations/sessions/:id/reserve com validação de 30s |
| API REST - Confirmação de Pagamento | ✅ | POST /reservations/:id/confirm com idempotência |
| API REST - Consultas | 🟡 | Parcial (falta endpoint GET disponibilidade e histórico) |
| Mensageria Assíncrona | ✅ | **RabbitMQ integrado** - publica eventos (reservation.created, payment.confirmed, reservation.expired), consumer com retry e DLQ |
| Controle de Concorrência | ✅ | **Redis Locks Distribuídos implementados** - previne race conditions |
| Logging Estruturado | 🟡 | Logging básico com Logger do NestJS, falta Winston/Pino |
| Clean Code e SOLID | ✅ | Clean Architecture, separação de responsabilidades, injeção de dependências |

### Requisitos Diferenciais (Opcionais)
| Requisito | Status | Observações |
|-----------|--------|-------------|
| Documentação Swagger | ❌ | Pendente |
| Testes Unitários | ❌ | Pendente |
| Dead Letter Queue | ❌ | Pendente |
| Retry com Backoff | ❌ | Pendente |
| Processamento em Batch | ❌ | Pendente |
| Testes de Concorrência | ❌ | Pendente |
| Rate Limiting | ❌ | Pendente |

---

## 🚀 Como Testar o que está Pronto

### 1. Subir o ambiente
```bash
cd /home/luis/Documentos/Projetos/starsoft-backend-challenge
docker-compose up --build
```

### 2. Criar uma sessão (gera assentos automaticamente)
```bash
curl -X POST http://localhost:3000/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "movieName": "Filme Teste",
    "roomName": "Sala 1",
    "sessionTime": "2026-02-09T19:00:00Z",
    "ticketPrice": 25.00,
    "totalSeats": 16
  }'

# Resposta esperada:
# {
#   "id": "uuid-aqui",
#   "movieName": "Filme Teste",
#   "roomName": "Sala 1",
#   "sessionTime": "2026-02-09T19:00:00Z",
#   "ticketPrice": 25.00,
#   "totalSeats": 16
# }
```

### 3. Listar sessões
```bash
curl http://localhost:3000/sessions
```

### 4. Reservar assentos (com controle de concorrência)
```bash
# Substitua SESSION_ID pelo ID da sessão criada
curl -X POST http://localhost:3000/reservations/sessions/SESSION_ID/reserve \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "seatNumbers": ["A1", "A2"]
  }'

# Resposta esperada:
# {
#   "success": true,
#   "data": {
#     "reservationId": "uuid-reserva",
#     "sessionId": "uuid-sessao",
#     "userId": "user123",
#     "seatNumbers": ["A1", "A2"],
#     "expiresAt": "2026-02-09T19:00:30Z",
#     "expiresInSeconds": 30
#   }
# }
```

### 5. Confirmar pagamento (converter reserva em venda)
```bash
# Substitua RESERVATION_ID pelo ID da reserva criada
curl -X POST http://localhost:3000/reservations/RESERVATION_ID/confirm \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123"
  }'

# Resposta esperada:
# {
#   "success": true,
#   "data": {
#     "saleId": "uuid-venda",
#     "reservationId": "uuid-reserva",
#     "sessionId": "uuid-sessao",
#     "userId": "user123",
#     "seatNumbers": ["A1", "A2"],
#     "totalPrice": 50.00,
#     "paidAt": "2026-02-09T19:00:15Z"
#   }
# }
```

### 6. Testar Race Condition (múltiplos usuários tentando reservar mesmo assento)
```bash
# Em um terminal:
curl -X POST http://localhost:3000/reservations/sessions/SESSION_ID/reserve \
  -H "Content-Type: application/json" \
  -d '{"userId": "user1", "seatNumbers": ["B1"]}' &

# Imediatamente em outro terminal:
curl -X POST http://localhost:3000/reservations/sessions/SESSION_ID/reserve \
  -H "Content-Type: application/json" \
  -d '{"userId": "user2", "seatNumbers": ["B1"]}' &

# Resultado esperado: Apenas 1 usuário consegue reservar, o outro recebe erro
```

### 7. Verificar Eventos no RabbitMQ

**Acessar Management UI:**
```
http://localhost:15672
User: cinema_user
Pass: cinema_pass
```

**O que verificar:**
1. **Exchanges** → `cinema.events` deve existir (tipo: topic)
2. **Queues** → Devem existir:
   - `cinema.reservations.created`
   - `cinema.payments.confirmed`
   - `cinema.reservations.expired`
   - `cinema.seats.released`
   - `cinema.events.dead-letter` (DLQ)

3. **Após criar reserva** → Vá em "Queues" → `cinema.reservations.created` → "Get messages"
   - Deve aparecer evento com dados da reserva

4. **Após confirmar pagamento** → Vá em "Queues" → `cinema.payments.confirmed`
   - Deve aparecer evento com dados da venda

**Logs da aplicação:**
```bash
# Veja os logs do consumer processando eventos
docker logs -f cinema-app | grep "Processing.*event"

# Exemplo de saída esperada:
# [RabbitMQConsumerService] Processing reservation.created event: { reservationId: '...', userId: 'user123', ... }
# [RabbitMQConsumerService] Successfully processed reservation.created event
```

### 8. Testar Expiração Automática de Reservas (Background Job)

**Criar reserva e aguardar expiração:**
```bash
# 1. Criar reserva (expira em 30s)
curl -X POST http://localhost:3000/reservations/sessions/SESSION_ID/reserve \
  -H "Content-Type: application/json" \
  -d '{"userId": "test_user", "seatNumbers": ["C1"]}'

# 2. Ver logs do background job (roda a cada 10s)
docker logs -f cinema-app | grep "ReservationExpirationScheduler"

# Após 30 segundos, você verá algo como:
# [ReservationExpirationSchedulerService] Found 1 expired reservations to process
# [ExpireReservationsUseCase] Processing expired reservation: <uuid>
# [ExpireReservationsUseCase] Released 1 seats from reservation <uuid>
# [ReservationExpirationSchedulerService] Expired 1 reservations, released 1 seats

# 3. Verificar que assento foi liberado
# Tente reservar o mesmo assento C1 novamente - deve funcionar!
curl -X POST http://localhost:3000/reservations/sessions/SESSION_ID/reserve \
  -H "Content-Type: application/json" \
  -d '{"userId": "another_user", "seatNumbers": ["C1"]}'

# Deve retornar sucesso (200 OK) porque o assento foi liberado
```

**Verificar evento reservation.expired no RabbitMQ:**
1. Acesse http://localhost:15672
2. Vá em "Queues" → `cinema.reservations.expired`
3. Click em "Get messages"
4. Deve aparecer evento com dados da reserva expirada

---

## 📝 Decisões Técnicas Tomadas

1. **Clean Architecture**: Separação clara entre domínio, casos de uso e infraestrutura
2. **TypeORM**: ORM escolhido para facilitar operações com PostgreSQL
3. **Validação no Domínio**: Entidades de domínio contêm suas próprias validações
4. **RabbitMQ**: Escolhido para mensageria por ser robusto e ter boa integração com NestJS
5. **Redis**: Para locks distribuídos e cache de alta performance

---

## 🐛 Problemas Conhecidos

1. SeatTypeORM não está registrado no AppModule.entities
2. Sem tratamento de erros centralizado
3. Sem logging estruturado ainda
4. Sem validação com class-validator nos DTOs

---

---

## 🎉 Implementado Nesta Sessão (2026-02-08)

### Funcionalidades Principais
1. ✅ Sistema completo de reserva de assentos com controle de concorrência
2. ✅ Locks distribuídos com Redis (prevenção de race conditions e deadlocks)
3. ✅ Confirmação de pagamento com idempotência
4. ✅ Geração automática de assentos ao criar sessão
5. ✅ **Sistema de mensageria assíncrona com RabbitMQ**
6. ✅ **Publicação de eventos e consumer de exemplo**
7. ✅ **Background Job para expiração automática de reservas**

### Código Criado

**Primeira Etapa - Core do Sistema:**
- 4 entidades de domínio completas (Session, Seat, Reservation, Sale)
- 4 repositórios com interfaces + implementações TypeORM
- 3 casos de uso principais (CreateSession, ReserveSeat, ConfirmPayment)
- 2 controllers REST (Sessions, Reservations)
- 1 serviço de lock distribuído (RedisLockService) com 7 métodos
- 4 entidades TypeORM com relacionamentos e índices otimizados

**Segunda Etapa - Mensageria:**
- 1 serviço de publicação (RabbitMQPublisherService) com configuração automática de exchanges/queues
- 1 serviço de consumo (RabbitMQConsumerService) com retry e DLQ
- 4 tipos de eventos definidos (reservation.created, payment.confirmed, reservation.expired, seat.released)
- Integração nos UseCases para publicar eventos automaticamente

**Terceira Etapa - Background Jobs:**
- 1 UseCase de expiração (ExpireReservationsUseCase)
- 1 serviço de scheduler (ReservationExpirationSchedulerService) com cron job (a cada 10s)
- Integração com @nestjs/schedule
- Publicação automática de eventos reservation.expired

### Decisões Técnicas Importantes

**Controle de Concorrência:**
1. **Locks Ordenados**: Sempre ordena chaves alfabeticamente antes de adquirir para evitar deadlocks
2. **Finally Block**: Garante liberação de locks mesmo em caso de exceção
3. **Idempotência**: ConfirmPayment verifica se já existe venda antes de criar nova

**Geração de Dados:**
4. **Assentos Automáticos**: Gera formato "A1, A2, B1, B2..." (8 assentos por fileira)
5. **Validação em Camadas**: Validação nos DTOs, entidades de domínio e UseCases

**Mensageria:**
6. **Publicação Assíncrona**: Eventos são publicados sem bloquear resposta (catch errors)
7. **Retry com Backoff**: Consumer tenta até 3x com delay exponencial (1s, 2s, 4s)
8. **Dead Letter Queue**: Mensagens com falha após 3 tentativas vão para DLQ
9. **Exchanges Topic**: Permite roteamento flexível de mensagens
10. **Confirmações**: Mensagens persistentes e com confirmação de entrega

### Arquitetura do RabbitMQ

```
Publisher (UseCase)
    ↓
Exchange: cinema.events (topic)
    ↓
Queues:
  - cinema.reservations.created
  - cinema.payments.confirmed
  - cinema.reservations.expired
  - cinema.seats.released
    ↓
Consumer (processa eventos)
    ↓ (se falhar 3x)
DLQ Exchange: cinema.events.dlq
    ↓
DLQ Queue: cinema.events.dead-letter
```

**Mensageria:**
6. **Publicação Assíncrona**: Eventos são publicados sem bloquear resposta (catch errors)
7. **Retry com Backoff**: Consumer tenta até 3x com delay exponencial (1s, 2s, 4s)
8. **Dead Letter Queue**: Mensagens com falha após 3 tentativas vão para DLQ
9. **Exchanges Topic**: Permite roteamento flexível de mensagens
10. **Confirmações**: Mensagens persistentes e com confirmação de entrega

**Background Jobs:**
11. **Cron Scheduling**: Job executa a cada 10 segundos (configurável)
12. **Prevenção de Concorrência**: Flag isRunning previne execução simultânea do job
13. **Estatísticas**: Retorna quantas reservas foram expiradas e assentos liberados
14. **Tratamento de Erros**: Continua processando mesmo se uma reserva falhar

### Próximas Prioridades
1. **Endpoints de Consulta** - GET assentos disponíveis, histórico de compras
2. **Testes Automatizados** - Testes de unidade e integração
3. **Documentação Swagger** - API docs automática

---

**Última Atualização**: 2026-02-08 (Sessão Atual - Background Job Implementado)
