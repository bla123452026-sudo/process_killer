# --- INITIALISATIE & MODERN UI SETUP ---
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch {
    Write-Host "Fout bij laden van Windows Forms."
    exit
}

# Locatie voor instellingen
$LogBestand = "$env:APPDATA\ProcessKiller_Settings.json"
$script:Running = $true

# Data structuur
$script:Data = @{
    Datum    = (Get-Date).ToString("yyyy-MM-dd")
    Limieten = @{}
    Verbruik = @{}
    Eenheid  = @{}
}

# --- FUNCTIES ---

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

# --- MODERNE UI ---

function Open-HoofdVenster {
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "Process Monitor Pro"; $Form.Size = "400,600"
    $Form.BackColor = [System.Drawing.Color]::FromArgb(255, 250, 250, 250)
    $Form.StartPosition = "CenterScreen"; $Form.FormBorderStyle = "FixedSingle"
    $Form.Icon = [System.Drawing.SystemIcons]::Shield

    # Header
    $Header = New-Object System.Windows.Forms.Panel
    $Header.Size = "400,80"; $Header.BackColor = [System.Drawing.Color]::FromArgb(255, 63, 81, 181)
    $Form.Controls.Add($Header)

    $Title = New-Object System.Windows.Forms.Label
    $Title.Text = "Monitor Dashboard"; $Title.ForeColor = "White"; $Title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $Title.Location = "20,20"; $Title.AutoSize = $true
    $Header.Controls.Add($Title)

    # Content Area (Scrollbaar)
    $Content = New-Object System.Windows.Forms.FlowLayoutPanel
    $Content.Location = "0,80"; $Content.Size = "400,380"; $Content.AutoScroll = $true
    $Content.Padding = New-Object System.Windows.Forms.Padding(10)
    $Form.Controls.Add($Content)

    function Refresh-Lijst {
        $Content.Controls.Clear()
        foreach ($App in $script:Data.Limieten.PSObject.Properties.Name) {
            $ItemBox = New-Object System.Windows.Forms.Panel
            $ItemBox.Size = "350,70"; $ItemBox.Margin = New-Object System.Windows.Forms.Padding(0,0,0,10)
            $ItemBox.BackColor = "White"; $ItemBox.BorderStyle = "None"
            
            $AppNameLabel = New-Object System.Windows.Forms.Label
            $AppNameLabel.Text = $App.ToUpper(); $AppNameLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            $AppNameLabel.Location = "10,5"; $AppNameLabel.AutoSize = $true
            
            $Usage = [int]$script:Data.Verbruik.$App
            $Lim = [int]$script:Data.Limieten.$App
            $MaxSec = if($script:Data.Eenheid.$App -eq "uur"){$Lim * 3600}else{$Lim * 60}
            
            $StatsLabel = New-Object System.Windows.Forms.Label
            $StatsLabel.Text = "$(Format-Tijd $Usage) / $(Format-Tijd $MaxSec)"
            $StatsLabel.Location = "10,25"; $StatsLabel.ForeColor = "Gray"; $StatsLabel.AutoSize = $true
            
            $PB = New-Object System.Windows.Forms.ProgressBar
            $PB.Location = "10,45"; $PB.Width = 280; $PB.Height = 10
            $perc = [Math]::Min(100, [Math]::Floor(($Usage / $MaxSec) * 100))
            $PB.Value = $perc
            
            $DelBtn = New-Object System.Windows.Forms.Button
            $DelBtn.Text = "X"; $DelBtn.Location = "310,10"; $DelBtn.Width = 30; $DelBtn.Height = 30
            $DelBtn.FlatStyle = "Flat"; $DelBtn.FlatAppearance.BorderSize = 0; $DelBtn.BackColor = "#FFE0E0"
            $DelBtn.add_Click({
                $script:Data.Limieten.PSObject.Properties.Remove($App)
                $script:Data.Verbruik.PSObject.Properties.Remove($App)
                Opslaan-Data; Refresh-Lijst
            })

            $ItemBox.Controls.AddRange(@($AppNameLabel, $StatsLabel, $PB, $DelBtn))
            $Content.Controls.Add($ItemBox)
        }
    }

    # Footer (Add Button)
    $Footer = New-Object System.Windows.Forms.Panel
    $Footer.Size = "400,100"; $Footer.Dock = "Bottom"
    $Form.Controls.Add($Footer)

    $AddBtn = New-Object System.Windows.Forms.Button
    $AddBtn.Text = "+ Limiet Toevoegen"; $AddBtn.Size = "340,45"; $AddBtn.Location = "20,10"
    $AddBtn.FlatStyle = "Flat"; $AddBtn.BackColor = "#3F51B5"; $AddBtn.ForeColor = "White"
    $AddBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $AddBtn.add_Click({
        Toevoegen-App-Popup
        Refresh-Lijst
    })
    $Footer.Controls.Add($AddBtn)

    Refresh-Lijst
    $Form.ShowDialog() | Out-Null
}

function Toevoegen-App-Popup {
    $Popup = New-Object System.Windows.Forms.Form
    $Popup.Text = "Nieuwe App"; $Popup.Size = "300,250"; $Popup.StartPosition = "CenterParent"
    
    $l1 = New-Object System.Windows.Forms.Label; $l1.Text = "Naam:"; $l1.Location = "20,20"; $Popup.Controls.Add($l1)
    $t1 = New-Object System.Windows.Forms.TextBox; $t1.Location = "20,40"; $t1.Width = 240; $Popup.Controls.Add($t1)
    
    $l2 = New-Object System.Windows.Forms.Label; $l2.Text = "Tijd:"; $l2.Location = "20,80"; $Popup.Controls.Add($l2)
    $t2 = New-Object System.Windows.Forms.TextBox; $t2.Location = "20,100"; $t2.Width = 80; $Popup.Controls.Add($t2)
    
    $c1 = New-Object System.Windows.Forms.ComboBox; $c1.Location = "110,100"; $c1.Width = 80
    $c1.Items.AddRange(@("min", "uur")); $c1.SelectedIndex = 0; $Popup.Controls.Add($c1)
    
    $b1 = New-Object System.Windows.Forms.Button; $b1.Text = "Opslaan"; $b1.Location = "20,150"; $b1.Width = 240; $b1.Height = 40
    $b1.BackColor = "#3F51B5"; $b1.ForeColor = "White"; $b1.FlatStyle = "Flat"
    $b1.add_Click({
        $name = $t1.Text.ToLower().Replace(".exe","").Trim()
        if ($name -and $t2.Text -match '^\d+$') {
            $script:Data.Limieten.$name = [int]$t2.Text
            $script:Data.Eenheid.$name = $c1.SelectedItem
            $script:Data.Verbruik.$name = 0
            Opslaan-Data; $Popup.Close()
        }
    })
    $Popup.Controls.Add($b1)
    $Popup.ShowDialog() | Out-Null
}

# --- SYSTEM TRAY ---
Laad-Data
$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$NotifyIcon.Icon = [System.Drawing.SystemIcons]::Shield
$NotifyIcon.Visible = $true
$NotifyIcon.Text = "Process Monitor Actief"

$Menu = New-Object System.Windows.Forms.ContextMenu
$Menu.MenuItems.Add("Dashboard Openen", { Open-HoofdVenster }) | Out-Null
$Menu.MenuItems.Add("-") | Out-Null
$Menu.MenuItems.Add("Stop Monitor", { $NotifyIcon.Visible = $false; Stop-Process -Id $PID }) | Out-Null
$NotifyIcon.ContextMenu = $Menu

# --- MAIN LOOP ---
# Als het script gestart is met het argument "-ShowUI", open dan direct het venster
if ($args -contains "-ShowUI") {
    $null = [threading.Thread]::new({ Open-HoofdVenster }).Start()
}

while($true) {
    # Dagelijkse reset check
    if ((Get-Date).ToString("yyyy-MM-dd") -ne $script:Data.Datum) {
        $script:Data.Datum = (Get-Date).ToString("yyyy-MM-dd"); $script:Data.Verbruik = @{}
    }
    
    $Procs = Get-Process -ErrorAction SilentlyContinue
    foreach ($App in $script:Data.Limieten.PSObject.Properties.Name) {
        $P = $Procs | Where-Object { $_.ProcessName -eq $App }
        if ($P) {
            $L = [int]$script:Data.Limieten.$App
            $MaxSec = if($script:Data.Eenheid.$App -eq "uur"){$L * 3600}else{$L * 60}
            
            if ($null -eq $script:Data.Verbruik.$App) { $script:Data.Verbruik.$name = 0 }
            $script:Data.Verbruik.$App = [double]$script:Data.Verbruik.$App + 5
            
            if ($script:Data.Verbruik.$App -ge $MaxSec) {
                $P | Stop-Process -Force -ErrorAction SilentlyContinue
                $NotifyIcon.ShowBalloonTip(3000, "Limiet Bereikt", "App $App is gesloten.", "Warning")
            }
        }
    }
    Opslaan-Data
    Start-Sleep -Seconds 5
}