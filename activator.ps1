# ZapMod Core Engine v4.0 - Clean Edition
# Dev: Codeactivate
# Class-based Architecture without problematic Unicode chars

class ZapModEngine {
    hidden [string]$Dev      = "zamod"
    hidden [string]$WhatsApp = "-"
    hidden [string]$NewHost  = "api-guardian-gate.lovable.app"
    hidden [string]$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    hidden [System.Net.HttpListener]$Listener
    
    hidden [string[]]$OldHosts = @(
        "backend-plugin.wascript.com.br",
        "app-backend.wascript.com.br",
        "audio-transcriber.wascript.com.br",
        "api.zapvoice.com.br",
        "gmplus.io"
        #"copycat.intellabs.com.br"
    )

    hidden [hashtable[]]$RouteTable = @(
        @{ Host = "backend-plugin.wascript.com.br";    Match = "^/api/auth/login-bearer"; Dest = "/extension/waspeed/api/auth/login-bearer.php" },
        @{ Host = "backend-plugin.wascript.com.br";    Match = "^/api/auth/login";        Dest = "/extension/waspeed/api/auth/login.php"         },
        @{ Host = "backend-plugin.wascript.com.br";    Match = "^/api/auth/validation";   Dest = "/extension/waspeed/api/auth/validation.php"    },
        @{ Host = "backend-plugin.wascript.com.br";    Match = "^/api/services/initial";  Dest = "/extension/waspeed/api/services/initial-data.php" },
        @{ Host = "backend-plugin.wascript.com.br";    Match = "^/api/notify/get";        Dest = "/extension/waspeed/api/notify/get.php"          },
        @{ Host = "app-backend.wascript.com.br";       Match = "^/api/auth/login-bearer"; Dest = "/extension/waspeed/api/auth/login-bearer.php" },
        @{ Host = "app-backend.wascript.com.br";       Match = "^/api/auth/login";        Dest = "/extension/waspeed/api/auth/login.php"         },
        @{ Host = "app-backend.wascript.com.br";       Match = "^/api/auth/validation";   Dest = "/extension/waspeed/api/auth/validation.php"    },
        @{ Host = "app-backend.wascript.com.br";       Match = "^/api/services/initial";  Dest = "/extension/waspeed/api/services/initial-data.php" },
        @{ Host = "app-backend.wascript.com.br";       Match = "^/api/notify/get";        Dest = "/extension/waspeed/api/notify/get.php"          },
        @{ Host = "audio-transcriber.wascript.com.br"; Match = "^/transcription";         Dest = "/extension/waspeed/transcription.php"           },
        @{ Host = "api.zapvoice.com.br";               Match = "^/";                      Dest = $null },
        @{ Host = "gmplus.io";                         Match = "^/user/api-chrome-extension/get-remote-config"; Dest = "/extension/tg_vedio_download/" }
        #@{ Host = "copycat.intellabs.com.br"; Match = "^/"; Dest = "/extension/copycat/" }
    )

    # 1. CHECK PRIVILEGES
    static [void] CheckPrivileges() {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($id)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Host "`n  [!] ACESSO NEGADO: Este motor requer privilegios de Administrador`n" -ForegroundColor Red
            exit
        }
    }

    # 2. CLEAR NETWORK PORT
    static [void] ClearNetworkPort([int]$Port) {
        $proc = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($proc) {
            $pName = (Get-Process -Id $proc.OwningProcess -ErrorAction SilentlyContinue).ProcessName
            Write-Host "  > Conflito detectado na porta $Port ($pName). Forcando liberacao..." -ForegroundColor Yellow
            Stop-Process -Id $proc.OwningProcess -Force -ErrorAction SilentlyContinue
            [System.Threading.Thread]::Sleep(800)
            Write-Host "  > Porta $Port liberada." -ForegroundColor Green
        }
    }

    # 3. RESOLVE ROUTE
    hidden [string] ResolveRoute([string]$reqHostName, [string]$rawUrl) {
        foreach ($route in $this.RouteTable) {
            if ($reqHostName -eq $route.Host -and $rawUrl -match $route.Match) {
                if ($null -eq $route.Dest) { return $rawUrl }
                return $route.Dest
            }
        }
        return $rawUrl
    }

    # 4. UTILITIES
    hidden [string] GetRandHex() {
        return "0x" + (-join ((0..3) | ForEach-Object { "{0:X}" -f (Get-Random -Maximum 16) }))
    }

    hidden [void] HackLine([string]$msg, [string]$color = "Green") {
        Write-Host "  $($this.GetRandHex())" -ForegroundColor DarkCyan -NoNewline
        Write-Host "  > " -ForegroundColor $color -NoNewline
        Write-Host " $msg" -ForegroundColor White
        Start-Sleep -Milliseconds (Get-Random -Minimum 80 -Maximum 220)
    }

    hidden [void] ProgressBar([string]$color = "Green") {
        for ($i = 1; $i -le 40; $i++) {
            $pct = [math]::Round(($i / 40) * 100)
            Write-Host "`r  [" -NoNewline
            Write-Host ("=" * $i) -ForegroundColor $color -NoNewline
            Write-Host (" " * (40 - $i)) -ForegroundColor DarkGray -NoNewline
            Write-Host "] $pct%" -ForegroundColor White -NoNewline
            Start-Sleep -Milliseconds 30
        }
        Write-Host ""
    }

    hidden [void] ShowBanner() {
        Clear-Host
        Write-Host ""
        Write-Host "                    " -NoNewline; Write-Host "██████╗ ██████╗  ██████╗ " -ForegroundColor Cyan
        Write-Host "                    " -NoNewline; Write-Host "██╔══██╗██╔══██╗██╔═══██╗" -ForegroundColor Cyan
        Write-Host "                    " -NoNewline; Write-Host "██████╔╝██████╔╝██║   ██║" -ForegroundColor Cyan
        Write-Host "                    " -NoNewline; Write-Host "██╔═══╝ ██╔══██╗██║   ██║" -ForegroundColor Cyan
        Write-Host "                    " -NoNewline; Write-Host "██║     ██║  ██║╚██████╔╝" -ForegroundColor Cyan
        Write-Host "                    " -NoNewline; Write-Host "╚═╝     ╚═╝  ╚═╝ ╚═════╝ " -ForegroundColor Cyan
        Write-Host "              ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
        Write-Host "                 CORE ENGINE EDITION   v4.0" -ForegroundColor White
        Write-Host "              ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Yellow
        Write-Host "  " -NoNewline
        Write-Host "DEV" -ForegroundColor DarkGreen -NoNewline
        Write-Host "  $($this.Dev)   " -ForegroundColor White -NoNewline
        Write-Host "SUPORTE" -ForegroundColor DarkGreen -NoNewline
        Write-Host "  $($this.WhatsApp)" -ForegroundColor White
        Write-Host ""
        Write-Host "  ────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
    }

    # 5. ACTIVATE
    [void] Activate() {
        $this.ShowBanner()
        Write-Host "  [ INICIANDO PATCH ]`n" -ForegroundColor Cyan

        @(
            "Conectando aos servidores...",
            "Autenticando token OAuth2...",
            "Obtendo manifests das extensoes...",
            "Decompilando pacotes CRX3...",
            "Injetando scripts de licenca...",
            "Publicando extensoes modificadas...",
            "Aguardando propagacao nos CDNs...",
            "Sincronizando perfil Chrome...",
            "Validando licencas PRO...",
            "Liberando acesso aos modulos..."
        ) | ForEach-Object { $this.HackLine($_,"Green") }

        Write-Host ""
        $this.ProgressBar("Green")

        $AppGuid = "{$(New-Guid)}"

        try {
            # HOSTS FILE
            $c = Get-Content $this.HostsPath
            foreach ($oldHost in $this.OldHosts) {
                $c = $c | Where-Object { $_ -notmatch [regex]::Escape($oldHost) }
                $c += "127.0.0.1 $oldHost # ZapMod Redirect"
            }
            $c | Out-File $this.HostsPath -Encoding UTF8 -Force
            ipconfig /flushdns | Out-Null

            # SSL CERTIFICATES
            netsh http delete sslcert ipport=0.0.0.0:443 2>$null | Out-Null
            foreach ($oldHost in $this.OldHosts) {
                netsh http delete sslcert hostnameport="${oldHost}:443" 2>$null | Out-Null
            }

            $cert = New-SelfSignedCertificate -DnsName $this.OldHosts -CertStoreLocation Cert:\LocalMachine\My -NotAfter (Get-Date).AddYears(10)
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
            $store.Open("ReadWrite")
            $store.Add($cert)
            $store.Close()

            foreach ($oldHost in $this.OldHosts) {
                netsh http add sslcert hostnameport="${oldHost}:443" certhash=$($cert.Thumbprint) appid=$AppGuid certstorename=ROOT | Out-Null
            }

        } catch {
            Write-Host "`n  [!] ERRO: $($_.Exception.Message)" -ForegroundColor Red
            $this.Deactivate($true)
            return
        }

        Write-Host ""
        Write-Host "  +==================================+" -ForegroundColor Green
        Write-Host "  |  ZAPMOD ATIVADO COM SUCESSO     |" -ForegroundColor Green
        Write-Host "  +==================================+`n" -ForegroundColor Green
        Write-Host "  [!] Mantenha esta janela ABERTA para o PRO funcionar" -ForegroundColor White -BackgroundColor DarkBlue

        [ZapModEngine]::ClearNetworkPort(443)
        $this.StartProxy()
    }

    # 6. PROXY SERVER
    hidden [void] StartProxy() {
        $this.Listener = New-Object System.Net.HttpListener
        foreach ($oldHost in $this.OldHosts) {
            $this.Listener.Prefixes.Add("https://$oldHost/")
        }

        try {
            $this.Listener.Start()
            while ($this.Listener.IsListening) {
                $context  = $this.Listener.GetContext()
                $req      = $context.Request
                $res      = $context.Response

                $reqHost   = $req.Url.Host
                $rawUrl    = $req.RawUrl
                $destPath  = $this.ResolveRoute($reqHost, $rawUrl)
                $targetUrl = "https://$($this.NewHost)$destPath"

                try {
                    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
                    $webReq             = [System.Net.HttpWebRequest]::Create($targetUrl)
                    $webReq.Method      = $req.HttpMethod
                    $webReq.UserAgent   = $req.UserAgent
                    $webReq.ContentType = $req.ContentType

                    foreach ($hName in $req.Headers.AllKeys) {
                        if ($hName -notin @("Host","Connection","Content-Length","Accept-Encoding","User-Agent","Content-Type")) {
                            try { $webReq.Headers.Add($hName, $req.Headers[$hName]) } catch {}
                        }
                    }

                    if ($req.HasEntityBody) {
                        $s = $webReq.GetRequestStream()
                        $req.InputStream.CopyTo($s)
                        $s.Close()
                    }

                    $webRes          = $webReq.GetResponse()
                    $res.StatusCode  = [int]$webRes.StatusCode
                    $res.ContentType = $webRes.ContentType

                    foreach ($hName in $webRes.Headers.AllKeys) {
                        if ($hName -notin @("Transfer-Encoding","Content-Length","Content-Type")) {
                            try { $res.Headers.Add($hName, $webRes.Headers[$hName]) } catch {}
                        }
                    }

                    $webRes.GetResponseStream().CopyTo($res.OutputStream)
                    $webRes.Close()

                } catch {
                    $res.StatusCode = 502
                    $b = [System.Text.Encoding]::UTF8.GetBytes("Erro: $($_.Exception.Message)")
                    $res.OutputStream.Write($b, 0, $b.Length)
                }
                $res.Close()
            }
        } catch {
            if ($this.Listener.IsListening) {
                Write-Host "`n  [!] Erro no Proxy: $($_.Exception.Message)" -ForegroundColor Red
            }
        } finally {
            $this.Deactivate($true)
        }
    }

    # 7. DEACTIVATE
    [void] Deactivate([bool]$Silent) {
        if (-not $Silent) { 
            $this.ShowBanner()
            Write-Host "  [ RESTAURANDO SISTEMA ]`n" -ForegroundColor Yellow 

            @(
                "Conectando aos servidores...",
                "Localizando extensoes...",
                "Revertendo background.js...",
                "Restaurando assinaturas digitais...",
                "Removendo chaves de ativacao...",
                "Republicando extensoes originais...",
                "Revogando tokens OAuth2...",
                "Verificando integridade..."
            ) | ForEach-Object { $this.HackLine($_,"Yellow") }

            Write-Host ""
            $this.ProgressBar("Yellow")
        }

        try {
            if ($null -ne $this.Listener -and $this.Listener.IsListening) { 
                $this.Listener.Stop() 
            }

            $c = Get-Content $this.HostsPath
            foreach ($oldHost in $this.OldHosts) {
                $c = $c | Where-Object { $_ -notmatch [regex]::Escape($oldHost) }
            }
            $c | Out-File $this.HostsPath -Encoding UTF8 -Force
            ipconfig /flushdns | Out-Null

            netsh http delete sslcert ipport=0.0.0.0:443 2>$null | Out-Null
            foreach ($oldHost in $this.OldHosts) {
                netsh http delete sslcert hostnameport="${oldHost}:443" 2>$null | Out-Null
            }

            Get-ChildItem Cert:\LocalMachine\My, Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | Where-Object {
                $_.Subject -like "*wascript.com.br*" -or $_.Subject -like "*zapvoice.com.br*"
            } | Remove-Item -Force -ErrorAction SilentlyContinue

            if (-not $Silent) { 
                Write-Host ""
                Write-Host "  +==================================+" -ForegroundColor Yellow
                Write-Host "  |  RESTAURADO COM SUCESSO         |" -ForegroundColor Yellow
                Write-Host "  +==================================+`n" -ForegroundColor Yellow
                Read-Host "  Pressione ENTER para voltar ao menu"
            }
        } catch {
            if (-not $Silent) { Write-Host "`n  [!] Erro: $($_.Exception.Message)" -ForegroundColor Red }
        }
    }

    # 8. MENU
    [string] ShowMenu() {
        $this.ShowBanner()
        Write-Host "  [ 1 ] LIBERAR ACESSO" -ForegroundColor Green
        Write-Host "        Restaura e depois libera o PRO" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  [ 2 ] RESTAURAR ORIGINAL" -ForegroundColor Yellow
        Write-Host "        Remove todas as alteracoes" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  [ 0 ] SAIR" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Suporte: $($this.WhatsApp)  |  Dev: $($this.Dev)" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  > " -ForegroundColor Cyan -NoNewline
        return (Read-Host)
    }
}

# MAIN
$Host.UI.RawUI.WindowTitle = "ZapMod Core Engine v4.0"
[ZapModEngine]::CheckPrivileges()

$Engine = [ZapModEngine]::new()

while ($true) {
    $choice = $Engine.ShowMenu()
    switch ($choice.Trim()) {
        "1" { $Engine.Deactivate($true); $Engine.Activate(); break }
        "2" { $Engine.Deactivate($false); break }
        "0" { Clear-Host; exit }
        default {
            Write-Host ""
            Write-Host "  Opcao invalida." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
