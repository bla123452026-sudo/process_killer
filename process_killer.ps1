# --- INITIALISATIE & WINDOWS GUI SETUP ---
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch {
    Write-Host "Fout bij laden van Windows Forms. Zorg dat je op Windows werkt."
    exit
}

# Locatie voor instellingen en verbruik
$LogBestand = "$env:APPDATA\ProcessKiller_Settings.json"

$script:Data = @{
    Datum           = (Get-Date).ToString("yyyy-MM-dd")
    Limieten        = @{} 
    Verbruik        = @{} 
    Eenheid         = @{} 
    Categorie       = @{} 
    LaatstGezien    = @{} 
}

# --- HULPFUNCTIES ---

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

function Laad-Data {
    if (Test-Path $LogBestand) {
        try {
            $Geladen = Get-Content $LogBestand -Raw | ConvertFrom-Json
            if ($null -ne $Geladen.Limieten) { $script:Data.Limieten = $Geladen.Limieten }
            if ($null -ne $Geladen.Eenheid) { $script:Data.Eenheid = $Geladen.Eenheid }
            if ($null -ne $Geladen.Categorie) { $script:Data.Categorie = $Geladen.Categorie }
            if ($Geladen.Datum -eq (Get-Date).ToString("yyyy-MM-dd")) {
                if ($null -ne $Geladen.Verbruik) { $script:Data.Verbruik = $Geladen.Verbruik }
            } else {
                $script:Data.Verbruik = @{}
                $script:Data.Datum = (Get-Date).ToString("yyyy-MM-dd")
            }
        } catch {}
    }
}

function Opslaan-Data {
    $script:Data | ConvertTo-Json | Out-File $LogBestand -Force
}

# --- INTERFACE ---

function Toevoegen-App-Venster {
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "Beheer Limieten"; $Form.Size = "350,420"; $Form.StartPosition = "CenterScreen"; $Form.Topmost = $true

    $TabControl = New-Object System.Windows.Forms.TabControl
    $TabControl.Size = "310,340"; $TabControl.Location = "12,12"
    
    $TabPage1 = New-Object System.Windows.Forms.TabPage; $TabPage1.Text = "Apps"
    $TabPage2 = New-Object System.Windows.Forms.TabPage; $TabPage2.Text = "Achtergrond"

    # We gebruiken een functie om de tabs te vullen, maar we moeten zorgen dat de variabelen bereikbaar zijn
    function Build-Tab($Tab, $Type) {
        $label = New-Object System.Windows.Forms.Label; $label.Text = "Procesnaam (zonder .exe):"; $label.Location = "10,20"; $label.AutoSize = $true
        $Tab.Controls.Add($label)
        
        $inputField = New-Object System.Windows.Forms.TextBox; $inputField.Location = "10,45"; $inputField.Width = 260
        $Tab.Controls.Add($inputField)
        
        $label2 = New-Object System.Windows.Forms.Label; $label2.Text = "Tijdlimiet:"; $label2.Location = "10,85"; $label2.AutoSize = $true
        $Tab.Controls.Add($label2)
        
        $timeField = New-Object System.Windows.Forms.TextBox; $timeField.Location = "10,110"; $timeField.Width = 60
        $Tab.Controls.Add($timeField)
        
        $unitField = New-Object System.Windows.Forms.ComboBox; $unitField.Location = "80,110"; $unitCombo.Width = 70
        $unitField.Items.AddRange(@("min", "uur")); $unitField.SelectedIndex = 0; $unitField.DropDownStyle = "DropDownList"
        $Tab.Controls.Add($unitField)
        
        $saveBtn = New-Object System.Windows.Forms.Button; $saveBtn.Text = "Toevoegen aan $Type"; $saveBtn.Location = "10,160"; $saveBtn.Width = 260; $saveBtn.Height = 40; $saveBtn.BackColor = "LightGray"
        
        # De fix: we geven de velden mee aan de knop via een custom property of we gebruiken de juiste scope
        $saveBtn.add_Click({
            $Name = $inputField.Text.ToLower().Replace(".exe", "").Trim()
            if ($Name -and $timeField.Text -match '^\d+$') {
                $script:Data.Limieten.$Name = [int]$timeField.Text
                $script:Data.Eenheid.$Name = $unitField.SelectedItem
                $script:Data.Categorie.$Name = if($Type -eq "Apps"){"app"}else{"proces"}
                $script:Data.Verbruik.$Name = 0
                Opslaan-Data
                $Form.Close()
            } else {
                [System.Windows.Forms.MessageBox]::Show("Vul een geldige naam en tijd (cijfers) in.", "Fout")
            }
        })
        $Tab.Controls.Add($saveBtn)
    }

    Build-Tab $TabPage1 "Apps"
    Build-Tab $TabPage2 "Achtergrond"
    
    $TabControl.Controls.Add($TabPage1)
    $TabControl.Controls.Add($TabPage2)
    $Form.Controls.Add($TabControl)
    $Form.ShowDialog() | Out-Null
}

# --- MONITOR ENGINE ---

Laad-Data
$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$NotifyIcon.Icon = [System.Drawing.SystemIcons]::Shield
$NotifyIcon.Visible = $true
$NotifyIcon.Text = "Process Killer Actief"

$NotifyIcon.ShowBalloonTip(3000, "Monitor Gestart", "Rechtsklik op het schild-icoontje rechtsonder voor het menu.", "Info")

$ContextMenu = New-Object System.Windows.Forms.ContextMenu
$ContextMenu.MenuItems.Add("Limieten Instellen", { Toevoegen-App-Venster }) | Out-Null
$ContextMenu.MenuItems.Add("Status Bekijken", {
    $StatusTekst = "Verbruik Vandaag:`n"
    $Props = $script:Data.Limieten.PSObject.Properties.Name
    if ($null -eq $Props -or $Props.Count -eq 0) { $StatusTekst += "(Geen limieten ingesteld)" }
    foreach ($App in $Props) {
        $Verbruikt = Format-Tijd ([int]$script:Data.Verbruik.$App)
        $Val = [int]$script:Data.Limieten.$App
        $TotaalSec = if($script:Data.Eenheid.$App -eq "uur"){$Val * 3600}else{$Val * 60}
        $LimietTekst = Format-Tijd $TotaalSec
        $StatusTekst += "- ${App}: ${Verbruikt} / ${LimietTekst}`n"
    }
    [System.Windows.Forms.MessageBox]::Show($StatusTekst, "Huidige Status")
}) | Out-Null
$ContextMenu.MenuItems.Add("-") | Out-Null
$ContextMenu.MenuItems.Add("Monitor Stoppen", { $NotifyIcon.Visible = $false; Stop-Process -Id $PID }) | Out-Null
$NotifyIcon.ContextMenu = $ContextMenu

# Loop blijft hetzelfde
while($true) {
    $Nu = Get-Date
    if ($Nu.ToString("yyyy-MM-dd") -ne $script:Data.Datum) {
        $script:Data.Datum = $Nu.ToString("yyyy-MM-dd")
        $script:Data.Verbruik = @{}
        Opslaan-Data
    }

    $AlleProcessen = Get-Process -ErrorAction SilentlyContinue

    foreach ($App in $script:Data.Limieten.PSObject.Properties.Name) {
        $ProcesActive = $AlleProcessen | Where-Object { $_.ProcessName -eq $App }

        if ($ProcesActive) {
            if ($null -ne $script:Data.LaatstGezien.$App) {
                $Verschil = ($Nu - [datetime]$script:Data.LaatstGezien.$App).TotalSeconds
                if ($Verschil -gt 0 -and $Verschil -lt 60) { 
                    $script:Data.Verbruik.$App = [double]$script:Data.Verbruik.$App + $Verschil
                }
            }
            $script:Data.LaatstGezien.$App = $Nu.ToString("yyyy-MM-dd HH:mm:ss")

            $LimietWaarde = [int]$script:Data.Limieten.$App
            $TotaalLimietSec = if($script:Data.Eenheid.$App -eq "uur"){$LimietWaarde * 3600}else{$LimietWaarde * 60}

            if ($script:Data.Verbruik.$App -ge $TotaalLimietSec) {
                $ProcesActive | Stop-Process -Force -ErrorAction SilentlyContinue
                $TijdGeformatteerd = Format-Tijd $TotaalLimietSec
                $NotifyIcon.ShowBalloonTip(5000, "Tijd is op!", "De app ${App} is gesloten na ${TijdGeformatteerd}.", "Warning")
            }
        } else {
            $script:Data.LaatstGezien.$App = $null
        }
    }
    Opslaan-Data
    Start-Sleep -Seconds 5
}