# --- INITIALISATIE & WINDOWS GUI SETUP ---
# We laden de benodigde Windows-onderdelen voor vensters en iconen
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch {
    Write-Host "Fout bij laden van Windows Forms. Zorg dat je op Windows werkt."
    exit
}

# Locatie voor instellingen en verbruik (AppData map van de gebruiker)
$LogBestand = "$env:APPDATA\ProcessKiller_Settings.json"

# De data-structuur die we gebruiken
$script:Data = @{
    Datum           = (Get-Date).ToString("yyyy-MM-dd")
    Limieten        = @{} # Procesnaam = Aantal (min/uur)
    Verbruik        = @{} # Procesnaam = Totaal verbruikte seconden vandaag
    Eenheid         = @{} # Procesnaam = 'min' of 'uur'
    Categorie       = @{} # Procesnaam = 'app' of 'proces'
    LaatstGezien    = @{} # Interne timer voor berekening
}

# --- HULPFUNCTIES ---

# Zet seconden om naar een leesbaar formaat (bijv. 1u 5m 10s)
function Format-Tijd {
    param([int]$TotaalSeconden)
    $Uren = [Math]::Floor($TotaalSeconden / 3600)
    $Minuten = [Math]::Floor(($TotaalSeconden % 3600) / 60)
    $Seconden = $TotaalSeconden % 60
    
    $Result = ""
    if ($Uren -gt 0) { $Result += "$Uren" + "u " }
    if ($Minuten -gt 0 -or $Uren -gt 0) { $Result += "$Minuten" + "m " }
    $Result += "$Seconden" + "s"
    return $Result.Trim()
}

# Laad opgeslagen data uit het JSON-bestand
function Laad-Data {
    if (Test-Path $LogBestand) {
        try {
            $Geladen = Get-Content $LogBestand -Raw | ConvertFrom-Json
            if ($null -ne $Geladen.Limieten) { $script:Data.Limieten = $Geladen.Limieten }
            if ($null -ne $Geladen.Eenheid) { $script:Data.Eenheid = $Geladen.Eenheid }
            if ($null -ne $Geladen.Categorie) { $script:Data.Categorie = $Geladen.Categorie }
            
            # Alleen verbruik laden als de datum van vandaag is
            if ($Geladen.Datum -eq (Get-Date).ToString("yyyy-MM-dd")) {
                if ($null -ne $Geladen.Verbruik) { $script:Data.Verbruik = $Geladen.Verbruik }
            } else {
                $script:Data.Verbruik = @{}
                $script:Data.Datum = (Get-Date).ToString("yyyy-MM-dd")
            }
        } catch {
            Write-Warning "Kon instellingenbestand niet correct lezen."
        }
    }
}

# Sla huidige status op naar bestand
function Opslaan-Data {
    $script:Data | ConvertTo-Json | Out-File $LogBestand -Force
}

# --- INTERFACE ---

# Venster om een nieuwe app of proces toe te voegen
function Toevoegen-App-Venster {
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "Beheer Limieten"; $Form.Size = "350,420"; $Form.StartPosition = "CenterScreen"; $Form.Topmost = $true

    $TabControl = New-Object System.Windows.Forms.TabControl
    $TabControl.Size = "310,340"; $TabControl.Location = "12,12"
    
    $TabPage1 = New-Object System.Windows.Forms.TabPage; $TabPage1.Text = "Apps"
    $TabPage2 = New-Object System.Windows.Forms.TabPage; $TabPage2.Text = "Achtergrond"

    function Voeg-Tab-Controls($Tab, $Type) {
        $label = New-Object System.Windows.Forms.Label; $label.Text = "Procesnaam (zonder .exe):"; $label.Location = "10,20"; $label.AutoSize = $true
        $Tab.Controls.Add($label)

        $input = New-Object System.Windows.Forms.TextBox; $input.Location = "10,45"; $input.Width = 260
        $Tab.Controls.Add($input)

        $label2 = New-Object System.Windows.Forms.Label; $label2.Text = "Tijdlimiet:"; $label2.Location = "10,85"; $label2.AutoSize = $true
        $Tab.Controls.Add($label2)

        $timeInput = New-Object System.Windows.Forms.TextBox; $timeInput.Location = "10,110"; $timeInput.Width = 60
        $Tab.Controls.Add($timeInput)

        $unitCombo = New-Object System.Windows.Forms.ComboBox; $unitCombo.Location = "80,110"; $unitCombo.Width = 70
        $unitCombo.Items.AddRange(@("min", "uur")); $unitCombo.SelectedIndex = 0; $unitCombo.DropDownStyle = "DropDownList"
        $Tab.Controls.Add($unitCombo)

        $btn = New-Object System.Windows.Forms.Button; $btn.Text = "Toevoegen aan $Type"; $btn.Location = "10,160"; $btn.Width = 260; $btn.Height = 40
        $btn.BackColor = "LightGray"
        
        $btn.add_Click({
            $Name = $input.Text.ToLower().Replace(".exe", "").Trim()
            if ($Name -and $timeInput.Text -match '^\d+$') {
                $script:Data.Limieten.$Name = [int]$timeInput.Text
                $script:Data.Eenheid.$Name = $unitCombo.SelectedItem
                $script:Data.Categorie.$Name = if($Type -eq "Apps"){"app"}else{"proces"}
                $script:Data.Verbruik.$Name = 0
                Opslaan-Data
                $Form.Close()
            }
        })
        $Tab.Controls.Add($btn)
    }

    Voeg-Tab-Controls $TabPage1 "Apps"
    Voeg-Tab-Controls $TabPage2 "Achtergrond"
    $TabControl.Controls.Add($TabPage1); $TabControl.Controls.Add($TabPage2)
    $Form.Controls.Add($TabControl)
    $Form.ShowDialog() | Out-Null
}

# --- MONITOR ENGINE ---

Laad-Data
$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$NotifyIcon.Icon = [System.Drawing.SystemIcons]::Shield
$NotifyIcon.Visible = $true
$NotifyIcon.Text = "Process Killer Actief"

$ContextMenu = New-Object System.Windows.Forms.ContextMenu
$ContextMenu.MenuItems.Add("Limieten Instellen", { Toevoegen-App-Venster }) | Out-Null
$ContextMenu.MenuItems.Add("Status Bekijken", {
    $StatusTekst = "Verbruik Vandaag:`n"
    $Props = $script:Data.Limieten.PSObject.Properties.Name
    if ($null -eq $Props) { $StatusTekst += "(Geen limieten ingesteld)" }
    foreach ($App in $Props) {
        $Verbruikt = Format-Tijd ([int]$script:Data.Verbruik.$App)
        $Val = [int]$script:Data.Limieten.$App
        $TotaalSec = if($script:Data.Eenheid.$App -eq "uur"){$Val * 3600}else{$Val * 60}
        $LimietTekst = Format-Tijd $TotaalSec
        # FIX: Gebruik van ${} voorkomt 'InvalidVariableReferenceWithDrive' error door de dubbele punt
        $StatusTekst += "- ${App}: ${Verbruikt} / ${LimietTekst}`n"
    }
    [System.Windows.Forms.MessageBox]::Show($StatusTekst, "Huidige Status")
}) | Out-Null
$ContextMenu.MenuItems.Add("-") | Out-Null
$ContextMenu.MenuItems.Add("Monitor Stoppen", { $NotifyIcon.Visible = $false; Stop-Process -Id $PID }) | Out-Null
$NotifyIcon.ContextMenu = $ContextMenu

# Hoofdloop die elke 5 seconden kijkt
while($true) {
    $Nu = Get-Date
    # Controleer of de dag is gewisseld voor automatische reset
    if ($Nu.ToString("yyyy-MM-dd") -ne $script:Data.Datum) {
        $script:Data.Datum = $Nu.ToString("yyyy-MM-dd")
        $script:Data.Verbruik = @{}
        Opslaan-Data
    }

    $AlleProcessen = Get-Process -ErrorAction SilentlyContinue

    foreach ($App in $script:Data.Limieten.PSObject.Properties.Name) {
        $ProcesActive = $AlleProcessen | Where-Object { $_.ProcessName -eq $App }

        if ($ProcesActive) {
            # Bereken hoeveel tijd er verstreken is sinds de laatste check
            if ($null -ne $script:Data.LaatstGezien.$App) {
                $Verschil = ($Nu - [datetime]$script:Data.LaatstGezien.$App).TotalSeconds
                # Voorkom grote sprongen als PC uit slaapstand komt (max 60 sec per check)
                if ($Verschil -gt 0 -and $Verschil -lt 60) { 
                    $script:Data.Verbruik.$App = [double]$script:Data.Verbruik.$App + $Verschil
                }
            }
            $script:Data.LaatstGezien.$App = $Nu.ToString("yyyy-MM-dd HH:mm:ss")

            # Check tegen de limiet
            $LimietWaarde = [int]$script:Data.Limieten.$App
            $TotaalLimietSec = if($script:Data.Eenheid.$App -eq "uur"){$LimietWaarde * 3600}else{$LimietWaarde * 60}

            if ($script:Data.Verbruik.$App -ge $TotaalLimietSec) {
                $ProcesActive | Stop-Process -Force -ErrorAction SilentlyContinue
                $TijdGeformatteerd = Format-Tijd $TotaalLimietSec
                $NotifyIcon.ShowBalloonTip(5000, "Tijd is op!", "De app ${App} is gesloten na ${TijdGeformatteerd}.", "Warning")
            }
        } else {
            # Proces draait niet, zet de timer pauze indicator op null
            $script:Data.LaatstGezien.$App = $null
        }
    }

    Opslaan-Data
    Start-Sleep -Seconds 5
}