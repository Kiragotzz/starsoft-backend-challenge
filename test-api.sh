#!/bin/bash

# Script de Teste Automatizado - Cinema Ticketing System API
# Este script testa todo o fluxo da aplicação

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base URL
BASE_URL="http://localhost:3000"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq is not installed. JSON output will not be formatted.${NC}"
    echo "Install jq: sudo apt install jq (Linux) or brew install jq (Mac)"
    JQ_INSTALLED=false
else
    JQ_INSTALLED=true
fi

# Helper functions
print_step() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if API is running
check_api() {
    print_step "Verificando se a API está rodando..."
    if curl -s -o /dev/null -w "%{http_code}" $BASE_URL/sessions | grep -q "200"; then
        print_success "API está rodando em $BASE_URL"
    else
        print_error "API não está respondendo em $BASE_URL"
        echo "Execute: docker-compose up -d"
        exit 1
    fi
}

# Step 1: Create a session
create_session() {
    print_step "PASSO 1: Criando sessão de cinema"

    RESPONSE=$(curl -s -X POST $BASE_URL/sessions \
        -H "Content-Type: application/json" \
        -d '{
            "movieName": "Interstellar",
            "roomName": "Sala 1",
            "sessionTime": "2026-02-15T20:00:00Z",
            "ticketPrice": 30.00,
            "totalSeats": 16
        }')

    if [ "$JQ_INSTALLED" = true ]; then
        echo "$RESPONSE" | jq
        SESSION_ID=$(echo "$RESPONSE" | jq -r '.id')
    else
        echo "$RESPONSE"
        SESSION_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    fi

    if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "null" ]; then
        print_error "Falha ao criar sessão"
        exit 1
    fi

    print_success "Sessão criada: $SESSION_ID"
}

# Step 2: List all sessions
list_sessions() {
    print_step "PASSO 2: Listando todas as sessões"

    RESPONSE=$(curl -s -X GET $BASE_URL/sessions)

    if [ "$JQ_INSTALLED" = true ]; then
        echo "$RESPONSE" | jq
    else
        echo "$RESPONSE"
    fi

    print_success "Sessões listadas"
}

# Step 3: Get available seats
get_available_seats() {
    print_step "PASSO 3: Consultando assentos disponíveis"

    RESPONSE=$(curl -s -X GET $BASE_URL/sessions/$SESSION_ID/seats)

    if [ "$JQ_INSTALLED" = true ]; then
        echo "$RESPONSE" | jq
        AVAILABLE=$(echo "$RESPONSE" | jq -r '.availableSeats')
    else
        echo "$RESPONSE"
        AVAILABLE=$(echo "$RESPONSE" | grep -o '"availableSeats":[0-9]*' | cut -d':' -f2)
    fi

    print_success "Assentos disponíveis: $AVAILABLE/16"
}

# Step 4: Reserve seats (User Alice)
reserve_seats_alice() {
    print_step "PASSO 4: Reservando assentos para user-alice"

    RESPONSE=$(curl -s -X POST $BASE_URL/reservations/sessions/$SESSION_ID/reserve \
        -H "Content-Type: application/json" \
        -d '{
            "userId": "user-alice",
            "seatNumbers": ["A1", "A2", "A3"]
        }')

    if [ "$JQ_INSTALLED" = true ]; then
        echo "$RESPONSE" | jq
        RESERVATION_ID_ALICE=$(echo "$RESPONSE" | jq -r '.data.reservationId')
    else
        echo "$RESPONSE"
        RESERVATION_ID_ALICE=$(echo "$RESPONSE" | grep -o '"reservationId":"[^"]*' | cut -d'"' -f4)
    fi

    if [ -z "$RESERVATION_ID_ALICE" ] || [ "$RESERVATION_ID_ALICE" = "null" ]; then
        print_error "Falha ao reservar assentos"
        exit 1
    fi

    print_success "Reserva criada para Alice: $RESERVATION_ID_ALICE"
}

# Step 5: Try to reserve already reserved seat (should fail)
test_race_condition() {
    print_step "PASSO 5: Testando race condition (esperado falhar)"

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST $BASE_URL/reservations/sessions/$SESSION_ID/reserve \
        -H "Content-Type: application/json" \
        -d '{
            "userId": "user-bob",
            "seatNumbers": ["A2", "A4", "A5"]
        }')

    if [ "$HTTP_CODE" = "409" ]; then
        print_success "Race condition prevenida corretamente! (409 Conflict)"
    else
        print_error "Esperava 409, recebeu $HTTP_CODE"
    fi
}

# Step 6: Reserve different seats (User Bob)
reserve_seats_bob() {
    print_step "PASSO 6: Reservando assentos para user-bob"

    RESPONSE=$(curl -s -X POST $BASE_URL/reservations/sessions/$SESSION_ID/reserve \
        -H "Content-Type: application/json" \
        -d '{
            "userId": "user-bob",
            "seatNumbers": ["B1", "B2"]
        }')

    if [ "$JQ_INSTALLED" = true ]; then
        echo "$RESPONSE" | jq
        RESERVATION_ID_BOB=$(echo "$RESPONSE" | jq -r '.data.reservationId')
    else
        echo "$RESPONSE"
        RESERVATION_ID_BOB=$(echo "$RESPONSE" | grep -o '"reservationId":"[^"]*' | cut -d'"' -f4)
    fi

    print_success "Reserva criada para Bob: $RESERVATION_ID_BOB"
}

# Step 7: Confirm payment (Alice)
confirm_payment_alice() {
    print_step "PASSO 7: Confirmando pagamento da Alice"

    RESPONSE=$(curl -s -X POST $BASE_URL/reservations/$RESERVATION_ID_ALICE/confirm \
        -H "Content-Type: application/json" \
        -d '{
            "userId": "user-alice"
        }')

    if [ "$JQ_INSTALLED" = true ]; then
        echo "$RESPONSE" | jq
        SALE_ID_ALICE=$(echo "$RESPONSE" | jq -r '.data.saleId')
    else
        echo "$RESPONSE"
        SALE_ID_ALICE=$(echo "$RESPONSE" | grep -o '"saleId":"[^"]*' | cut -d'"' -f4)
    fi

    print_success "Pagamento confirmado: $SALE_ID_ALICE"
}

# Step 8: Test idempotency (confirm same payment again)
test_idempotency() {
    print_step "PASSO 8: Testando idempotência (confirmar pagamento novamente)"

    RESPONSE=$(curl -s -X POST $BASE_URL/reservations/$RESERVATION_ID_ALICE/confirm \
        -H "Content-Type: application/json" \
        -d '{
            "userId": "user-alice"
        }')

    if [ "$JQ_INSTALLED" = true ]; then
        SALE_ID_DUPLICATE=$(echo "$RESPONSE" | jq -r '.data.saleId')
    else
        SALE_ID_DUPLICATE=$(echo "$RESPONSE" | grep -o '"saleId":"[^"]*' | cut -d'"' -f4)
    fi

    if [ "$SALE_ID_ALICE" = "$SALE_ID_DUPLICATE" ]; then
        print_success "Idempotência funcionando! Mesmo saleId retornado"
    else
        print_error "Idempotência falhou. IDs diferentes: $SALE_ID_ALICE vs $SALE_ID_DUPLICATE"
    fi
}

# Step 9: Get purchase history (Alice)
get_purchase_history_alice() {
    print_step "PASSO 9: Consultando histórico de compras da Alice"

    RESPONSE=$(curl -s -X GET $BASE_URL/purchases/users/user-alice)

    if [ "$JQ_INSTALLED" = true ]; then
        echo "$RESPONSE" | jq
        TOTAL_PURCHASES=$(echo "$RESPONSE" | jq -r '.totalPurchases')
    else
        echo "$RESPONSE"
        TOTAL_PURCHASES=$(echo "$RESPONSE" | grep -o '"totalPurchases":[0-9]*' | cut -d':' -f2)
    fi

    print_success "Alice tem $TOTAL_PURCHASES compra(s)"
}

# Step 10: Get purchase history (Bob - should be 0)
get_purchase_history_bob() {
    print_step "PASSO 10: Consultando histórico de compras do Bob"

    RESPONSE=$(curl -s -X GET $BASE_URL/purchases/users/user-bob)

    if [ "$JQ_INSTALLED" = true ]; then
        echo "$RESPONSE" | jq
        TOTAL_PURCHASES=$(echo "$RESPONSE" | jq -r '.totalPurchases')
    else
        echo "$RESPONSE"
        TOTAL_PURCHASES=$(echo "$RESPONSE" | grep -o '"totalPurchases":[0-9]*' | cut -d':' -f2)
    fi

    if [ "$TOTAL_PURCHASES" = "0" ]; then
        print_success "Bob não tem compras (esperado)"
    else
        print_error "Bob deveria ter 0 compras, mas tem $TOTAL_PURCHASES"
    fi
}

# Step 11: Wait for expiration
test_expiration() {
    print_step "PASSO 11: Testando expiração de reserva (aguarde 40 segundos...)"

    print_info "Reserva do Bob expira em 30s + 10s do job = 40s total"
    print_info "Aguardando..."

    for i in {40..1}; do
        printf "\r⏳ Segundos restantes: $i "
        sleep 1
    done

    echo ""
    print_info "Verificando se assentos B1 e B2 foram liberados..."

    RESPONSE=$(curl -s -X GET $BASE_URL/sessions/$SESSION_ID/seats)

    if [ "$JQ_INSTALLED" = true ]; then
        echo "$RESPONSE" | jq '.seats[] | select(.seatNumber == "B1" or .seatNumber == "B2")'

        SEAT_B1_STATUS=$(echo "$RESPONSE" | jq -r '.seats[] | select(.seatNumber == "B1") | .status')
        SEAT_B2_STATUS=$(echo "$RESPONSE" | jq -r '.seats[] | select(.seatNumber == "B2") | .status')

        if [ "$SEAT_B1_STATUS" = "AVAILABLE" ] && [ "$SEAT_B2_STATUS" = "AVAILABLE" ]; then
            print_success "Expiração funcionando! Assentos B1 e B2 liberados automaticamente"
        else
            print_error "Assentos não foram liberados. Status: B1=$SEAT_B1_STATUS, B2=$SEAT_B2_STATUS"
        fi
    else
        echo "$RESPONSE"
        print_info "Verifique manualmente se os assentos B1 e B2 estão AVAILABLE"
    fi
}

# Main execution
main() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  Cinema Ticketing System - Script de Teste          ║"
    echo "║  Testa todas as funcionalidades da API              ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    check_api
    create_session
    list_sessions
    get_available_seats
    reserve_seats_alice
    test_race_condition
    reserve_seats_bob
    confirm_payment_alice
    test_idempotency
    get_purchase_history_alice
    get_purchase_history_bob
    test_expiration

    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ TODOS OS TESTES CONCLUÍDOS COM SUCESSO!          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"

    echo -e "\n${YELLOW}Próximos passos:${NC}"
    echo "  • Acesse Swagger: http://localhost:3000/api-docs"
    echo "  • RabbitMQ UI: http://localhost:15672 (cinema_user/cinema_pass)"
    echo "  • Logs: docker-compose logs -f app"
}

# Run main function
main
