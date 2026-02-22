# --- INITIALISATIE ---
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch { exit }

$LogBestand = "$env:APPDATA\AppMonitor_Settings.json"
$script:Data = [PSCustomObject]@{
    Datum    = (Get-Date).ToString("yyyy-MM-dd")
    Limieten = [PSCustomObject]@{}
    Verbruik = [PSCustomObject]@{}
    Eenheid  = [PSCustomObject]@{}
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
        } catch {
            # Bij corrupte file, start met schone lei
        }
    }
}

function Opslaan-Data {
    $script:Data | ConvertTo-Json -Depth 5 | Out-File $LogBestand -Force
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
    $Form.Text = "App Monitor Dashboard"
    $Form.Size = "450,650"
    $Form.StartPosition = "CenterScreen"
    $Form.BackColor = [System.Drawing.Color]::White
    $Form.FormBorderStyle = "FixedSingle"
    $Form.MaximizeBox = $false

    # Header
    $Header = New-Object System.Windows.Forms.Panel
    $Header.Size = "450,70"; $Header.BackColor = [System.Drawing.Color]::FromArgb(255, 45, 52, 71)
    $Form.Controls.Add($Header)

    $Title = New-Object System.Windows.Forms.Label
    $Title.Text = "Mijn App Limieten"; $Title.ForeColor = "White"; $Title.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $Title.Location = "20,20"; $Title.AutoSize = $true
    $Header.Controls.Add($Title)

    # Invoer Sectie
    $InputGroup = New-Object System.Windows.Forms.GroupBox
    $InputGroup.Text = "Nieuwe App Toevoegen"; $InputGroup.Location = "20,85"; $InputGroup.Size = "390,130"
    $Form.Controls.Add($InputGroup)

    $lblN = New-Object System.Windows.Forms.Label; $lblN.Text = "Naam (bijv. chrome):"; $lblN.Location = "15,25"; $lblN.AutoSize = $true; $InputGroup.Controls.Add($lblN)
    $txtName = New-Object System.Windows.Forms.TextBox; $txtName.Location = "15,45"; $txtName.Width = 200; $InputGroup.Controls.Add($txtName)

    $lblT = New-Object System.Windows.Forms.Label; $lblT.Text = "Tijd:"; $lblT.Location = "230,25"; $lblT.AutoSize = $true; $InputGroup.Controls.Add($lblT)
    $txtTime = New-Object System.Windows.Forms.TextBox; $txtTime.Location = "230,45"; $txtTime.Width = 60; $InputGroup.Controls.Add($txtTime)

    $cmbUnit = New-Object System.Windows.Forms.ComboBox; $cmbUnit.Location = "300,45"; $cmbUnit.Width = 70
    $cmbUnit.Items.AddRange(@("min", "uur")); $cmbUnit.SelectedIndex = 0; $cmbUnit.DropDownStyle = "DropDownList"
    $InputGroup.Controls.Add($cmbUnit)

    $btnAdd = New-Object System.Windows.Forms.Button; $btnAdd.Text = "Toevoegen"; $btnAdd.Location = "15,85"; $btnAdd.Width = 355; $btnAdd.Height = 30
    $btnAdd.BackColor = [System.Drawing.Color]::FromArgb(255, 0, 120, 215); $btnAdd.ForeColor = "White"; $btnAdd.FlatStyle = "Flat"
    $InputGroup.Controls.Add($btnAdd)

    # Lijst Sectie
    $Container = New-Object System.Windows.Forms.FlowLayoutPanel
    $Container.Location = "20,230"; $Container.Size = "400,360"; $Container.AutoScroll = $true
    $Form.Controls.Add($Container)

    $Refresh = {
        $Container.Controls.Clear()
        foreach ($Prop in $script:Data.Limieten.PSObject.Properties) {
            $App = $Prop.Name
            $LimValue = $Prop.Value
            
            # Voorkom data types errors
            [int]$Usage = if ($script:Data.Verbruik.$App -is [int]) { $script:Data.Verbruik.$App } else { 0 }
            [int]$Lim = if ($LimValue -is [int]) { $LimValue } else { [int]$LimValue }
            
            # Bereken MaxSec en voorkom deling door nul
            $MaxSec = if($script:Data.Eenheid.$App -eq "uur") { $Lim * 3600 } else { $Lim * 60 }
            if ($MaxSec -le 0) { $MaxSec = 60 } # Fallback naar 1 minuut bij foutieve invoer

            $Perc = [Math]::Min(100, [Math]::Floor(($Usage / $MaxSec) * 100))

            $P = New-Object System.Windows.Forms.Panel; $P.Size = "370,65"; $P.BorderStyle = "FixedSingle"; $P.Margin = "0,0,0,10"
            $P.BackColor = [System.Drawing.Color]::WhiteSmoke
            
            $L = New-Object System.Windows.Forms.Label; $L.Text = "$($App.ToUpper())"; $L.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold); $L.Location = "10,5"; $L.AutoSize = $true
            $T = New-Object System.Windows.Forms.Label; $T.Text = "$(Format-Tijd $Usage) / $(Format-Tijd $MaxSec)"; $T.Location = "10,22"; $T.AutoSize = $true
            
            $PB = New-Object System.Windows.Forms.ProgressBar; $PB.Location = "10,40"; $PB.Width = 280; $PB.Height = 12; $PB.Value = $Perc
            
            $Del = New-Object System.Windows.Forms.Button; $Del.Text = "X"; $Del.Location = "330,5"; $Del.Width = 30; $Del.Height = 30; $Del.BackColor = "WhiteSmoke"
            $Del.add_Click({
                $script:Data.Limieten.PSObject.Properties.Remove($App)
                $script:Data.Verbruik.PSObject.Properties.Remove($App)
                $script:Data.Eenheid.PSObject.Properties.Remove($App)
                Opslaan-Data; &$Refresh
            })

            $P.Controls.AddRange(@($L, $T, $PB, $Del))
            $Container.Controls.Add($P)
        }
    }

    $btnAdd.add_Click({
        $n = $txtName.Text.ToLower().Trim()
        if ($n -and $txtTime.Text -match '^\d+') {
            $val = [int]$txtTime.Text
            if ($val -gt 0) {
                Add-Member -InputObject $script:Data.Limieten -NotePropertyName $n -NotePropertyValue $val -Force
                Add-Member -InputObject $script:Data.Eenheid -NotePropertyName $n -NotePropertyValue $cmbUnit.SelectedItem -Force
                Add-Member -InputObject $script:Data.Verbruik -NotePropertyName $n -NotePropertyValue 0 -Force
                $txtName.Text = ""; $txtTime.Text = ""
                Opslaan-Data; &$Refresh
            }
        }
    })

    &$Refresh
    $Form.ShowDialog() | Out-Null
}

# --- STARTUP ---
Laad-Data
$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$NotifyIcon.Icon = [System.Drawing.SystemIcons]::Shield
$NotifyIcon.Visible = $true
$NotifyIcon.ContextMenu = New-Object System.Windows.Forms.ContextMenu
$NotifyIcon.ContextMenu.MenuItems.Add("Dashboard Openen", { Open-HoofdVenster }) | Out-Null
$NotifyIcon.ContextMenu.MenuItems.Add("Monitor Stoppen", { $NotifyIcon.Visible = $false; Stop-Process -Id $PID }) | Out-Null

# Start met dashboard
Open-HoofdVenster

# --- MONITOR LOOP ---
while($true) {
    $Procs = Get-Process -ErrorAction SilentlyContinue
    foreach ($Prop in $script:Data.Limieten.PSObject.Properties) {
        $App = $Prop.Name
        if ($Procs | Where-Object { $_.ProcessName -eq $App }) {
            [int]$curUsage = if ($null -ne $script:Data.Verbruik.$App) { $script:Data.Verbruik.$App } else { 0 }
            $newUsage = $curUsage + 5
            Add-Member -InputObject $script:Data.Verbruik -NotePropertyName $App -NotePropertyValue $newUsage -Force
            
            [int]$Lim = $Prop.Value
            $MaxSec = if($script:Data.Eenheid.$App -eq "uur") { $Lim * 3600 } else { $Lim * 60 }
            
            if ($newUsage -ge $MaxSec) {
                $Procs | Where-Object { $_.ProcessName -eq $App } | Stop-Process -Force
                $NotifyIcon.ShowBalloonTip(5000, "Tijd is op!", "$App is gesloten.", "Warning")
            }
        }
    }
    if ((Get-Date).ToString("yyyy-MM-dd") -ne $script:Data.Datum) {
        $script:Data.Datum = (Get-Date).ToString("yyyy-MM-dd")
        $script:Data.Verbruik = [PSCustomObject]@{}
    }
    Opslaan-Data; Start-Sleep -Seconds 5
}