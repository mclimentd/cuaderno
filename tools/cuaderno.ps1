param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("export", "status", "deploy")]
    [string]$Command,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string]$PageName
)

$ErrorActionPreference = "Stop"

# ============================================================
# CONFIGURACION
# ============================================================

$Server        = "root@192.168.1.10"
$WordPressPath = "/var/webs/wordpress/cuaderno"
$BackupPath    = "/var/backups/cuaderno-pages"

# El script esta en /tools, por lo que la raiz del proyecto
# es la carpeta padre.
$ProjectRoot = Split-Path -Parent $PSScriptRoot

$PageDir    = Join-Path $ProjectRoot "pages\$PageName"
$JsonFile   = Join-Path $PageDir "page.json"
$ContentFile = Join-Path $PageDir "content.html"


# ============================================================
# FUNCIONES AUXILIARES
# ============================================================

function Write-Info {
    param([string]$Message)
    Write-Host "[CUADERNO] $Message"
}

function Stop-Cuaderno {
    param([string]$Message)

    Write-Host ""
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

function Invoke-SSH {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RemoteCommand
    )

    $output = & ssh $Server $RemoteCommand

    if ($LASTEXITCODE -ne 0) {
        Stop-Cuaderno "Ha fallado un comando SSH en el servidor."
    }

    return $output
}

function Test-RequiredCommand {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Stop-Cuaderno "No se encuentra el comando '$Name' en Windows."
    }
}


# ============================================================
# COMPROBACIONES LOCALES
# ============================================================

Test-RequiredCommand "ssh"
Test-RequiredCommand "scp"

if (-not (Test-Path $PageDir)) {
    Stop-Cuaderno "No existe la carpeta: $PageDir"
}

if (-not (Test-Path $JsonFile)) {
    Stop-Cuaderno "No existe el archivo: $JsonFile"
}

try {
    $PageInfo = Get-Content $JsonFile -Raw -Encoding UTF8 | ConvertFrom-Json
}
catch {
    Stop-Cuaderno "No se puede leer page.json: $($_.Exception.Message)"
}

if (-not $PageInfo.ID) {
    Stop-Cuaderno "page.json no contiene ID."
}

if (-not $PageInfo.post_name) {
    Stop-Cuaderno "page.json no contiene post_name."
}

if (-not $PageInfo.post_type) {
    Stop-Cuaderno "page.json no contiene post_type."
}

$PostId   = [int]$PageInfo.ID
$PostSlug = [string]$PageInfo.post_name
$PostType = [string]$PageInfo.post_type

if ($PostType -ne "page") {
    Stop-Cuaderno "El post $PostId no esta definido como post_type=page."
}

if ($PostSlug -ne $PageName) {
    Stop-Cuaderno "El nombre solicitado '$PageName' no coincide con post_name '$PostSlug'."
}


# ============================================================
# VALIDACION DEL POST REMOTO
# ============================================================

function Get-RemotePostInfo {

    Write-Info "Comprobando pagina WordPress ID $PostId..."

    $remoteJson = Invoke-SSH "wp post get $PostId --path='$WordPressPath' --fields=ID,post_name,post_type,post_status --format=json --allow-root"

    try {
        $remote = ($remoteJson -join "`n") | ConvertFrom-Json
    }
    catch {
        Stop-Cuaderno "No se ha podido interpretar la informacion del post remoto."
    }

    if ([int]$remote.ID -ne $PostId) {
        Stop-Cuaderno "El ID remoto no coincide con page.json."
    }

    if ([string]$remote.post_name -ne $PostSlug) {
        Stop-Cuaderno "El slug remoto '$($remote.post_name)' no coincide con '$PostSlug'."
    }

    if ([string]$remote.post_type -ne "page") {
        Stop-Cuaderno "El post remoto no es de tipo page."
    }

    return $remote
}


# ============================================================
# EXPORT
# ============================================================

function Export-CuadernoPage {

    $remote = Get-RemotePostInfo

    Write-Info "Exportando '$PostSlug' desde WordPress..."

    $RemoteTemp = "/tmp/cuaderno-export-$PostId-$PID.html"

    try {
        Invoke-SSH "wp post get $PostId --path='$WordPressPath' --field=post_content --allow-root > '$RemoteTemp'" | Out-Null

        & scp "${Server}:$RemoteTemp" "$ContentFile"

        if ($LASTEXITCODE -ne 0) {
            Stop-Cuaderno "No se ha podido copiar el contenido desde el servidor."
        }

        if (-not (Test-Path $ContentFile)) {
            Stop-Cuaderno "No se ha creado content.html."
        }

# Normalizar contenido
$text = [System.IO.File]::ReadAllText($ContentFile)
$text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
$text = $text.Trim("`r", "`n")

[System.IO.File]::WriteAllText(
    $ContentFile,
    $text + "`n",
    [System.Text.UTF8Encoding]::new($false)
)

        Write-Host ""
        Write-Host "EXPORTACION CORRECTA" -ForegroundColor Green
        Write-Host "Pagina : $PostSlug"
        Write-Host "ID     : $PostId"
        Write-Host "Estado : $($remote.post_status)"
        Write-Host "Archivo: $ContentFile"
    }
    finally {
        Invoke-SSH "rm -f '$RemoteTemp'" | Out-Null
    }
}


# ============================================================
# STATUS
# ============================================================

function Get-NormalizedHash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$File
    )

    # Leer texto completo
    $text = [System.IO.File]::ReadAllText($File)

    # Normalizar finales de línea Windows/Linux
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")

    # Ignorar saltos de línea exclusivamente al final del documento
    $text = $text.Trim("`r", "`n")

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)

    $sha = [System.Security.Cryptography.SHA256]::Create()

    try {
        $hashBytes = $sha.ComputeHash($bytes)

        return (
            [System.BitConverter]::ToString($hashBytes)
        ).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}


function Show-CuadernoStatus {

    $remote = Get-RemotePostInfo

    if (-not (Test-Path $ContentFile)) {
        Stop-Cuaderno "No existe content.html para comparar."
    }

    $RemoteTemp = "/tmp/cuaderno-status-$PostId-$PID.html"
    $LocalTemp = Join-Path $env:TEMP "cuaderno-status-$PostId-$PID.html"

    try {

        Write-Info "Obteniendo contenido actual de WordPress..."

        Invoke-SSH "wp post get $PostId --path='$WordPressPath' --field=post_content --allow-root > '$RemoteTemp'" | Out-Null

        & scp "${Server}:$RemoteTemp" "$LocalTemp"

        if ($LASTEXITCODE -ne 0) {
            Stop-Cuaderno "No se ha podido descargar el contenido remoto."
        }

        Write-Info "Calculando contenido normalizado..."

        $LocalHash  = Get-NormalizedHash $ContentFile
        $RemoteHash = Get-NormalizedHash $LocalTemp

        Write-Host ""
        Write-Host "Pagina : $PostSlug"
        Write-Host "ID     : $PostId"
        Write-Host "Estado : $($remote.post_status)"
        Write-Host ""
        Write-Host "Local  : $LocalHash"
        Write-Host "Remoto : $RemoteHash"
        Write-Host ""

        if ($LocalHash -eq $RemoteHash) {
            Write-Host "IGUAL" -ForegroundColor Green
        }
        else {
            Write-Host "DIFERENTE" -ForegroundColor Yellow
        }
    }
    finally {

        Invoke-SSH "rm -f '$RemoteTemp'" | Out-Null

        if (Test-Path $LocalTemp) {
            Remove-Item $LocalTemp -Force
        }
    }
}


# ============================================================
# DEPLOY
# ============================================================

function Deploy-CuadernoPage {

    $remoteBefore = Get-RemotePostInfo

    if (-not (Test-Path $ContentFile)) {
        Stop-Cuaderno "No existe content.html para desplegar."
    }

    Write-Host ""
    Write-Host "ATENCION" -ForegroundColor Yellow
    Write-Host "Se va a actualizar exclusivamente post_content."
    Write-Host "Pagina : $PostSlug"
    Write-Host "ID     : $PostId"
    Write-Host "Estado : $($remoteBefore.post_status)"
    Write-Host ""

    $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

    $RemoteBackup = "$BackupPath/$PostId-$PostSlug-$Timestamp.html"
    $RemoteTemp   = "/tmp/cuaderno-deploy-$PostId-$PID.html"

    Write-Info "Creando directorio de backups..."

    Invoke-SSH "mkdir -p '$BackupPath'" | Out-Null

    Write-Info "Creando backup del post_content actual..."

    Invoke-SSH "wp post get $PostId --path='$WordPressPath' --field=post_content --allow-root > '$RemoteBackup'" | Out-Null

    $backupCheck = Invoke-SSH "test -s '$RemoteBackup' && echo OK"

    if (($backupCheck -join "").Trim() -ne "OK") {
        Stop-Cuaderno "No se ha podido crear correctamente el backup."
    }

    Write-Info "Backup creado:"
    Write-Host $RemoteBackup

    try {

        Write-Info "Copiando content.html al servidor..."

        & scp "$ContentFile" "${Server}:$RemoteTemp"

        if ($LASTEXITCODE -ne 0) {
            Stop-Cuaderno "Ha fallado la copia del archivo al servidor."
        }

        $tempCheck = Invoke-SSH "test -s '$RemoteTemp' && echo OK"

        if (($tempCheck -join "").Trim() -ne "OK") {
            Stop-Cuaderno "El archivo temporal remoto no existe o esta vacio."
        }

        Write-Info "Actualizando exclusivamente post_content..."

        $updateOutput = Invoke-SSH "wp post update $PostId --path='$WordPressPath' --post_content=`"`$(cat '$RemoteTemp')`" --allow-root"

        Write-Host ($updateOutput -join "`n")

        Write-Info "Verificando pagina despues del despliegue..."

        $remoteAfter = Get-RemotePostInfo

        if ([int]$remoteAfter.ID -ne $PostId) {
            Stop-Cuaderno "La verificacion posterior ha fallado: ID incorrecto."
        }

        if ([string]$remoteAfter.post_name -ne $PostSlug) {
            Stop-Cuaderno "La verificacion posterior ha fallado: slug incorrecto."
        }

        if ([string]$remoteAfter.post_type -ne "page") {
            Stop-Cuaderno "La verificacion posterior ha fallado: post_type incorrecto."
        }

        if ([string]$remoteAfter.post_status -ne [string]$remoteBefore.post_status) {
            Stop-Cuaderno "El estado del post ha cambiado durante el despliegue."
        }

        Write-Host ""
        Write-Host "DESPLIEGUE CORRECTO" -ForegroundColor Green
        Write-Host "Pagina : $PostSlug"
        Write-Host "ID     : $PostId"
        Write-Host "Estado : $($remoteAfter.post_status)"
        Write-Host "Backup : $RemoteBackup"
    }
    finally {

        Write-Info "Eliminando archivo temporal remoto..."

        Invoke-SSH "rm -f '$RemoteTemp'" | Out-Null
    }
}


# ============================================================
# EJECUCION
# ============================================================

Write-Host ""
Write-Host "============================================"
Write-Host " CUADERNO - Gestor de paginas WordPress"
Write-Host "============================================"
Write-Host ""

switch ($Command) {

    "export" {
        Export-CuadernoPage
    }

    "status" {
        Show-CuadernoStatus
    }

    "deploy" {
        Deploy-CuadernoPage
    }

    default {
        Stop-Cuaderno "Comando no reconocido."
    }
}