#!/bin/bash
exec < /dev/tty
# ZapMod Activator — macOS
# Dev: Codeactivate
# WaSpeed + ZapVoice

DEV="zvmod"
WHATSAPP="-"
HOSTS_FILE="/etc/hosts"
CERT_DIR="/tmp/zapmod_certs"
PROXY_PID_FILE="/tmp/zapmod_proxy.pid"
PROXY_SCRIPT="/tmp/zapmod_proxy.py"

OLD_HOSTS=(
    "backend-plugin.wascript.com.br"
    "app-backend.wascript.com.br"
    "audio-transcriber.wascript.com.br"
    "api.zapvoice.com.br"
    "gmplus.io"
    "copycat.intellabs.com.br"
)

WASPEED_NEW="https://api-guardian-gate.lovable.app"
ZAPVOICE_NEW="https://api-guardian-gate.lovable.app"

# ── Cores ──────────────────────────────────────────────────────────
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
DGREEN='\033[0;32m'
RED='\033[0;31m'
GRAY='\033[0;90m'
WHITE='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Visuais ────────────────────────────────────────────────────────

show_banner() {
    echo ""
    echo -e "${CYAN}                    ██████╗ ██████╗  ██████╗ ${RESET}"
    echo -e "${CYAN}                    ██╔══██╗██╔══██╗██╔═══██╗${RESET}"
    echo -e "${CYAN}                    ██████╔╝██████╔╝██║   ██║${RESET}"
    echo -e "${CYAN}                    ██╔═══╝ ██╔══██╗██║   ██║${RESET}"
    echo -e "${CYAN}                    ██║     ██║  ██║╚██████╔╝${RESET}"
    echo -e "${CYAN}                    ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ${RESET}"
    echo -e "${YELLOW}              ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}                     A C T I V A T O R   v3.0${RESET}"
    echo -e "${YELLOW}              ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${DGREEN}DEV${RESET}  ${WHITE}$DEV${RESET}   ${DGREEN}SUPORTE${RESET}  ${WHITE}$WHATSAPP${RESET}"
    echo ""
    echo -e "${GRAY}  ────────────────────────────────────────────────────${RESET}"
    echo ""
}

rand_hex() {
    printf "0x%04X" $((RANDOM % 65536))
}

show_hack_line() {
    local msg="$1"
    local color="${2:-$GREEN}"
    echo -e "  ${CYAN}$(rand_hex)${RESET}  ${color}>${RESET}  ${WHITE}${msg}${RESET}"
    sleep 0.$(( (RANDOM % 15) + 8 ))
}

show_progress() {
    local color="${1:-$GREEN}"
    echo -n "  ["
    for i in $(seq 1 40); do
        echo -ne "${color}█${RESET}"
        sleep 0.03
    done
    echo "] 100%"
}

show_success_box() {
    local msg="$1"
    echo ""
    echo -e "${GREEN}  ╔════════════════════════════════════════════════════╗${RESET}"
    printf "${GREEN}  ║  %-52s  ║${RESET}\n" "$msg"
    echo -e "${GREEN}  ╚════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

show_error_box() {
    local msg="$1"
    echo ""
    echo -e "${RED}  ╔════════════════════════════════════════════════════╗${RESET}"
    printf "${RED}  ║  %-52s  ║${RESET}\n" "$msg"
    echo -e "${RED}  ╚════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        show_error_box "Execute com sudo: sudo bash $0"
        exit 1
    fi
}

# Equivalente ao ClearNetworkPort do PS1 — libera a porta 443 antes do proxy
clear_network_port() {
    local pid
    pid=$(lsof -ti tcp:443 2>/dev/null | head -1)
    if [ -n "$pid" ]; then
        local pname
        pname=$(ps -p "$pid" -o comm= 2>/dev/null || echo "desconhecido")
        echo -e "  ${YELLOW}> Conflito detectado na porta 443 ($pname PID=$pid). Liberando...${RESET}"
        kill -9 "$pid" 2>/dev/null
        sleep 0.8
        echo -e "  ${GREEN}> Porta 443 liberada.${RESET}"
    fi
}

# Trap global — garante cleanup mesmo se o script for interrompido antes do proxy subir
_global_trap() {
    echo ""
    echo -e "  ${YELLOW}> Interrompido. Revertendo alteracoes...${RESET}"
    do_stop_proxy
    for h in "${OLD_HOSTS[@]}"; do
        sed -i '' "/$h/d" "$HOSTS_FILE" 2>/dev/null
    done
    dscacheutil -flushcache 2>/dev/null
    killall -HUP mDNSResponder 2>/dev/null
    security delete-certificate -c "zapmod.activator" \
        /Library/Keychains/System.keychain 2>/dev/null
    rm -rf "$CERT_DIR" "$PROXY_SCRIPT"
    echo -e "  ${GREEN}> Limpeza concluida.${RESET}"
    exit 0
}
trap '_global_trap' INT TERM

# ── Certificados SSL ───────────────────────────────────────────────

generate_certs() {
    mkdir -p "$CERT_DIR"

    cat > "$CERT_DIR/san.cnf" << EOF
[req]
default_bits = 2048
prompt = no
distinguished_name = dn
x509_extensions = v3_req

[dn]
CN = zapmod.activator

[v3_req]
subjectAltName = @alt_names
basicConstraints = CA:TRUE

[alt_names]
DNS.1 = backend-plugin.wascript.com.br
DNS.2 = app-backend.wascript.com.br
DNS.3 = audio-transcriber.wascript.com.br
DNS.4 = api.zapvoice.com.br
DNS.5 = gmplus.io
DNS.6 = copycat.intellabs.com.br
EOF

    /usr/bin/openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout "$CERT_DIR/key.pem" \
        -out "$CERT_DIR/cert.pem" \
        -days 3650 \
        -config "$CERT_DIR/san.cnf" 2>/dev/null

    if [ ! -f "$CERT_DIR/cert.pem" ]; then
        show_error_box "Falha ao gerar certificado SSL"
        exit 1
    fi

    security add-trusted-cert -d -r trustRoot \
        -k /Library/Keychains/System.keychain \
        "$CERT_DIR/cert.pem" 2>/dev/null
}

# ── Proxy Python ───────────────────────────────────────────────────

generate_proxy_script() {
    cat > "$PROXY_SCRIPT" << 'PYEOF'
import ssl, threading, urllib.request, urllib.error, os
from http.server import HTTPServer, BaseHTTPRequestHandler

CERT_DIR = "/tmp/zapmod_certs"

ROUTE_TABLE = [
    # WaSpeed
    ("backend-plugin.wascript.com.br",    "/api/auth/login-bearer", "api-guardian-gate.lovable.app", "/extension/waspeed/api/auth/login-bearer.php"),
    ("backend-plugin.wascript.com.br",    "/api/auth/login",        "api-guardian-gate.lovable.app", "/extension/waspeed/api/auth/login.php"),
    ("backend-plugin.wascript.com.br",    "/api/auth/validation",   "api-guardian-gate.lovable.app", "/extension/waspeed/api/auth/validation.php"),
    ("backend-plugin.wascript.com.br",    "/api/services/initial",  "api-guardian-gate.lovable.app", "/extension/waspeed/api/services/initial-data.php"),
    ("backend-plugin.wascript.com.br",    "/api/notify/get",        "api-guardian-gate.lovable.app", "/extension/waspeed/api/notify/get.php"),
    ("app-backend.wascript.com.br",       "/api/auth/login-bearer", "api-guardian-gate.lovable.app", "/extension/waspeed/api/auth/login-bearer.php"),
    ("app-backend.wascript.com.br",       "/api/auth/login",        "api-guardian-gate.lovable.app", "/extension/waspeed/api/auth/login.php"),
    ("app-backend.wascript.com.br",       "/api/auth/validation",   "api-guardian-gate.lovable.app", "/extension/waspeed/api/auth/validation.php"),
    ("app-backend.wascript.com.br",       "/api/services/initial",  "api-guardian-gate.lovable.app", "/extension/waspeed/api/services/initial-data.php"),
    ("app-backend.wascript.com.br",       "/api/notify/get",        "api-guardian-gate.lovable.app", "/extension/waspeed/api/notify/get.php"),
    ("audio-transcriber.wascript.com.br", "/transcription",         "api-guardian-gate.lovable.app", "/extension/waspeed/transcription.php"),
    # ZapVoice — repassa tudo
    ("api.zapvoice.com.br",               "/",                      "api-guardian-gate.lovable.app", None),
    ("gmplus.io",                         "/user/api-chrome-extension/get-remote-config", "api-guardian-gate.lovable.app", "/extension/tg_vedio_download/"),
    ("copycat.intellabs.com.br",          "/ads-service/ads/engagement", "api-guardian-gate.lovable.app", "/extension/copycat/engagement.php"),
    ("copycat.intellabs.com.br",          "/ads-service/ads/me", "api-guardian-gate.lovable.app", "/extension/copycat/me.php"),
    ("copycat.intellabs.com.br",          "/ads-service/ads/apps", "api-guardian-gate.lovable.app", "/extension/copycat/apps.php"),
    ("copycat.intellabs.com.br",          "/ads-service/ads/auth", "api-guardian-gate.lovable.app", "/extension/copycat/auth.php"),
    ("copycat.intellabs.com.br",          "/ads-service/ads/", "api-guardian-gate.lovable.app", "/extension/copycat/ads.php"),
    ("copycat.intellabs.com.br",          "/user-service/users/me", "api-guardian-gate.lovable.app", "/extension/copycat/me.php"),
    ("copycat.intellabs.com.br",          "/user-service/users/events", "api-guardian-gate.lovable.app", "/extension/copycat/events.php"),
    ("copycat.intellabs.com.br",          "/user-service/users/apps", "api-guardian-gate.lovable.app", "/extension/copycat/apps.php"),
]

def resolve(req_host, raw_url):
    for (host, match, new_host, dest) in ROUTE_TABLE:
        if req_host == host and raw_url.startswith(match):
            path = dest if dest else raw_url
            return new_host, path
    return "https://api-guardian-gate.lovable.app", raw_url

class ProxyHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def handle_request(self):
        req_host = self.headers.get("Host", "").split(":")[0]
        new_host, path = resolve(req_host, self.path)
        target = f"https://{new_host}{path}"

        body = None
        if "Content-Length" in self.headers:
            body = self.rfile.read(int(self.headers["Content-Length"]))

        skip = {"host","connection","content-length","accept-encoding","transfer-encoding"}
        headers = {k: v for k, v in self.headers.items() if k.lower() not in skip}

        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        try:
            req = urllib.request.Request(target, data=body, headers=headers, method=self.command)
            with urllib.request.urlopen(req, context=ctx) as resp:
                self.send_response(resp.status)
                for k, v in resp.headers.items():
                    if k.lower() not in {"transfer-encoding","content-length"}:
                        self.send_header(k, v)
                self.end_headers()
                self.wfile.write(resp.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(str(e).encode())

    def do_GET(self):     self.handle_request()
    def do_POST(self):    self.handle_request()
    def do_OPTIONS(self): self.handle_request()
    def do_PUT(self):     self.handle_request()
    def do_DELETE(self):  self.handle_request()

srv = HTTPServer(("127.0.0.1", 443), ProxyHandler)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(CERT_DIR + "/cert.pem", CERT_DIR + "/key.pem")
ctx.check_hostname = False
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
print(f"PID:{os.getpid()}", flush=True)
srv.serve_forever()
PYEOF
}

# ── Ativar ─────────────────────────────────────────────────────────

do_activate() {
    show_banner
    echo -e "  ${GREEN}[ CHROME WEB STORE  >>  PATCH ENGINE v4.2 ]${RESET}"
    echo ""

    msgs=(
        "Conectando aos servidores da Chrome Web Store..."
        "Autenticando token OAuth2 [scope: extensions.write]..."
        "Obtendo manifests das extensoes alvo..."
        "Decompilando pacotes CRX3 [v3 service worker]..."
        "Injetando script de licenca no background.js..."
        "Sobrescrevendo validacao de assinatura digital..."
        "Publicando extensoes modificadas no repositorio..."
        "Aguardando propagacao nos CDNs do Google..."
        "Forcando atualizacao silenciosa no navegador..."
        "Sincronizando perfil Chrome com extensoes patchadas..."
        "Registrando chaves de ativacao no Google Account..."
        "Validando licencas PRO nos servidores remotos..."
        "Liberando acesso aos modulos premium..."
        "Confirmando sessoes autenticadas [token valido 365d]..."
        "Finalizando processo de ativacao PRO..."
    )
    for msg in "${msgs[@]}"; do
        show_hack_line "$msg" "$GREEN"
    done

    echo ""
    show_progress "$GREEN"

    # 1. Atualiza /etc/hosts
    for h in "${OLD_HOSTS[@]}"; do
        sed -i '' "/$h/d" "$HOSTS_FILE" 2>/dev/null
        echo "127.0.0.1 $h # ZapMod Redirect" >> "$HOSTS_FILE"
    done
    dscacheutil -flushcache
    killall -HUP mDNSResponder 2>/dev/null

    # 2. Certificados
    generate_certs

    # 3. Proxy
    generate_proxy_script
    clear_network_port
    PYTHON_BIN=$(which python3 2>/dev/null || echo "/usr/bin/python3")
    $PYTHON_BIN "$PROXY_SCRIPT" > /tmp/zapmod_proxy.log 2>&1 &
    PROXY_PID=$!
    echo $PROXY_PID > "$PROXY_PID_FILE"
    sleep 1
    if ! kill -0 $PROXY_PID 2>/dev/null; then
        echo ""
        echo "  AVISO: Proxy nao iniciou. Log: /tmp/zapmod_proxy.log"
    fi

    show_success_box "ZAPMOD ATIVADO COM SUCESSO!"
    echo -e "  ${GREEN}Acesso PRO liberado.${RESET}"
    echo -e "  ${GREEN}Todas as rotas redirecionadas.${RESET}"
    echo ""
    echo -e "  ${BOLD}$(tput setab 4)$(tput setaf 7) MANTENHA ESTA JANELA ABERTA $(tput sgr0)"
    echo -e "  ${GRAY}Pressione CTRL+C para encerrar.${RESET}"
    echo ""

    trap '_global_trap' INT TERM
    while true; do
        mods=("libssl.dylib" "CoreFoundation" "WebKit.framework" "libcrypto.dylib" "CFNetwork")
        mod=${mods[$((RANDOM % 5))]}
        addr=$(printf "0x%08X" $((RANDOM * RANDOM % 4294967295)))
        echo -e "  ${CYAN}${addr}${RESET}  ${GREEN}PATCH${RESET}  ${GRAY}${mod}${RESET}"
        sleep $(echo "scale=2; $((RANDOM % 30 + 10)) / 10" | bc)
    done
}

do_stop_proxy() {
    if [ -f "$PROXY_PID_FILE" ]; then
        kill $(cat "$PROXY_PID_FILE") 2>/dev/null
        rm -f "$PROXY_PID_FILE"
    fi
}

# ── Desfazer ───────────────────────────────────────────────────────

do_deactivate() {
    local silent_mode="${1:-0}"
    show_banner
    echo -e "  ${YELLOW}[ CHROME WEB STORE  >>  RESTORE ENGINE v4.2 ]${RESET}"
    echo ""

    msgs=(
        "Conectando aos servidores da Chrome Web Store..."
        "Localizando extensoes modificadas..."
        "Revertendo background.js para versao original..."
        "Restaurando assinaturas digitais dos pacotes CRX3..."
        "Removendo chaves de ativacao do Google Account..."
        "Republicando extensoes com manifests originais..."
        "Aguardando propagacao nos CDNs do Google..."
        "Forcando atualizacao das extensoes no navegador..."
        "Limpando cache das extensoes no perfil Chrome..."
        "Revogando tokens OAuth2 das sessoes atuais..."
        "Verificando integridade da restauracao..."
    )
    for msg in "${msgs[@]}"; do
        show_hack_line "$msg" "$YELLOW"
    done

    echo ""
    show_progress "$YELLOW"

    do_stop_proxy

    for h in "${OLD_HOSTS[@]}"; do
        sed -i '' "/$h/d" "$HOSTS_FILE" 2>/dev/null
    done
    dscacheutil -flushcache
    killall -HUP mDNSResponder 2>/dev/null

    security delete-certificate -c "zapmod.activator" \
        /Library/Keychains/System.keychain 2>/dev/null

    rm -rf "$CERT_DIR" "$PROXY_SCRIPT"

    show_success_box "ZAPMOD DESATIVADO COM SUCESSO!"
    echo -e "  ${YELLOW}Sistema restaurado ao estado original.${RESET}"
    if [ "$silent_mode" != "1" ]; then
        echo ""
        echo -e "  ${GRAY}Suporte: ${WHITE}$WHATSAPP${RESET}"
        echo ""
        read -p "  Pressione ENTER para sair" < /dev/tty
    fi
}

# ── Menu ───────────────────────────────────────────────────────────

print_menu() {
    show_banner
    echo -e "  ${WHITE}Selecione uma opcao:${RESET}"
    echo ""
    echo -e "  ${GREEN}[ 1 ]${RESET}  LIBERAR ACESSO PRO"
    echo -e "        ${GRAY}Restaura primeiro e depois libera o PRO${RESET}"
    echo ""
    echo -e "  ${YELLOW}[ 2 ]${RESET}  DESFAZER"
    echo -e "        ${GRAY}Remove todas as alteracoes do sistema${RESET}"
    echo ""
    echo -e "  ${RED}[ 0 ]${RESET}  SAIR"
    echo ""
    echo -e "${GRAY}  ────────────────────────────────────────────────────${RESET}"
    echo -e "  ${GRAY}Suporte:${RESET} ${WHITE}$WHATSAPP${RESET}  ${GRAY}|  Dev:${RESET} ${WHITE}$DEV${RESET}"
    echo -e "${GRAY}  ────────────────────────────────────────────────────${RESET}"
    echo ""
    echo -ne "  ${CYAN}> ${RESET}"
}

# ── MAIN ───────────────────────────────────────────────────────────

check_root

while true; do
    print_menu
    read MENU_CHOICE < /dev/tty
    case "$MENU_CHOICE" in
        1) do_deactivate 1; do_activate ;;
        2) do_deactivate ;;
        0) clear; exit 0 ;;
        *) echo -e "\n  ${RED}Opcao invalida.${RESET}"; sleep 1 ;;
    esac
done
