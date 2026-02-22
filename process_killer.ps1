# --- CONFIGURATIE & SETUP ---
# Laden van Windows Forms voor de interface
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$LogBestand = "$env:APPDATA\monitor_settings.json"
$script:PathCache = @{} # Slaat de locatie van .exe bestanden op voor herstarten

# De basisgegevens van de monitor
$script:Data = @{
    Datum    = (Get-Date).ToString("yyyy-MM-dd")
    Limieten = @{}
    Verbruik = @{}
    Eenheid  = @{}
}

# --- FUNCTIES VOOR DATA ---

function Laad-Data {
    if (Test-Path $LogBestand) {
        try {
            $Geladen = Get-Content $LogBestand -Raw | ConvertFrom-Json
            if ($Geladen.Limieten) { $script:Data.Limieten = $Geladen.Limieten }
            if ($Geladen.Eenheid) { $script:Data.Eenheid = $Geladen.Eenheid }
            if ($Geladen.Datum -eq (Get-Date).ToString("yyyy-MM-dd")) {
                if ($Geladen.Verbruik) { $script:Data.Verbruik = $Geladen.Verbruik }
            } else {
                # Nieuwe dag? Reset verbruik
                $script:Data.Verbruik = @{}
                $script:Data.Datum = (Get-Date).ToString("yyyy-MM-dd")
            }
        } catch {}
    }
}

function Opslaan-Data {
    $script:Data | ConvertTo-Json | Out-File $LogBestand -Force
}

# --- INTERFACE FUNCTIES ---

function Toevoegen-App {
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "App Toevoegen"; $Form.Size = "300,250"; $Form.Topmost = $true; $Form.StartPosition = "CenterScreen"
    
    $lbl = New-Object System.Windows.Forms.Label; $lbl.Text = "Naam (zonder .exe):"; $lbl.Location = "10,10"; $lbl.AutoSize = $true; $Form.Controls.Add($lbl)
    $txt = New-Object System.Windows.Forms.TextBox; $txt.Location = "10,35"; $txt.Width = 250; $Form.Controls.Add($txt)
    
    $lbl2 = New-Object System.Windows.Forms.Label; $lbl2.Text = "Tijd:"; $lbl2.Location = "10,75"; $lbl2.AutoSize = $true; $Form.Controls.Add($lbl2)
    $time = New-Object System.Windows.Forms.TextBox; $time.Location = "10,100"; $time.Width = 80; $Form.Controls.Add($time)
    
    $unit = New-Object System.Windows.Forms.ComboBox; $unit.Location = "100,100"; $unit.Width = 80
    $unit.Items.AddRange(@("min", "uur")); $unit.SelectedIndex = 0; $unit.DropDownStyle = "DropDownList"; $Form.Controls.Add($unit)
    
    $btn = New-Object System.Windows.Forms.Button; $btn.Text = "Limiet Opslaan"; $btn.Location = "10,150"; $btn.Width = 250; $btn.Height = 40; $btn.BackColor = "LightBlue"
    $btn.add_Click({
        $n = $txt.Text.ToLower().Replace(".exe","").Trim()
        if ($n -and $time.Text -match '^\d+$') {
            $script:Data.Limieten.$n = [int]$time.Text
            $script:Data.Eenheid.$n = $unit.SelectedItem
            $script:Data.Verbruik.$n = 0
            Opslaan-Data; $Form.Close()
            $NotifyIcon.ShowBalloonTip(2000, "Succes", "$n is toegevoegd aan de monitor.", "Info")
        }
    })
    $Form.Controls.Add($btn); $Form.ShowDialog() | Out-Null
}

function Toon-Herstart-Venster {
    $HForm = New-Object System.Windows.Forms.Form
    $HForm.Text = "Herstarten & Resetten"; $HForm.Size = "320,350"; $HForm.StartPosition = "CenterScreen"; $HForm.Topmost = $true
    
    $Flow = New-Object System.Windows.Forms.FlowLayoutPanel; $Flow.Dock = "Fill"; $Flow.Padding = "10"; $HForm.Controls.Add($Flow)

    $RefreshList = {
        $Flow.Controls.Clear()
        foreach ($App in $script:Data.Limieten.PSObject.Properties.Name) {
            $Max = if ($script:Data.Eenheid.$App -eq "uur") { $script:Data.Limieten.$App * 3600 } else { $script:Data.Limieten.$App * 60 }
            if ($script:Data.Verbruik.$App -ge $Max) {
                $Btn = New-Object System.Windows.Forms.Button; $Btn.Text = "Herstart $App"; $Btn.Width = 260; $Btn.Height = 35; $Btn.Margin = "0,0,0,5"
                $Btn.add_Click({
                    $script:Data.Verbruik.$App = 0
                    Opslaan-Data
                    $Pad = $script:PathCache[$App]
                    if ($Pad -and (Test-Path $Pad)) { Start-Process -FilePath $Pad }
                    &$RefreshList
                })
                $Flow.Controls.Add($Btn)
            }
        }
        if ($Flow.Controls.Count -eq 0) { $HForm.Close() }
    }
    &$RefreshList; $HForm.ShowDialog() | Out-Null
}

# --- TRAY PICTOGRAM SETUP ---

Laad-Data
$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$NotifyIcon.Icon = [System.Drawing.SystemIcons]::Shield
$NotifyIcon.Visible = $true
$NotifyIcon.Text = "App Monitor is actief"

$Menu = New-Object System.Windows.Forms.ContextMenu
$Menu.MenuItems.Add("App Toevoegen", { Toevoegen-App }) | Out-Null
$Menu.MenuItems.Add("Apps Herstarten / Resetten", { Toon-Herstart-Venster }) | Out-Null
$Menu.MenuItems.Add("-") | Out-Null
$Menu.MenuItems.Add("Afsluiten", { $NotifyIcon.Visible = $false; Stop-Process -Id $PID }) | Out-Null
$NotifyIcon.ContextMenu = $Menu

# --- DE MONITOR LUS (DE MOTOR) ---

while($true) {
    # Controleer of de dag is gewisseld voor automatische reset
    if ((Get-Date).ToString("yyyy-MM-dd") -ne $script:Data.Datum) {
        $script:Data.Datum = (Get-Date).ToString("yyyy-MM-dd")
        $script:Data.Verbruik = @{}
        Opslaan-Data
    }
    
    $AlleProcessen = Get-Process -ErrorAction SilentlyContinue
    
    foreach ($App in $script:Data.Limieten.PSObject.Properties.Name) {
        $Gevonden = $AlleProcessen | Where-Object { $_.ProcessName -eq $App }
        
        if ($Gevonden) {
            # Onthoud het pad voor de herstart-knop
            if (-not $script:PathCache[$App]) {
                try { $script:PathCache[$App] = $Gevonden[0].MainModule.FileName } catch {}
            }

            # Bereken limiet
            $Limiet = [int]$script:Data.Limieten.$App
            $MaxInSeconden = if ($script:Data.Eenheid.$App -eq "uur") { $Limiet * 3600 } else { $Limiet * 60 }
            
            # Verhoog verbruik (we slapen 5 seconden per keer)
            $Huidig = if ($script:Data.Verbruik.$App) { [int]$script:Data.Verbruik.$App } else { 0 }
            $script:Data.Verbruik.$App = $Huidig + 5
            
            # Controleer of de tijd op is
            if ($script:Data.Verbruik.$App -ge $MaxInSeconden) {
                # DIT SLUIT DE APP ECHT AF
                $Gevonden | Stop-Process -Force -ErrorAction SilentlyContinue
                $NotifyIcon.ShowBalloonTip(4000, "Tijd is op!", "De app '$App' is gesloten door de monitor.", "Warning")
            }
        }
    }
    
    Opslaan-Data
    Start-Sleep -Seconds 5
}