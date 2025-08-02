#!/bin/bash

# Script per installare Open WebUI e Ollama con Docker
# Autore: Assistant
# Data: $(date +%Y-%m-%d)

set -e  # Esce in caso di errore

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzione per stampare messaggi colorati
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Funzione per controllare se Docker è installato
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker non è installato. Installa Docker prima di continuare."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker non è in esecuzione o non hai i permessi necessari."
        print_warning "Prova: sudo systemctl start docker"
        print_warning "Oppure aggiungi il tuo utente al gruppo docker: sudo usermod -aG docker \$USER"
        exit 1
    fi
    
    print_success "Docker è installato e funzionante"
}

# Funzione per creare la rete Docker
create_network() {
    local network_name="ollama-network"
    
    if docker network ls | grep -q "$network_name"; then
        print_warning "La rete $network_name esiste già"
    else
        print_status "Creazione della rete Docker: $network_name"
        docker network create "$network_name"
        print_success "Rete $network_name creata con successo"
    fi
}

# Funzione per controllare e gestire container esistenti
check_existing_containers() {
    local ollama_exists=false
    local webui_exists=false
    
    if docker ps -a | grep -q "ollama"; then
        ollama_exists=true
    fi
    
    if docker ps -a | grep -q "open-webui"; then
        webui_exists=true
    fi
    
    if [ "$ollama_exists" = true ] || [ "$webui_exists" = true ]; then
        echo
        print_warning "Container esistenti trovati:"
        [ "$ollama_exists" = true ] && echo "  - ollama"
        [ "$webui_exists" = true ] && echo "  - open-webui"
        echo
        read -p "Vuoi rimuovere i container esistenti e reinstallare? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Rimozione container esistenti..."
            
            if [ "$ollama_exists" = true ]; then
                docker stop ollama 2>/dev/null || true
                docker rm ollama 2>/dev/null || true
                print_success "Container ollama rimosso"
            fi
            
            if [ "$webui_exists" = true ]; then
                docker stop open-webui 2>/dev/null || true
                docker rm open-webui 2>/dev/null || true
                print_success "Container open-webui rimosso"
            fi
            
            return 0  # Procedi con l'installazione
        else
            print_status "Container esistenti mantenuti."
            
            # Verifica se i container sono in esecuzione
            if [ "$ollama_exists" = true ] && ! docker ps | grep -q "ollama"; then
                print_status "Avvio container ollama..."
                docker start ollama
            fi
            
            if [ "$webui_exists" = true ] && ! docker ps | grep -q "open-webui"; then
                print_status "Avvio container open-webui..."
                docker start open-webui
            fi
            
            return 1  # Salta l'installazione
        fi
    fi
    
    return 0  # Nessun container esistente, procedi
}

# Funzione per installare Ollama
install_ollama() {
    local container_name="ollama"
    local network_name="ollama-network"
    
    print_status "Installazione di Ollama..."
    
    # Avvia Ollama
    docker run -d \
        --name "$container_name" \
        --network "$network_name" \
        -p 11434:11434 \
        -v ollama_data:/root/.ollama \
        --restart unless-stopped \
        ollama/ollama
    
    print_success "Ollama avviato con successo"
    
    # Attendi che Ollama sia pronto
    print_status "Attendo che Ollama sia pronto..."
    sleep 10
    
    # Verifica che Ollama sia raggiungibile
    if curl -s http://localhost:11434/api/tags &>/dev/null; then
        print_success "Ollama è pronto e raggiungibile"
    else
        print_warning "Ollama potrebbe non essere ancora completamente pronto"
    fi
}

# Funzione per installare Open WebUI
install_openwebui() {
    local container_name="open-webui"
    local network_name="ollama-network"
    
    print_status "Installazione di Open WebUI..."
    
    # Avvia Open WebUI
    docker run -d \
        --name "$container_name" \
        --network "$network_name" \
        -p 3000:8080 \
        -e OLLAMA_BASE_URL=http://ollama:11434 \
        -v open-webui:/app/backend/data \
        --restart unless-stopped \
        ghcr.io/open-webui/open-webui:main
    
    print_success "Open WebUI avviato con successo"
}

# Funzione per scaricare un modello di default
download_default_model() {
    local model="llama3.2"
    
    print_status "Download del modello di default: $model"
    print_warning "Questo potrebbe richiedere diversi minuti..."
    
    if docker exec ollama ollama pull "$model"; then
        print_success "Modello $model scaricato con successo"
    else
        print_error "Errore durante il download del modello $model"
        print_warning "Puoi scaricarlo manualmente in seguito con: docker exec ollama ollama pull $model"
    fi
}

# Funzione per mostrare lo stato dei servizi
show_status() {
    print_status "Stato dei servizi:"
    echo
    docker ps --filter "name=ollama" --filter "name=open-webui" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo
    print_status "Comandi utili:"
    echo "- Visualizza logs Ollama: docker logs -f ollama"
    echo "- Visualizza logs Open WebUI: docker logs -f open-webui"
    echo "- Scarica un modello: docker exec ollama ollama pull <nome_modello>"
    echo "- Lista modelli: docker exec ollama ollama list"
}

# Funzione per mostrare i link finali
show_final_links() {
    echo
    echo "================================================"
    echo -e "${GREEN}🎉 INSTALLAZIONE COMPLETATA CON SUCCESSO! 🎉${NC}"
    echo "================================================"
    echo
    echo -e "${BLUE}📋 SERVIZI DISPONIBILI:${NC}"
    echo
    echo -e "${GREEN}🌐 Open WebUI${NC}"
    echo -e "   URL: ${YELLOW}http://localhost:3000${NC}"
    echo -e "   Descrizione: Interfaccia web per interagire con i modelli AI"
    echo
    echo -e "${GREEN}🤖 Ollama API${NC}"
    echo -e "   URL: ${YELLOW}http://localhost:11434${NC}"
    echo -e "   Descrizione: API REST per gestire e utilizzare i modelli"
    echo
    echo "================================================"
    echo -e "${BLUE}🚀 ACCESSO RAPIDO:${NC}"
    echo
    echo -e "👉 Apri il browser e vai su: ${GREEN}http://localhost:3000${NC}"
    echo -e "👉 Crea un account nella prima schermata"
    echo -e "👉 Inizia a chattare con i tuoi modelli AI!"
    echo
    echo "================================================"
}

# Funzione per il cleanup in caso di errore
cleanup_on_error() {
    print_error "Errore durante l'installazione. Pulizia in corso..."
    docker stop ollama open-webui 2>/dev/null || true
    docker rm ollama open-webui 2>/dev/null || true
    exit 1
}

# Funzione principale
main() {
    print_status "Avvio installazione Open WebUI + Ollama"
    echo "================================================"
    
    # Trap per gestire interruzioni
    trap cleanup_on_error ERR
    
    check_docker
    
    # Controlla container esistenti
    if ! check_existing_containers; then
        # Se l'utente ha scelto di non rimuovere i container esistenti
        print_status "I container esistenti sono stati mantenuti e avviati se necessario."
        show_final_links
        show_status
        exit 0
    fi
    
    create_network
    install_ollama
    install_openwebui
    
    # Chiedi se scaricare un modello di default
    echo
    read -p "Vuoi scaricare il modello llama3.2 di default? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        download_default_model
    else
        print_warning "Modello non scaricato. Ricorda di scaricare almeno un modello per usare Open WebUI."
    fi
    
    show_final_links
    
    echo -e "${BLUE}🔧 GESTIONE SERVIZI:${NC}"
    echo "- Fermare i servizi: docker stop ollama open-webui"
    echo "- Riavviare i servizi: docker start ollama open-webui"
    echo "- Rimuovere tutto: docker stop ollama open-webui && docker rm ollama open-webui && docker network rm ollama-network"
    echo
    show_status
}

# Esegui solo se il script è chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
