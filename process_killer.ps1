# --- INITIALISATIE ---
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch { exit }

$LogBestand = "$env:APPDATA\ProcessKiller_Settings.json"
$script:Data = @{
    Datum    = (Get-Date).ToString("yyyy-MM-dd")
    Limieten = @{}
    Verbruik = @{}
    Eenheid  = @{}
}

# --- DATA FUNCTIES ---
function Laad-Data {
    if (Test-Path $LogBestand) {
        try {
            $Geladen = Get-Content $LogBestand -Raw | ConvertFrom-Json
            if ($null -ne $Geladen.Limieten) { $script:Data.Limieten = $Geladen.Limieten }
            if ($null -ne $Geladen.Eenheid) { $script:Data.Eenheid = $Geladen.Eenheid }
            if ($Geladen.Datum -eq (Get-Date).ToString("yyyy-MM-dd")) {
                if ($null -ne $Geladen.Verbruik) { $script:Data.Verbruik = $Geladen.Verbruik }
            }
        } catch {}
    }
}

function Opslaan-Data {
    $script:Data | ConvertTo-Json | Out-File $LogBestand -Force
}

function Format-Tijd {
    param([int]$TotaalSec)
    $m = [Math]::Floor($TotaalSec / 60)
    $s = $TotaalSec % 60
    return "{0}m {1}s" -f $m, $s
}

# --- DASHBOARD UI ---
function Open-HoofdVenster {
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "App Monitor Dashboard"; $Form.Size = "400,500"; $Form.StartPosition = "CenterScreen"; $Form.Topmost = $true

    $Content = New-Object System.Windows.Forms.FlowLayoutPanel
    $Content.Dock = "Fill"; $Content.AutoScroll = $true; $Form.Controls.Add($Content)

    function Refresh-Lijst {
        $Content.Controls.Clear()
        foreach ($App in $script:Data.Limieten.PSObject.Properties.Name) {
            $Usage = if ($null -ne $script:Data.Verbruik.$App) { [int]$script:Data.Verbruik.$App } else { 0 }
            $Lim = [int]$script:Data.Limieten.$App
            $MaxSec = if($script:Data.Eenheid.$App -eq "uur"){$Lim * 3600}else{$Lim * 60}
            
            $Pnl = New-Object System.Windows.Forms.Panel; $Pnl.Size = "350,50"
            $Lbl = New-Object System.Windows.Forms.Label; $Lbl.Text = "$App: $(Format-Tijd $Usage) / $(Format-Tijd $MaxSec)"; $Lbl.AutoSize = $true
            $PB = New-Object System.Windows.Forms.ProgressBar; $PB.Location = "0,20"; $PB.Width = 300; $PB.Value = [Math]::Min(100, [Math]::Floor(($Usage / $MaxSec) * 100))
            
            $Pnl.Controls.AddRange(@($Lbl, $PB))
            $Content.Controls.Add($Pnl)
        }
    }

    $Btn = New-Object System.Windows.Forms.Button; $Btn.Text = "App Toevoegen"; $Btn.Dock = "Bottom"; $Btn.Height = 40
    $Btn.add_Click({ Toevoegen-Popup; Refresh-Lijst })
    $Form.Controls.Add($Btn)

    Refresh-Lijst
    $Form.ShowDialog() | Out-Null
}

function Toevoegen-Popup {
    $P = New-Object System.Windows.Forms.Form; $P.Size = "250,150"; $P.Text = "Nieuwe App"
    $t1 = New-Object System.Windows.Forms.TextBox; $t1.Location = "10,10"; $P.Controls.Add($t1)
    $t2 = New-Object System.Windows.Forms.TextBox; $t2.Location = "10,40"; $P.Controls.Add($t2)
    $b = New-Object System.Windows.Forms.Button; $b.Text = "OK"; $b.Location = "10,70"; $P.Controls.Add($b)
    $b.add_Click({
        $n = $t1.Text.ToLower().Trim()
        if ($n -and $t2.Text -match '^\d+') {
            $script:Data.Limieten.$n = [int]$t2.Text
            $script:Data.Eenheid.$n = "min"; $script:Data.Verbruik.$n = 0
            Opslaan-Data; $P.Close()
        }
    })
    $P.ShowDialog() | Out-Null
}

# --- STARTUP ---
Laad-Data
$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$NotifyIcon.Icon = [System.Drawing.SystemIcons]::Shield
$NotifyIcon.Visible = $true
$NotifyIcon.ContextMenu = New-Object System.Windows.Forms.ContextMenu
$NotifyIcon.ContextMenu.MenuItems.Add("Open Dashboard", { Open-HoofdVenster }) | Out-Null
$NotifyIcon.ContextMenu.MenuItems.Add("Stop", { $NotifyIcon.Visible = $false; Stop-Process -Id $PID }) | Out-Null

$NotifyIcon.ShowBalloonTip(3000, "Monitor Actief", "Het systeem wordt bewaakt.", "Info")

if ($args -contains "-ShowUI") { Open-HoofdVenster }

# --- LOOP ---
while($true) {
    $Procs = Get-Process -ErrorAction SilentlyContinue
    foreach ($App in $script:Data.Limieten.PSObject.Properties.Name) {
        if ($Procs | Where-Object { $_.ProcessName -eq $App }) {
            $script:Data.Verbruik.$App = [int]$script:Data.Verbruik.$App + 5
            if ($script:Data.Verbruik.$App -ge ([int]$script:Data.Limieten.$App * 60)) {
                $Procs | Where-Object { $_.ProcessName -eq $App } | Stop-Process -Force
                $NotifyIcon.ShowBalloonTip(5000, "Limiet!", "$App gesloten.", "Warning")
            }
        }
    }
    Opslaan-Data; Start-Sleep -Seconds 5
}