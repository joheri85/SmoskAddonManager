﻿$Version = "2.21.0"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.Windows.Forms.Application]::EnableVisualStyles()



function Unzip
{
    param([string]$zipfile, [string]$outpath)

    try{

        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
    } catch {
        Write-Host "Addon already installed, Importing only"
        Continue
    }
}

Function Get-KeyState ([uint16]$keyCode) {
    $signature = '[DllImport("user32.dll")]public static extern short GetKeyState(int nVirtKey);'
    $type = Add-Type -MemberDefinition $signature -Name User32 -Namespace GetKeyState -PassThru
    return [bool]($type::GetKeyState($keyCode) -band 0x80)
}

Function Get-Folder() {
    param([string]$Description)

    $initialDirectory=""
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.Description = $Description
    $foldername.rootfolder = "MyComputer"
    $foldername.SelectedPath = $initialDirectory
    $result = $FolderName.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true}))
   

    if($result -eq [Windows.Forms.DialogResult]::OK) {
        $folder += $foldername.SelectedPath
    }
    $foldername.Dispose()
    return $folder
}



Function NewAddon {

    Param ($ID, $ImportOnly)

    $IsInstalled = ($Addons.config.Addon | Where-Object ID -EQ $ID).length
    
    if ($IsInstalled -EQ 0) {
        
        $Url = "https://addons-ecs.forgesvc.net/api/v2/addon/" + $ID
            
        $MethodError = $true
        While ($MethodError) {

            Try {

                $AddonToInstall = Invoke-RestMethod -Uri $Url -TimeoutSec 5
                $MethodError = $false
                Start-Sleep -Seconds 1
            } catch {
                if (Test-Path ".\Resources\error_log.txt") {
                    "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\error_log.txt" -Append
                    $_ | Out-File ".\Resources\error_log.txt" -Append
                } else {
                    "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\error_log.txt"
                    $_ | Out-File ".\Resources\error_log.txt" -Append
        
                }
            }
        }

        

        $AddonInfo = $AddonToInstall | 
            Select-Object -ExpandProperty LatestFiles  |
                Where-Object {($_.GameVersionFlavor -eq "wow_classic") -and ($_.ReleaseType -eq "1")  }
        
        if (($null -ne $AddonInfo.length) -and ($null -ne $AddonInfo)){

            $AddonInfo = $AddonInfo[0]

        }
       
        If ($null -ne $AddonInfo){
            
                        
            $Link = $AddonInfo.downloadUrl         
            
            $subnode = $Addons.SelectSingleNode("config")
            
            $child = $Addons.CreateElement("Addon")

            $SubChildID = $Addons.CreateElement("ID")
            $SubChildName = $Addons.CreateElement("Name")
            $SubChildDownloadLink = $Addons.CreateElement("DownloadLink")
            $SubChildDescription = $Addons.CreateElement("Description")
            $SubChildVersion = $Addons.CreateElement("CurrentVersion")
            $SubChildLVersion = $Addons.CreateElement("LatestVersion")
            $SubChildModules = $Addons.CreateElement("Modules")
            $SubChildDateUpdated = $Addons.CreateElement("DateUpdated")
           
            $child.AppendChild($SubChildID)
            $child.AppendChild($SubChildName)
            $child.AppendChild($SubChildDownloadLink)
            $child.AppendChild($SubChildDescription)
            $child.AppendChild($SubChildVersion)
            $child.AppendChild($SubChildLVersion)
            $child.AppendChild($SubChildModules)
            $child.AppendChild($SubChildDateUpdated)
           
            $child.ID = $ID
            $child.DownloadLink = $Link.ToString()
            $child.Description = $AddonToInstall.summary
            $child.Name = $AddonToInstall.Name
            $child.LatestVersion = $AddonInfo.displayName.ToString()
            $Modules = $AddonToInstall | 
                Select-Object -ExpandProperty LatestFiles | 
                    Where-Object {($_.GameVersionFlavor -eq "wow_classic") -and ($_.ReleaseType -eq "1") } | 
                        select-Object -Property Modules

            $ModulesString = ""
        
            foreach ($Module in $Modules.modules){

                $ModulesString += ($Module.foldername + ",")

            }
           
            $ModulesString = $ModulesString.Substring(0,$ModulesString.Length-1)
            
            $child.Modules = $ModulesString

            $child.DateUpdated = ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date), 'Central European Standard Time')).ToString("yyyy-MM-dd HH:mm")


            if ($ImportOnly) { 
                $child.CurrentVersion = "Imported, Update to display version."
                
            } else {
                $child.CurrentVersion = $AddonInfo.displayName.ToString()
            }
            $subnode.AppendChild($child)
        
            $Addons.Save($XMLPath)

            if ($ImportOnly -eq $false) { 
                $OutFile = (".\Downloads\TempAddonDownload.zip")
                Invoke-WebRequest -Uri $Link -OutFile $OutFile -TimeoutSec 20
                Unzip -zipfile $OutFile -outpath $Addons.config.IfaceAddonsFolder
                Remove-Item $OutFile -Force 
            }
        
        }
        
    }
}

Function UpdateAddon {

    Param ($AddonID)

    DeleteAddon -ID $AddonID
    NewAddon -ID $AddonID -ImportOnly $false
    
}



Function DeleteAddon {

    Param($ID)  

    if ($null -ne $Addons.config.Addon ) {
      
        $AddonToDelete = $Addons.config.Addon | Where-Object ID -EQ $ID
        
        foreach ($Folder in $AddonToDelete.Modules.split(",")) {

            $PathToDelete = $Addons.config.IfaceAddonsFolder + "\" + $Folder

            if (Test-Path $PathToDelete) {

                Remove-Item -LiteralPath $PathToDelete -Force -Recurse

            }

        }

        $Addons.config.RemoveChild($AddonToDelete)

        $Addons.Save($XMLPath)
    }
    
}

Function SetIfaceAddonsFolder {
    
    Try {
        $Path = Get-Folder -Description "Select your Classic addons dir:

Example:  D:\World of Warcraft\_classic_\Interface\Addons"
        } catch {
            $Path = $null
            Continue
        } 

    if ($null -ne $Path) {

        $Addons.config.IfaceAddonsFolder = $Path
        $ButtonIfaceAddonsPath.Text = $Path
        $Addons.Save($XMLPath)

    }
    
}





Function DrawGUI {

    

    $global:dragging = $false
    $global:mouseDragX = 0
    $global:mouseDragY = 0



    $workareaWidth = 0
    $workareaHeight = 0
    foreach ($screen in ([System.Windows.Forms.Screen]::AllScreens) ) {
        $workareaWidth += [int]($screen | Select-Object -ExpandProperty WorkingArea).Width
        $workareaHeight += [int]($screen | Select-Object -ExpandProperty WorkingArea).Height
    }


    #*** colors
    $CreamText = [System.Drawing.ColorTranslator]::FromHtml("#f1c898")
    $StandardButtonColor = [System.Drawing.ColorTranslator]::FromHtml("#212121")
    $StandardButtonTextColor = [System.Drawing.Color]::Snow

    if ($null -eq $Addons.config.HighlightFont) {
        $node = $Addons.SelectSingleNode("config")
        $newNode = $Addons.CreateNode("element", "HighlightFont", $null)
        $node.AppendChild($newNode)
        $Addons.config.HighlightFont = "Georgia"
        $Addons.Save($XMLPath)
    } 
    if ($null -eq $Addons.config.DetailFont) {
        $node = $Addons.SelectSingleNode("config")
        $newNode = $Addons.CreateNode("element", "DetailFont", $null)
        $node.AppendChild($newNode)
        $Addons.config.DetailFont = "Arial"
        $Addons.Save($XMLPath)
    }
    


    


    #*** Splash Form ******************************************************************************************************
    $SplashScreen = New-Object System.Windows.Forms.Form
    $SplashScreen.Text ="SMOSK - Classic Addon Manager"
    $SplashScreen.minimumSize = New-Object System.Drawing.Size(500,250) 
    $SplashScreen.maximumSize = New-Object System.Drawing.Size(500,250) 
    $SplashScreen.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen 
    $SplashScreen.AutoSize = $true
    $SplashScreen.SizeGripStyle = "Hide"
    $SplashScreen.FormBorderStyle = [System.Windows.Forms.BorderStyle]::"None"
    $SplashScreen.BackColor = [System.Drawing.Color]::Black
    $SplashScreen.BackgroundImage = [system.drawing.image]::FromFile($Addons.config.Splash)
    $SplashScreen.BackgroundImageLayout = "Zoom"

    #*** Label Splash
    $LabelSplash = New-Object System.Windows.Forms.Label
    $LabelSplash.Text = "SMOSK
Classic Addon Manager" 
    $LabelSplash.Location  = New-Object System.Drawing.Point(0,30)
    $LabelSplash.Size = New-Object System.Drawing.Size(500,50)
    $LabelSplash.TextAlign = "MiddleCenter"
    $LabelSplash.BackColor = [System.Drawing.Color]::Transparent
    $LabelSplash.ForeColor = [System.Drawing.Color]::White
    $LabelSplash.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 12, [System.Drawing.FontStyle]::Bold)
    $SplashScreen.Controls.Add($LabelSplash)

     #*** Label Splash
     $LabelSplashStatus = New-Object System.Windows.Forms.Label
     $LabelSplashStatus.Text = "Loading Addon list" 
     $LabelSplashStatus.Location  = New-Object System.Drawing.Point(0,180)
     $LabelSplashStatus.Size = New-Object System.Drawing.Size(500,50)
     $LabelSplashStatus.TextAlign = "MiddleCenter"
     $LabelSplashStatus.BackColor = [System.Drawing.Color]::Transparent
     $LabelSplashStatus.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffa500")
     $LabelSplashStatus.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 10, [System.Drawing.FontStyle]::Bold)
     $SplashScreen.Controls.Add($LabelSplashStatus)

    $SplashScreen.Show()
    $LabelSplash.Update()
    Start-Sleep -Seconds 3

    #*** Change Form ******************************************************************************************************
    $change_form = New-Object System.Windows.Forms.Form
    
    $change_form.minimumSize = New-Object System.Drawing.Size(500,705) 
    $change_form.maximumSize = New-Object System.Drawing.Size(500,705) 
    $change_form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen 
    $change_form.AutoSize = $false
    $change_form.SizeGripStyle = "Hide"
    $change_form.FormBorderStyle = "None"
    $change_form.BackColor = [System.Drawing.Color]::Black
    $change_form.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\wallpaper_search.png")
    $change_form.BackgroundImageLayout = "Center"

    $LabelMovechangeForm = New-Object System.Windows.Forms.Label
    $LabelMovechangeForm.Name = "LabelMoveSearchForm"
    $LabelMovechangeForm.BackColor = [System.Drawing.Color]::Black
    $LabelMovechangeForm.Location = New-Object System.Drawing.Point(2, 2)
    $LabelMovechangeForm.Size = New-Object System.Drawing.Size(496, 30)
    $LabelMovechangeForm.Anchor = "Top","Left"
    $LabelMovechangeForm.BorderStyle = "None"
    $LabelMovechangeForm.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 12, [System.Drawing.FontStyle]::Bold)
    $LabelMovechangeForm.ForeColor = $CreamText
    $LabelMovechangeForm.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    
    $LabelMovechangeForm.Add_MouseDown( { 
        $global:dragging = $true
        $global:mouseDragX = [System.Windows.Forms.Cursor]::Position.X - $change_form.Left
        $global:mouseDragY = [System.Windows.Forms.Cursor]::Position.Y - $change_form.Top
    })

    $LabelMovechangeForm.Add_MouseMove( { 
        if($global:dragging) {
            $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
            $currentX = [System.Windows.Forms.Cursor]::Position.X
            $currentY = [System.Windows.Forms.Cursor]::Position.Y
            [int]$newX = [Math]::Min($currentX - $global:mouseDragX, $workareaWidth - $change_form.Width)
            [int]$newY = [Math]::Min($currentY - $global:mouseDragY, $workareaHeight - $change_form.Height)
            $change_form.Location = New-Object System.Drawing.Point($newX, $newY)
        }
    })

    $LabelMovechangeForm.Add_MouseUp( { 
        $global:dragging = $false 
    })

    $ButtonClosechangeForm = New-Object System.Windows.Forms.Button
    $ButtonClosechangeForm.Name = "ButtonCloseMainForm"
    $ButtonClosechangeForm.Anchor = "Top","Left"
    $ButtonClosechangeForm.Location = New-Object System.Drawing.Point(475, 5)
    $ButtonClosechangeForm.Size = New-Object System.Drawing.Size(20, 20)
    
    $ButtonClosechangeForm.TextAlign = "BottomCenter"
    $ButtonClosechangeForm.FlatStyle = "PopUp"
    $ButtonClosechangeForm.UseVisualStyleBackColor = $true
    $ButtonClosechangeForm.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\close.png")
    $ButtonClosechangeForm.BackgroundImageLayout = "Zoom"
    $ButtonClosechangeForm.ForeColor = [System.Drawing.Color]::White
    $ButtonClosechangeForm.BackColor = [System.Drawing.Color]::Black
    $ButtonClosechangeForm.UseMnemonic = $true
    $ButtonClosechangeForm.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $ButtonMinimizechangeForm = New-Object System.Windows.Forms.Button
    $ButtonMinimizechangeForm.Name = "ButtonCloseMainForm"
    $ButtonMinimizechangeForm.Anchor = "Top","Left"
    $ButtonMinimizechangeForm.Location = New-Object System.Drawing.Point(450, 5)
    $ButtonMinimizechangeForm.Size = New-Object System.Drawing.Size(20, 20)
    #$ButtonMinimizeSearchForm.Text = "_"
    $ButtonMinimizechangeForm.FlatStyle = "PopUp"
    $ButtonMinimizechangeForm.UseVisualStyleBackColor = $true
    $ButtonMinimizechangeForm.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\minimize.png")
    $ButtonMinimizechangeForm.BackgroundImageLayout = "Zoom"
    $ButtonMinimizechangeForm.ForeColor = [System.Drawing.Color]::White
    $ButtonMinimizechangeForm.BackColor = [System.Drawing.Color]::Black
    
    $ButtonMinimizechangeForm.Add_Click({
        $change_form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
    })

    $Changelogbox = New-Object System.Windows.Forms.TextBox 
    $Changelogbox.Multiline = $True;
    $Changelogbox.Font = [System.Drawing.Font]::new($Addons.config.DetailFont, 10, [System.Drawing.FontStyle]::Bold)
    $Changelogbox.Location = New-Object System.Drawing.Size(2,30) 
    $Changelogbox.Size = New-Object System.Drawing.Size(496,673)
    $Changelogbox.BackColor = [System.Drawing.Color]::Black
    $Changelogbox.ForeColor = [System.Drawing.Color]::White
    $Changelogbox.Scrollbars = "Vertical" 
    $Changelogbox.BorderStyle = "None"

    $change_form.Controls.Add($Changelogbox)
    $change_form.Controls.Add($LabelMovechangeForm)
    $change_form.Controls.Add($ButtonMinimizechangeForm)
    $change_form.Controls.Add($ButtonClosechangeForm)
    $ButtonMinimizechangeForm.BringToFront()
    $ButtonClosechangeForm.BringToFront()





    #*** Search Form ******************************************************************************************************
    $Search_form = New-Object System.Windows.Forms.Form
    
    $Search_form.minimumSize = New-Object System.Drawing.Size(500,705) 
    $Search_form.maximumSize = New-Object System.Drawing.Size(500,705) 
    $Search_form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen 
    $Search_form.AutoSize = $false
    $Search_form.SizeGripStyle = "Hide"
    $Search_form.FormBorderStyle = "None"
    $Search_form.BackColor = [System.Drawing.Color]::Black
    $Search_form.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\wallpaper_search.png")
    $Search_form.BackgroundImageLayout = "Center"

    $LabelMoveSearchForm = New-Object System.Windows.Forms.Label
    $LabelMoveSearchForm.Name = "LabelMoveSearchForm"
    $LabelMoveSearchForm.BackColor = [System.Drawing.Color]::Transparent
    $LabelMoveSearchForm.Location = New-Object System.Drawing.Point(0, 0)
    $LabelMoveSearchForm.Size = New-Object System.Drawing.Size(440, 30)
    $LabelMoveSearchForm.Anchor = "Top","Left"
    $LabelMoveSearchForm.BorderStyle = "None"
    $LabelMoveSearchForm.Text = "SMOSK - Classic Addon Manager"
    $LabelMoveSearchForm.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 12, [System.Drawing.FontStyle]::Bold)
    $LabelMoveSearchForm.ForeColor = [System.Drawing.Color]::White
    $LabelMoveSearchForm.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    
    $LabelMoveSearchForm.Add_MouseDown( { 
        $global:dragging = $true
        $global:mouseDragX = [System.Windows.Forms.Cursor]::Position.X - $Search_form.Left
        $global:mouseDragY = [System.Windows.Forms.Cursor]::Position.Y - $Search_form.Top
    })

    $LabelMoveSearchForm.Add_MouseMove( { 
        if($global:dragging) {
            $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
            $currentX = [System.Windows.Forms.Cursor]::Position.X
            $currentY = [System.Windows.Forms.Cursor]::Position.Y
            [int]$newX = [Math]::Min($currentX - $global:mouseDragX, $workareaWidth - $Search_form.Width)
            [int]$newY = [Math]::Min($currentY - $global:mouseDragY, $workareaHeight - $Search_form.Height)
            $Search_form.Location = New-Object System.Drawing.Point($newX, $newY)
        }
    })

    $LabelMoveSearchForm.Add_MouseUp( { 
        $global:dragging = $false 
    })

    $ButtonCloseSearchForm = New-Object System.Windows.Forms.Button
    $ButtonCloseSearchForm.Name = "ButtonCloseMainForm"
    $ButtonCloseSearchForm.Anchor = "Top","Left"
    $ButtonCloseSearchForm.Location = New-Object System.Drawing.Point(475, 5)
    $ButtonCloseSearchForm.Size = New-Object System.Drawing.Size(20, 20)
    #$ButtonCloseSearchForm.Text = "X"
    $ButtonCloseSearchForm.TextAlign = "BottomCenter"
    $ButtonCloseSearchForm.FlatStyle = "PopUp"
    $ButtonCloseSearchForm.UseVisualStyleBackColor = $true
    $ButtonCloseSearchForm.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\close.png")
    $ButtonCloseSearchForm.BackgroundImageLayout = "Zoom"
    $ButtonCloseSearchForm.ForeColor = [System.Drawing.Color]::White
    $ButtonCloseSearchForm.BackColor = [System.Drawing.Color]::Black
    $ButtonCloseSearchForm.UseMnemonic = $true
    $ButtonCloseSearchForm.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $ButtonMinimizeSearchForm = New-Object System.Windows.Forms.Button
    $ButtonMinimizeSearchForm.Name = "ButtonCloseMainForm"
    $ButtonMinimizeSearchForm.Anchor = "Top","Left"
    $ButtonMinimizeSearchForm.Location = New-Object System.Drawing.Point(450, 5)
    $ButtonMinimizeSearchForm.Size = New-Object System.Drawing.Size(20, 20)
    #$ButtonMinimizeSearchForm.Text = "_"
    $ButtonMinimizeSearchForm.FlatStyle = "PopUp"
    $ButtonMinimizeSearchForm.UseVisualStyleBackColor = $true
    $ButtonMinimizeSearchForm.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\minimize.png")
    $ButtonMinimizeSearchForm.BackgroundImageLayout = "Zoom"
    $ButtonMinimizeSearchForm.ForeColor = [System.Drawing.Color]::White
    $ButtonMinimizeSearchForm.BackColor = [System.Drawing.Color]::Black
    
    $ButtonMinimizeSearchForm.Add_Click({
        $Search_form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
    })

    $Search_form.Controls.Add($LabelMoveSearchForm)
    $Search_form.Controls.Add($ButtonMinimizeSearchForm)
    $Search_form.Controls.Add($ButtonCloseSearchForm)

    #*** Label Search string
    $LabelSearchString = New-Object System.Windows.Forms.Label
    $LabelSearchString.Text = "Search CurseForge for addons"
    $LabelSearchString.Location  = New-Object System.Drawing.Point(10,40)
    $LabelSearchString.Size = New-Object System.Drawing.Size(380,30)
    $LabelSearchString.TextAlign = "MiddleLeft"
    $LabelSearchString.BackColor = [System.Drawing.Color]::Transparent
    $LabelSearchString.ForeColor = [System.Drawing.Color]::White
    $LabelSearchString.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 12, [System.Drawing.FontStyle]::Bold)
    $Search_form.Controls.Add($LabelSearchString)

    #*** Textbox Search String
    $textBoxSearchString = New-Object System.Windows.Forms.TextBox
    $textBoxSearchString.Location = New-Object System.Drawing.Size(10,70)
    $textBoxSearchString.Size = New-Object System.Drawing.Size(400,20)
    $textBoxSearchString.ForeColor = [System.Drawing.Color]::White
    $textBoxSearchString.BackColor = [System.Drawing.Color]::Black
    $textBoxSearchString.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 12, [System.Drawing.FontStyle]::Bold)
    $Search_form.Controls.Add($textBoxSearchString)

    $TextBoxSearchString.Add_KeyDown({

        if ($_.KeyCode -eq "Enter") {

            CurseForgeSearch -SearchTerm $textBoxSearchString.Text
            $textBoxSearchString.Clear()

        }      
    })

    #*** Button Search CurseForge
    $ButtonDoSearch = New-Object System.Windows.Forms.Button
    $ButtonDoSearch.Location = New-Object System.Drawing.Size(415,70)
    $ButtonDoSearch.Size = New-Object System.Drawing.Size(75,26)
    $ButtonDoSearch.Text = "Search"
    $ButtonDoSearch.FlatStyle = "Popup"
    $ButtonDoSearch.BackColor = $StandardButtonColor
    $ButtonDoSearch.ForeColor = $StandardButtonTextColor
    $ButtonDoSearch.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 7, [System.Drawing.FontStyle]::Bold)
    $Search_form.Controls.Add($ButtonDoSearch)

    $ButtonDoSearch.Add_Click({
        
        CurseForgeSearch -SearchTerm $textBoxSearchString.Text
        $textBoxSearchString.Clear()

    })

    #*** Label Search results
    $LabelSearchResult = New-Object System.Windows.Forms.Label
    $LabelSearchResult.Text = "Search results"
    $LabelSearchResult.Location  = New-Object System.Drawing.Point(10,100)
    $LabelSearchResult.Size = New-Object System.Drawing.Size(450,30)
    $LabelSearchResult.TextAlign = "MiddleLeft"
    $LabelSearchResult.BackColor = [System.Drawing.Color]::Transparent
    $LabelSearchResult.ForeColor = [System.Drawing.Color]::White
    $LabelSearchResult.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 12, [System.Drawing.FontStyle]::Bold)
    $Search_form.Controls.Add($LabelSearchResult)

    #*** Search result List
    $ListSearchResults = New-Object System.Windows.Forms.ListView
    $ListSearchResults.Location = New-Object System.Drawing.Point(10,130)
    $ListSearchResults.Size = New-Object System.Drawing.Size(465,240)
    $ListSearchResults.Anchor = 'Top, Bottom, Left, Right'
    $ListSearchResults.View = 'Details'
    $ListSearchResults.ShowItemToolTips = $true
    $ListSearchResults.GridLines = $true
    $ListSearchResults.FullRowSelect = $true
    $ListSearchResults.MultiSelect = $true
    $ListSearchResults.GridLines = $false
    $ListSearchResults.BackColor = [System.Drawing.Color]::Black
    $ListSearchResults.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
    $ListSearchResults.Font = [System.Drawing.Font]::new($Addons.config.DetailFont, 8, [System.Drawing.FontStyle]::Regular)
    
    $ListSearchResults.Add_click({
        
        $SelectedResult = $Global:SearchResult | Where-Object id -eq $ListSearchResults.SelectedItems[0].Text
        
        $LabelSearchDescriptionText.Text = "Loading description..."
        
        $Thumbnail = $SelectedResult | Select-Object -ExpandProperty attachments
        $LabelSearchDescriptionText.Text = $SelectedResult.summary
        if ($null -ne $thumbnail) {
            $pictureBox.Load($thumbnail[0].thumbnailUrl)
        } else {
            $pictureBox.image = $null
        }
        
        
    })

    $Search_form.Controls.Add($ListSearchResults)

    #*** LabelPicturebox
    $LablePictureBox = New-Object System.Windows.Forms.Label
    $LablePictureBox.Text = "Thumbnail"
    $LablePictureBox.Location  = New-Object System.Drawing.Point(10,490)
    $LablePictureBox.Size = New-Object System.Drawing.Size(180,20)
    $LablePictureBox.TextAlign = "MiddleCenter"
    $LablePictureBox.BackColor = [System.Drawing.Color]::Transparent
    $LablePictureBox.ForeColor = [System.Drawing.Color]::White
    $LablePictureBox.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 12, [System.Drawing.FontStyle]::Bold)
    $Search_form.Controls.Add($LablePictureBox)

    #*** Thumbnail picturebox
    $pictureBox = new-object Windows.Forms.PictureBox
    $pictureBox.Location = New-Object System.Drawing.Point(10,510)
    $pictureBox.Size = New-Object System.Drawing.Size(180,180)
    $pictureBox.BorderStyle = "FixedSingle"
    $pictureBox.SizeMode = "Zoom"
    $Search_form.controls.add($pictureBox)

    #*** Label Description title
    $LabelSearchDescription = New-Object System.Windows.Forms.Label
    $LabelSearchDescription.Text = "Description"
    $LabelSearchDescription.Location  = New-Object System.Drawing.Point(190,490)
    $LabelSearchDescription.Size = New-Object System.Drawing.Size(300,20)
    $LabelSearchDescription.TextAlign = "MiddleCenter"
    $LabelSearchDescription.BackColor = [System.Drawing.Color]::Transparent
    $LabelSearchDescription.ForeColor = [System.Drawing.Color]::White
    $LabelSearchDescription.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 12, [System.Drawing.FontStyle]::Bold)
    $Search_form.Controls.Add($LabelSearchDescription)

    #*** Button Web Link
    $ButtonWebURL = New-Object System.Windows.Forms.Button
    $ButtonWebURL.Location = New-Object System.Drawing.Size(10,415)
    $ButtonWebURL.Size = New-Object System.Drawing.Size(235,40)
    $ButtonWebURL.BackColor = [System.Drawing.Color]::Transparent
    $ButtonWebURL.Text = "Visit CursForge page"
    $ButtonWebURL.FlatStyle = "Popup"
    $ToolTipWebURL = New-Object System.Windows.Forms.ToolTip
    $ToolTipWebURL.SetToolTip($ButtonWebURL,"Opens selected addon page on CurseForge with your standard Web browser.") 
    $ButtonWebURL.BackColor = $StandardButtonColor
    $ButtonWebURL.ForeColor = $StandardButtonTextColor
    $ButtonWebURL.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 7, [System.Drawing.FontStyle]::Bold)
    $Search_form.Controls.Add($ButtonWebURL)

    $ButtonWebURL.Add_Click({
        $SelectedResult = $Global:SearchResult | Where-Object id -eq $ListSearchResults.SelectedItems[0].Text
        if ($null -ne $ListSearchResults.SelectedItems[0]){
            
            Start-Process  $SelectedResult.websiteUrl
        }

    })
    
    #*** Button Install selected
    $ButtonInstallSearchSelect = New-Object System.Windows.Forms.Button
    $ButtonInstallSearchSelect.Location = New-Object System.Drawing.Size(255,415)
    $ButtonInstallSearchSelect.Size = New-Object System.Drawing.Size(235,40)
    $ButtonInstallSearchSelect.Text = "Install selected addons"
    $ButtonInstallSearchSelect.FlatStyle = "Popup"
    $ToolTipInstallSearchSelect = New-Object System.Windows.Forms.ToolTip
    $ToolTipInstallSearchSelect.SetToolTip($ButtonInstallSearchSelect,"Install all selected addons.") 
    $ButtonInstallSearchSelect.BackColor = $StandardButtonColor
    $ButtonInstallSearchSelect.ForeColor = $StandardButtonTextColor
    $ButtonInstallSearchSelect.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 7, [System.Drawing.FontStyle]::Bold)
    $Search_form.Controls.Add($ButtonInstallSearchSelect)

    $ButtonInstallSearchSelect.Add_Click({
        $Search_form.Visible = $false
        $main_form.Topmost = $true
        $LoadSpinner.Visible = $true
        foreach ($record in $ListSearchResults.SelectedItems) {

            if ($null -ne ($Addons.config.Addon | Where-Object ID -EQ $record.Text).length) {
                
                $LoadSpinner.Text = "Installing

" + $record.SubItems[1].text
                $LoadSpinner.Update()
                NewAddon -ID $record.Text -ImportOnly $false
                
            }    

        }
        UpdateAddonsTable
        $LoadSpinner.Visible = $false
        $main_form.Topmost = $false

    })

    #*** Label Description text
    $LabelSearchDescriptionText = New-Object System.Windows.Forms.Label
    $LabelSearchDescriptionText.Location  = New-Object System.Drawing.Point(190,510)
    $LabelSearchDescriptionText.Size = New-Object System.Drawing.Size(300,180)
    $LabelSearchDescriptionText.TextAlign = "TopLeft"
    $LabelSearchDescriptionText.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $LabelSearchDescriptionText.BackColor = [System.Drawing.Color]::Black
    $LabelSearchDescriptionText.ForeColor = [System.Drawing.Color]::LightGray
    $LabelSearchDescriptionText.Padding = 5
    $LabelSearchDescriptionText.Font = [System.Drawing.Font]::new($Addons.config.DetailFont, 10, [System.Drawing.FontStyle]::Bold)
    $Search_form.Controls.Add($LabelSearchDescriptionText)

    #*** Main Form ******************************************************************************************************
    $main_form = New-Object System.Windows.Forms.Form
    $main_form.Text ="SMOSK - Classic Addon Manager"
    $main_form.minimumSize = New-Object System.Drawing.Size(985,800) 
    $main_form.maximumSize = New-Object System.Drawing.Size(985,800) 
    $main_form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen 
    $main_form.AutoSize = $false
    $main_form.FormBorderStyle = "None"
    $main_form.BackgroundImageLayout = "Zoom"
    $main_form.BackColor = [System.Drawing.Color]::Black
    $main_form.SizeGripStyle = "Hide"
    $main_form.BackgroundImage = [system.drawing.image]::FromFile($Addons.config.Wallpaper)
    
    $LabelMoveMainForm = New-Object System.Windows.Forms.Label
    $LabelMoveMainForm.Name = "LabelMoveMainForm"
    $LabelMoveMainForm.BackColor = [System.Drawing.Color]::Transparent
    $LabelMoveMainForm.Location = New-Object System.Drawing.Point(0, 0)
    $LabelMoveMainForm.Size = New-Object System.Drawing.Size(985, 30)
    $LabelMoveMainForm.Anchor = "Top","Left"
    $LabelMoveMainForm.BorderStyle = "None"
    $LabelMoveMainForm.Text = "SMOSK - Classic Addon Manager"
    $LabelMoveMainForm.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 12, [System.Drawing.FontStyle]::Bold)
    $LabelMoveMainForm.ForeColor = [System.Drawing.Color]::White
    $LabelMoveMainForm.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    
    $LabelMoveMainForm.Add_MouseDown( { 
        $global:dragging = $true
        $global:mouseDragX = [System.Windows.Forms.Cursor]::Position.X - $main_form.Left
        $global:mouseDragY = [System.Windows.Forms.Cursor]::Position.Y - $main_form.Top
    })
   
    $LabelMoveMainForm.Add_MouseMove( { 
        if($global:dragging) {
           
            $currentX = [System.Windows.Forms.Cursor]::Position.X
            $currentY = [System.Windows.Forms.Cursor]::Position.Y
            [int]$newX = [Math]::Min($currentX - $global:mouseDragX, $workareaWidth - $main_form.Width)
            [int]$newY = [Math]::Min($currentY - $global:mouseDragY, $workareaHeight - $main_form.Height)
            $main_form.Location = New-Object System.Drawing.Point($newX, $newY)
        }
    })
    
    $LabelMoveMainForm.Add_MouseUp( { 
        $global:dragging = $false 
    })

    $ButtonCloseMainForm = New-Object System.Windows.Forms.Button
    $ButtonCloseMainForm.Name = "ButtonCloseMainForm"
    $ButtonCloseMainForm.Anchor = "Top","Left"
    $ButtonCloseMainForm.Location = New-Object System.Drawing.Point(960, 5)
    $ButtonCloseMainForm.Size = New-Object System.Drawing.Size(20, 20)
    $ButtonCloseMainForm.TextAlign = "BottomCenter"
    $ButtonCloseMainForm.FlatStyle = "PopUp"
    $ButtonCloseMainForm.UseVisualStyleBackColor = $true
    $ButtonCloseMainForm.ForeColor = [System.Drawing.Color]::White
    $ButtonCloseMainForm.BackColor = [System.Drawing.Color]::Black
    $ButtonCloseMainForm.UseMnemonic = $true
    $ButtonCloseMainForm.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\close.png")
    $ButtonCloseMainForm.BackgroundImageLayout = "Zoom"
    $ButtonCloseMainForm.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $ButtonMinimizeMainForm = New-Object System.Windows.Forms.Button
    $ButtonMinimizeMainForm.Name = "ButtonCloseMainForm"
    $ButtonMinimizeMainForm.Anchor = "Top","Left"
    $ButtonMinimizeMainForm.Location = New-Object System.Drawing.Point(930, 5)
    $ButtonMinimizeMainForm.Size = New-Object System.Drawing.Size(20, 20)
    $ButtonMinimizeMainForm.FlatStyle = "PopUp"
    $ButtonMinimizeMainForm.UseVisualStyleBackColor = $true
    $ButtonMinimizeMainForm.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\minimize.png")
    $ButtonMinimizeMainForm.BackgroundImageLayout = "Zoom"
    $ButtonMinimizeMainForm.ForeColor = [System.Drawing.Color]::White
    $ButtonMinimizeMainForm.BackColor = [System.Drawing.Color]::Black

    $ButtonMinimizeMainForm.Add_Click({
        $main_form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
    })

    $ButtonHelpMainForm = New-Object System.Windows.Forms.Button
    $ButtonHelpMainForm.Name = "ButtonCloseMainForm"
    $ButtonHelpMainForm.Anchor = "Top","Left"
    $ButtonHelpMainForm.Location = New-Object System.Drawing.Point(900, 5)
    $ButtonHelpMainForm.Size = New-Object System.Drawing.Size(20, 20)
    $ButtonHelpMainForm.FlatStyle = "PopUp"
    $ButtonHelpMainForm.UseVisualStyleBackColor = $true
    $ButtonHelpMainForm.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\help.png")
    $ButtonHelpMainForm.BackgroundImageLayout = "Zoom"
    $ButtonHelpMainForm.ForeColor = [System.Drawing.Color]::White
    $ButtonHelpMainForm.BackColor = [System.Drawing.Color]::Black

    
    $ButtonHelpMainForm.Add_Click({
        Start-Process ".\Resources\SMOSK_help.pdf"
    })

    $ButtonDiscord = New-Object System.Windows.Forms.Button
    $ButtonDiscord.Name = "ButtonDiscord"
    $ButtonDiscord.Anchor = "Top","Left"
    $ButtonDiscord.Location = New-Object System.Drawing.Point(800, 7)
    $ButtonDiscord.Size = New-Object System.Drawing.Size(90, 20)

    $ButtonDiscord.FlatStyle = "PopUp"
    
    $ButtonDiscord.UseVisualStyleBackColor = $true
    $ButtonDiscord.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\Discord.png")
    $ButtonDiscord.BackgroundImageLayout = "Zoom"
    $ButtonDiscord.ForeColor = [System.Drawing.Color]::White
    

    
    $ButtonDiscord.Add_Click({
        Start-Process "https://discord.gg/zK2x5XX"
    })

    $ButtonGit = New-Object System.Windows.Forms.Button
    $ButtonGit.Name = "ButtonDiscord"
    $ButtonGit.Anchor = "Top","Left"
    $ButtonGit.Location = New-Object System.Drawing.Point(780, 7)
    $ButtonGit.Size = New-Object System.Drawing.Size(20, 20)

    $ButtonGit.FlatStyle = "PopUp"
    
    $ButtonGit.UseVisualStyleBackColor = $true
    $ButtonGit.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\GitHub-Mark.png")
    $ButtonGit.BackgroundImageLayout = "Zoom"
    $ButtonGit.ForeColor = [System.Drawing.Color]::White
    

    
    $ButtonGit.Add_Click({
        Start-Process "https://github.com/joheri85/SmoskAddonManager"
    })


    #*** Button for changelog
    $ButtonChangelog = New-Object System.Windows.Forms.Button
    $ButtonChangelog.Name = "ButtonDiscord"
    $ButtonChangelog.Anchor = "Top","Left"
    $ButtonChangelog.Location = New-Object System.Drawing.Point(750, 7)
    $ButtonChangelog.Size = New-Object System.Drawing.Size(20, 20)
    $ButtonChangelog.FlatStyle = "PopUp"
    $ButtonChangelog.TextAlign = "MiddleCenter"
    $ButtonChangelog.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\log.png")
    $ButtonChangelog.BackgroundImageLayout = "Zoom"
    $ToolTipWebURL = New-Object System.Windows.Forms.ToolTip
    $ToolTipWebURL.SetToolTip($ButtonChangelog,"Click to show change log. Shift+Click to show recently updated addons") 
    $ButtonChangelog.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 8, [System.Drawing.FontStyle]::Bold)
    $ButtonChangelog.UseVisualStyleBackColor = $true

    $ButtonChangelog.BackColor = [System.Drawing.Color]::Black
    

    
    $ButtonChangelog.Add_Click({
       
            $VK_SHIFT = 0x10
            $ShiftIsDown =  (Get-KeyState($VK_SHIFT))        

            if ($ShiftIsDown){
                makeUpdateLog
                $LabelMovechangeForm.Text = "SMOSK - Update log"
                $Changelogbox.SelectionStart = 0
                $change_form.ShowDialog()
            } else {
                makeChangelog
                $LabelMovechangeForm.Text = "SMOSK - Change log"
                $Changelogbox.SelectionStart = 0
                $change_form.ShowDialog()
            }
        
        

    })



    $main_form.Controls.Add($LabelMoveMainForm)
    $main_form.Controls.Add($ButtonMinimizeMainForm)
    $main_form.Controls.Add($ButtonHelpMainForm)
    $main_form.Controls.Add($ButtonCloseMainForm)
    $main_form.Controls.Add($ButtonDiscord)
    $main_form.Controls.Add($ButtonGit)
    $main_form.Controls.Add($ButtonChangelog)
    $ButtonDiscord.BringToFront()
    $ButtonGit.BringToFront()
    $ButtonChangelog.BringToFront()
    $ButtonHelpMainForm.BringToFront()
    $ButtonMinimizeMainForm.BringToFront()
    $ButtonCloseMainForm.BringToFront()
   

    #*** Updating Status box
    $LoadSpinner = New-Object System.Windows.Forms.Label
    $LoadSpinner.Text = "Downloading and updating... 
(Window may appear unresponsive)"
    $LoadSpinner.Location  = New-Object System.Drawing.Point(370,140)
    $LoadSpinner.Size = New-Object System.Drawing.Size(250,100)
    $LoadSpinner.TextAlign = "MiddleCenter"
    $LoadSpinner.Anchor = "Bottom,Right"
    $LoadSpinner.BackColor = [System.Drawing.Color]::Black
    $LoadSpinner.ForeColor = [System.Drawing.Color]::White
    $LoadSpinner.BorderStyle = "Fixed3D"
    $LoadSpinner.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 10, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LoadSpinner)
    $LoadSpinner.BringToFront()

    #*** Label InstalledAddons
    $LabelInstalledAddons = New-Object System.Windows.Forms.Label

    if ($null -eq $Addons.config.Addon.Length) {
        $LabelInstalledAddons.Text = "1 addon installed"

    } else {
        $LabelInstalledAddons.Text = $Addons.config.Addon.Length.ToString() + " addons installed"
    }
    $LabelInstalledAddons.Location  = New-Object System.Drawing.Point(10,30)
    $LabelInstalledAddons.Size = New-Object System.Drawing.Size(500,30)
    $LabelInstalledAddons.TextAlign = "MiddleLeft"
    $LabelInstalledAddons.BackColor = [System.Drawing.Color]::Transparent
    $LabelInstalledAddons.ForeColor = [System.Drawing.Color]::White
    $LabelInstalledAddons.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 12, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelInstalledAddons)

    #*** Label LegendSelected Color
    $LabelSelectedColor = New-Object System.Windows.Forms.Label
    $LabelSelectedColor.Location  = New-Object System.Drawing.Point(710,45)
    $LabelSelectedColor.Size = New-Object System.Drawing.Size(10,10)
    $LabelSelectedColor.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0078d7")
    $LabelSelectedColor.BorderStyle = "FixedSingle"
    $LabelSelectedColor.Anchor = "Top,Right"
    $main_form.Controls.Add($LabelSelectedColor)

    #*** Label LegendSelected Text
    $LabelSelectedText = New-Object System.Windows.Forms.Label
    $LabelSelectedText.Text = "Selected"
    $LabelSelectedText.Location  = New-Object System.Drawing.Point(720,40)
    $LabelSelectedText.Size = New-Object System.Drawing.Size(60,20)
    $LabelSelectedText.TextAlign = "MiddleLeft"
    $LabelSelectedText.Anchor = "Top,Right"
    $LabelSelectedText.BackColor = [System.Drawing.Color]::Transparent
    $LabelSelectedText.ForeColor = [System.Drawing.Color]::White
    $LabelSelectedText.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelSelectedText)

    #*** Label LegendUpToDate Color
    $LabelUpToDateColor = New-Object System.Windows.Forms.Label
    $LabelUpToDateColor.Location  = New-Object System.Drawing.Point(790,45)
    $LabelUpToDateColor.Size = New-Object System.Drawing.Size(10,10)
    $LabelUpToDateColor.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#c7c7c7")
    $LabelUpToDateColor.BorderStyle = "FixedSingle"
    $LabelUpToDateColor.Anchor = "Top,Right"
    $main_form.Controls.Add($LabelUpToDateColor)

    #*** Label LegendUpToDate Text
    $LabelUpToDateText = New-Object System.Windows.Forms.Label
    $LabelUpToDateText.Text = "Up to date"
    $LabelUpToDateText.Location  = New-Object System.Drawing.Point(800,40)
    $LabelUpToDateText.Size = New-Object System.Drawing.Size(60,20)
    $LabelUpToDateText.TextAlign = "MiddleLeft"
    $LabelUpToDateText.Anchor = "Top,Right"
    $LabelUpToDateText.BackColor = [System.Drawing.Color]::Transparent
    $LabelUpToDateText.ForeColor = [System.Drawing.Color]::White
    $LabelUpToDateText.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelUpToDateText)

    #*** Label LegendUpdateAvailable Color
    $LabelUpdateAvailableText = New-Object System.Windows.Forms.Label
    $LabelUpdateAvailableText.Location  = New-Object System.Drawing.Point(870,45)
    $LabelUpdateAvailableText.Size = New-Object System.Drawing.Size(10,10)
    $LabelUpdateAvailableText.BackColor = [System.Drawing.Color]::Orange
    $LabelUpdateAvailableText.BorderStyle = "FixedSingle"
    $LabelUpdateAvailableText.Anchor = "Top,Right"
    $main_form.Controls.Add($LabelUpdateAvailableText)

    #*** Label LegendUpToDate Text
    $LabelUpdateAvailableColor = New-Object System.Windows.Forms.Label
    $LabelUpdateAvailableColor.Text = "Update available"
    $LabelUpdateAvailableColor.Location  = New-Object System.Drawing.Point(880,40)
    $LabelUpdateAvailableColor.Size = New-Object System.Drawing.Size(100,20)
    $LabelUpdateAvailableColor.TextAlign = "MiddleLeft"
    $LabelUpdateAvailableColor.Anchor = "Top,Right"
    $LabelUpdateAvailableColor.BackColor = [System.Drawing.Color]::Transparent
    $LabelUpdateAvailableColor.ForeColor = [System.Drawing.Color]::White
    $LabelUpdateAvailableColor.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelUpdateAvailableColor)

    #*** Addon List
    $ListViewBox = New-Object System.Windows.Forms.ListView
    $ListViewBox.Location = New-Object System.Drawing.Point(10,60)
    $ListViewBox.Size     = New-Object System.Drawing.Size(950,410)
    $ListViewBox.Anchor = 'Top, Bottom, Left, Right'
    $ListViewBox.View = 'Details'
    $ListViewBox.GridLines = $false
    $ListViewBox.HeaderStyle =  'Nonclickable'
    $ListViewBox.BackColor = [System.Drawing.Color]::Black
    $ListViewBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
    $ListViewBox.Font = [System.Drawing.Font]::new($Addons.config.DetailFont, 8, [System.Drawing.FontStyle]::Regular)
    $ListViewBox.FullRowSelect = $true
    $ListViewBox.MultiSelect = $true
    $ListViewBox.he
    
    
    

    
    $ListViewBox.Add_click({
        
    })

    $ListViewBox.Add_DoubleClick({
       
        Start-Process ($Addons.config.Addon | Where-Object ID -eq $ListViewBox.SelectedItems[0].Text).Website
    })


    $Main_form.Controls.Add($ListViewBox)

    #*** Button Refresh
    $ButtonRefresh = New-Object System.Windows.Forms.Button
    $ButtonRefresh.Location = New-Object System.Drawing.Size(860,480)
    $ButtonRefresh.Size = New-Object System.Drawing.Size(100,40)
    $ButtonRefresh.Text = "Refresh"
    $ButtonRefresh.Anchor = "Bottom,Right"
    $ButtonRefresh.FlatStyle = "Popup"
    $ToolTipRefresh = New-Object System.Windows.Forms.ToolTip
    $ToolTipRefresh.SetToolTip($ButtonRefresh,"Refreshes the list and fetching latest version info from CurseForge. ")
    $ButtonRefresh.BackColor = $StandardButtonColor
    $ButtonRefresh.ForeColor = $StandardButtonTextColor
    $ButtonRefresh.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($ButtonRefresh)

    $ButtonRefresh.Add_Click({
        $LoadSpinner.Text = "Refreshing...

Waiting for API response"
        $LoadSpinner.Visible = $true
        UpdateAddonsTable
        $LoadSpinner.Visible = $false

    })

    #*** Button Update selected
    $ButtonUpdateSelected = New-Object System.Windows.Forms.Button
    $ButtonUpdateSelected.Location = New-Object System.Drawing.Size(640,480)
    $ButtonUpdateSelected.Size = New-Object System.Drawing.Size(100,40)
    $ButtonUpdateSelected.Text = "Update selected"
    $ButtonUpdateSelected.Anchor = "Bottom,Right"
    $ButtonUpdateSelected.FlatStyle = "Popup"
    $ToolTipUpdateSelected = New-Object System.Windows.Forms.ToolTip
    $ToolTipUpdateSelected.SetToolTip($ButtonUpdateSelected,"Update all selected addons. Select more than one by holding shift or control.")
    $ButtonUpdateSelected.BackColor = $StandardButtonColor
    $ButtonUpdateSelected.ForeColor = $StandardButtonTextColor
    $ButtonUpdateSelected.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($ButtonUpdateSelected)

    $ButtonUpdateSelected.Add_Click({

        $LoadSpinner.Visible = $true
        Foreach ($record in $ListViewBox.SelectedItems) {
            $LoadSpinner.Text = "Updating...
            
" + ($addons.config.Addon | Where-Object ID -eq $record.text).name
            $LoadSpinner.Update()
            UpdateAddon -AddonID $record.text

        }

        UpdateAddonsTable
        $LoadSpinner.Visible = $false

    })

        #*** Button Update all
        $ButtonUpdateAll = New-Object System.Windows.Forms.Button
        $ButtonUpdateAll.Location = New-Object System.Drawing.Size(750,480)
        $ButtonUpdateAll.Size = New-Object System.Drawing.Size(100,40)
        $ButtonUpdateAll.Text = "Update all"
        $ButtonUpdateAll.FlatStyle = "Popup"
        $ButtonUpdateAll.Anchor = "Bottom,Right"
        $ToolTipUpdateAll = New-Object System.Windows.Forms.ToolTip
        $ToolTipUpdateAll.SetToolTip($ButtonUpdateAll,"Updates all addons that have a new version on CurseForge.")        
        $ButtonUpdateAll.BackColor = $StandardButtonColor
        $ButtonUpdateAll.ForeColor = [System.Drawing.Color]::White
        $ButtonUpdateAll.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 7, [System.Drawing.FontStyle]::Bold)
        $main_form.Controls.Add($ButtonUpdateAll)
    
        $ButtonUpdateAll.Add_Click({
    
            $LoadSpinner.Visible = $true
            foreach ($addon in $Addons.config.Addon) {
       
                if ($addon.CurrentVersion -ne $addon.LatestVersion) {
                    
                    $LoadSpinner.Text = "Updating... 
                    
" + $addon.Name
                    $LoadSpinner.Update()
                    UpdateAddon -AddonID $addon.ID
                }
    
            }
    
            UpdateAddonsTable
            $LoadSpinner.Visible = $false
    
        })

    #*** Button Open Search
    $ButtonOpenSearch = New-Object System.Windows.Forms.Button
    $ButtonOpenSearch.Location = New-Object System.Drawing.Size(10,480)
    $ButtonOpenSearch.Size = New-Object System.Drawing.Size(320,40)
    $ButtonOpenSearch.Text = "Install new addons"
    $ButtonOpenSearch.Anchor = "Bottom,Left"
    $ButtonOpenSearch.FlatStyle = "Popup"
    $ToolTipOpenSearch = New-Object System.Windows.Forms.ToolTip
    $ToolTipOpenSearch.SetToolTip($ButtonOpenSearch,"Search and install more addons from CurseForge.")  
    $ButtonOpenSearch.BackColor = $StandardButtonColor
    $ButtonOpenSearch.ForeColor = $StandardButtonTextColor
    $ButtonOpenSearch.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 12, [System.Drawing.FontStyle]::Bold)
    $ButtonOpenSearch.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\search.png")
    $ButtonOpenSearch.BackgroundImageLayout = "Zoom"
    $main_form.Controls.Add($ButtonOpenSearch)

    $ButtonOpenSearch.Add_Click({
        $Search_form.ShowDialog()

    })


    #*** ElvUI backdrop
    $LabelElvUIBG = New-Object System.Windows.Forms.Label
    $LabelElvUIBG.Location  = New-Object System.Drawing.Point(10,570)
    $LabelElvUIBG.Size = New-Object System.Drawing.Size(320,125)
    $LabelElvUIBG.BorderStyle = "Fixed3D"
    $LabelElvUIBG.BackColor = $StandardButtonColor
    $main_form.Controls.Add($LabelElvUIBG)

    #*** Label ElvUI
    $LabelElvUI = New-Object System.Windows.Forms.Label
    $LabelElvUI.Text = "ElvUI"
    $LabelElvUI.Location  = New-Object System.Drawing.Point(20,575)
    $LabelElvUI.Size = New-Object System.Drawing.Size(300,25)
    $LabelElvUI.TextAlign = "MiddleCenter"
    $LabelElvUI.BorderStyle = "none"
    $LabelElvUI.BackColor = $StandardButtonColor
    $LabelElvUI.ForeColor = [System.Drawing.Color]::Orange
    $LabelElvUI.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 12, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelElvUI)
    $LabelElvUI.BringToFront()

    #*** ElvUi list
    $ElvUIViewBox = New-Object System.Windows.Forms.ListView
    $ElvUIViewBox.Location = New-Object System.Drawing.Point(20,600)
    $ElvUIViewBox.Size = New-Object System.Drawing.Size(300,51)
    $ElvUIViewBox.View = 'Details'
    $ElvUIViewBox.GridLines = $false
    $ElvUIViewBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
    $ElvUIViewBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
    $ElvUIViewBox.Font = [System.Drawing.Font]::new($Addons.config.DetailFont, 8, [System.Drawing.FontStyle]::Regular)
    $ElvUIViewBox.FullRowSelect = $true
    $ElvUIViewBox.MultiSelect = $true

    
    $ElvUIViewBox.Add_click({
        
    })

    $ElvUIViewBox.Add_DoubleClick({
        Start-Process "https://www.tukui.org/classic-addons.php?id=2"
    })

    $Main_form.Controls.Add($ElvUIViewBox)
    $ElvUIViewBox.BringToFront()

    #*** Button ElvUI
    $ButtonElvUI = New-Object System.Windows.Forms.Button
    $ButtonElvUI.Location = New-Object System.Drawing.Size(19,651)
    $ButtonElvUI.Size = New-Object System.Drawing.Size(302,30)
    $ButtonElvUI.FlatStyle = "Popup"
    $ButtonElvUI.ForeColor = $StandardButtonTextColor
    $ButtonElvUI.BackColor = $StandardButtonColor
    $ButtonElvUI.Font = [System.Drawing.Font]::new($Addons.config.DetailFont, 8, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($ButtonElvUI)
    $ButtonElvUI.BringToFront()

    $ButtonElvUI.Add_Click({
        if (Test-Path ($Addons.config.IfaceAddonsFolder + "\ElvUI")) {
            $ButtonElvUI.Text = "Updating..."
            InstallElvUI
        } else {
            $ButtonElvUI.Text = "Installing..."
            InstallElvUI
        }
        UpdateAddonsTable
        
    })

    #*** Label Battleground
    $LabelBattleground = New-Object System.Windows.Forms.Label
    $LabelBattleground.Location  = New-Object System.Drawing.Point(340,520)
    $LabelBattleground.Size = New-Object System.Drawing.Size(200,130)
    $LabelBattleground.TextAlign = "MiddleCenter"
    $LabelBattleground.BorderStyle = "Fixed3D"
    $LabelBattleground.BackColor = $StandardButtonColor
    $LabelBattleground.ForeColor = [System.Drawing.Color]::White
    $LabelBattleground.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 8, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelBattleground)

    #*** Label Battleground
    $LabelBattlegroundInternal = New-Object System.Windows.Forms.Label
    $LabelBattlegroundInternal.Location  = New-Object System.Drawing.Point(350,555)
    $LabelBattlegroundInternal.Size = New-Object System.Drawing.Size(180,30)
    $LabelBattlegroundInternal.TextAlign = "MiddleCenter"
    $LabelBattlegroundInternal.BorderStyle = "None"
    $LabelBattlegroundInternal.BackColor = $StandardButtonColor
    $LabelBattlegroundInternal.ForeColor = [System.Drawing.Color]::Orange
    $LabelBattlegroundInternal.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 10, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelBattlegroundInternal)
    $LabelBattlegroundInternal.BringToFront()

    #*** Label Darkmoon Faire
    $LabelDarkmoon = New-Object System.Windows.Forms.Label
    $LabelDarkmoon.Location  = New-Object System.Drawing.Point(340,660)
    $LabelDarkmoon.Size = New-Object System.Drawing.Size(200,133)
    $LabelDarkmoon.TextAlign = "MiddleCenter"
    $LabelDarkmoon.BorderStyle = "Fixed3D"
    $LabelDarkmoon.BackColor = $StandardButtonColor
    $LabelDarkmoon.ForeColor = [System.Drawing.Color]::White
    $LabelDarkmoon.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 8, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelDarkmoon)


    $LabelDarkmoonInternal = New-Object System.Windows.Forms.Label
    $LabelDarkmoonInternal.Location  = New-Object System.Drawing.Point(350,710)
    $LabelDarkmoonInternal.Size = New-Object System.Drawing.Size(180,30)
    $LabelDarkmoonInternal.TextAlign = "MiddleCenter"
    $LabelDarkmoonInternal.BorderStyle = "None"
    $LabelDarkmoonInternal.BackColor = $StandardButtonColor
    $LabelDarkmoonInternal.ForeColor = [System.Drawing.Color]::Orange
    $LabelDarkmoonInternal.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 10, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelDarkmoonInternal)
    $LabelDarkmoonInternal.BringToFront()

    #*** Button Import Current addons
    $ButtonImport = New-Object System.Windows.Forms.Button
    $ButtonImport.Location = New-Object System.Drawing.Size(10,755)
    $ButtonImport.Size = New-Object System.Drawing.Size(320,25)
    $ButtonImport.Text = "Import installed addons"
    $ButtonImport.FlatStyle = "Popup"
    #$ButtonImport.Anchor = "Bottom,Left"
    $ToolTipImport = New-Object System.Windows.Forms.ToolTip
    $ToolTipImport.SetToolTip($ButtonImport,"Searches through your addons folder and matching existing addons with possible matches on CurseForge and adds them to the list") 
    $ButtonImport.ForeColor = $StandardButtonTextColor
    $ButtonImport.BackColor = $StandardButtonColor
    $ButtonImport.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($ButtonImport)

    $ButtonImport.Add_Click({
        $SubPath = [regex]::escape("\Interface\AddOns")
        if ($Addons.config.IfaceAddonsFolder -match $SubPath) {
            $LoadSpinner.Text = "Importing your current addons. This can take some time depending on how many addons are installed"
            $LoadSpinner.Update()
            $LoadSpinner.Visible = $true
            ImportCurrentAddons
            UpdateAddonsTable
            $LoadSpinner.Visible = $false
        } else {
            $Loadspinner.Text = "Select your \Interface\Addons folder before importing"
            $LoadSpinner.Update()
            $LoadSpinner.Visible = $true
        }
    })

    #*** Label Version
    $ButtonVersion = New-Object System.Windows.Forms.Button
    $ButtonVersion.Text = "v " + $Version
    $ButtonVersion.Location  = New-Object System.Drawing.Point(3,3)
    $ButtonVersion.Size = New-Object System.Drawing.Size(80,23)
    $ButtonVersion.TextAlign = "BottomLeft"
    $ToolTipButtonVersion = New-Object System.Windows.Forms.ToolTip
    $ButtonVersion.BackColor = [System.Drawing.Color]::Black
    $ButtonVersion.ForeColor = [System.Drawing.Color]::LightGray
    if ($version -eq $SMOSKVersion.smosk.version) {
        $ButtonVersion.BackgroundImage = [System.Drawing.Image]::FromFile(".\Resources\update_ok.png")
    } else {
        $ButtonVersion.BackgroundImage = [System.Drawing.Image]::FromFile(".\Resources\update.png")
    }

    $ButtonVersion.BackgroundImageLayout = "Zoom"
    $ButtonVersion.FlatStyle = "Popup"
    $ButtonVersion.Font = [System.Drawing.Font]::new($Addons.config.DetailFont, 8, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($ButtonVersion)
    $ButtonVersion.BringToFront()

    $ButtonVersion.add_Click(
        {
            $VK_SHIFT = 0x10
            $ShiftIsDown =  (Get-KeyState($VK_SHIFT))        

            if ($ShiftIsDown){
                Start-Process notepad ".\Resources\Save.xml"
            } else {
                Start-Process ".\Update_SMOSK.exe"
            }

        }
    )   

    #*** Label Version
    $LabelCreator = New-Object System.Windows.Forms.Label
    $LabelCreator.Text = "Created and maintained by Lyanda@NetherGarde-Keep EU"
    $LabelCreator.Location  = New-Object System.Drawing.Point(10,740)
    $LabelCreator.Size = New-Object System.Drawing.Size(320,20)
    $LabelCreator.TextAlign = "MiddleCenter"
    $LabelCreator.Anchor = "Bottom,Left"
    $LabelCreator.BackColor = [System.Drawing.Color]::Transparent
    $LabelCreator.ForeColor = [System.Drawing.Color]::LightGray
    $LabelCreator.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelCreator)

    #*** Button Delete Addons
    $ButtonDeleteAddon = New-Object System.Windows.Forms.Button
    $ButtonDeleteAddon.Location = New-Object System.Drawing.Size(530,480)
    $ButtonDeleteAddon.Size = New-Object System.Drawing.Size(100,40)
    $ButtonDeleteAddon.Text = "Delete selected"
    $ButtonDeleteAddon.FlatStyle = "Popup"
    $ButtonDeleteAddon.Anchor = "Bottom,Right"
    $ToolTipDeleteAddon = New-Object System.Windows.Forms.ToolTip
    $ToolTipDeleteAddon.SetToolTip($ButtonDeleteAddon,"Delete all selected addons from the list and removing the files in your addons folder") 
    $ButtonDeleteAddon.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#e48330")
    $ButtonDeleteAddon.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#212121")
    $ButtonDeleteAddon.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($ButtonDeleteAddon)

    $ButtonDeleteAddon.Add_Click({
       

        Foreach ($record in $ListViewBox.SelectedItems) {
            
            DeleteAddon -ID $record.text
            $ListViewBox.Items.Remove($record)
            
        }

        if ($null -ne $Addons.config.Addon.Length) {
            $LabelInstalledAddons.Text = $Addons.config.Addon.Length.ToString() + " Addons installed"
        } else {
            $LabelInstalledAddons.Text = "1 Addon installed"
        }
       
    })



    #*** Label buffplaning header
    $LabelBuffsHeader = New-Object System.Windows.Forms.ComboBox
    $LabelBuffsHeader.Location  = New-Object System.Drawing.Point(550,570)
    $LabelBuffsHeader.items.AddRange(((Get-ChildItem -LiteralPath ".\BuffSchedules").Name.Trim(".xml")))
    $LabelBuffsHeader.Size = New-Object System.Drawing.Size(425,30)
    if ($null -ne $Addons.config.BuffplanningDefault ) {
        $LabelBuffsHeader.Text = $Addons.config.BuffplanningDefault.Trim(".xml")
    } else {
        $LabelBuffsHeader.Text = "Nethergarde Keep"
    }
    $LabelBuffsHeader.DropDownStyle = "DropDownList"
    $LabelBuffsHeader.BackColor = [System.Drawing.Color]::Black
    $LabelBuffsHeader.ForeColor = [System.Drawing.Color]::White
    $LabelBuffsHeader.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 10, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelBuffsHeader)

    $LabelBuffsHeader.Add_SelectedIndexChanged({

        
        if ($null -eq $Addons.config.BuffplanningDefault) {
            $node = $Addons.SelectSingleNode("config")
            $newNode = $Addons.CreateNode("element", "BuffplanningDefault", $null)
            $node.AppendChild($newNode)
 
        } 
        
        $Addons.config.BuffplanningDefault = $LabelBuffsHeader.SelectedItem.ToString()
        $Addons.Save($XMLPath)
        
        
        Buffplaning
        

    })




    #*** Buffplaning list
    $BuffViewBox = New-Object System.Windows.Forms.ListView
    $BuffViewBox.Location = New-Object System.Drawing.Point(550,600)
    $BuffViewBox.Size = New-Object System.Drawing.Size(425,100)
    $BuffViewBox.View = 'Details'
    $BuffViewBox.GridLines = $false
    $BuffViewBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
    $BuffViewBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $BuffViewBox.Font = [System.Drawing.Font]::new($Addons.config.DetailFont, 8, [System.Drawing.FontStyle]::Regular)
    $BuffViewBox.FullRowSelect = $true
    $BuffViewBox.MultiSelect = $true

    
    $BuffViewBox.Add_click({
        
    })

    $BuffViewBox.Add_DoubleClick({
        if ($LabelBuffsHeader.Selecteditem.ToString() -eq "Nethergarde Keep") {
            Start-Process "https://docs.google.com/spreadsheets/d/1YZbvGiUlRzVGYWwSTU7JeYoHtDUZW6JnXoqA1WEim84/htmlview?usp=sharing&pru=AAABc6XNR3U*ofU_hgCnK_odzu3J7DewXA"
        }
    })

    $Main_form.Controls.Add($BuffViewBox)


    #*** Reset list
    $ResetViewBox = New-Object System.Windows.Forms.ListView
    $ResetViewBox.Location = New-Object System.Drawing.Point(550,705)
    $ResetViewBox.Size = New-Object System.Drawing.Size(425,88)
    $ResetViewBox.View = 'Details'
    $ResetViewBox.GridLines = $false
    $ResetViewBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
    $ResetViewBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
    $ResetViewBox.Font = [System.Drawing.Font]::new($Addons.config.DetailFont, 8, [System.Drawing.FontStyle]::Regular)
    $ResetViewBox.FullRowSelect = $true
    $ResetViewBox.MultiSelect = $true

    
    $ResetViewBox.Add_click({
        
    })

    $ResetViewBox.Add_DoubleClick({
        
    })

    $Main_form.Controls.Add($ResetViewBox)



    #*** Label IfaceAddons
    $LabelIfaceAddons = New-Object System.Windows.Forms.Label
    $LabelIfaceAddons.Text = "WoW Classic addons path"
    $LabelIfaceAddons.Location  = New-Object System.Drawing.Point(10,700)
    $LabelIfaceAddons.Size = New-Object System.Drawing.Size(320,20)
    $LabelIfaceAddons.TextAlign = "MiddleCenter"
    $LabelIfaceAddons.BackColor = [System.Drawing.Color]::Transparent
    $LabelIfaceAddons.ForeColor = [System.Drawing.Color]::White
    $LabelIfaceAddons.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 9, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelIfaceAddons)

    #*** Button IfaceAddonsPatch 
    $ButtonIfaceAddonsPath = New-Object System.Windows.Forms.Button
    $ButtonIfaceAddonsPath.Location = New-Object System.Drawing.Size(10,720)
    $ButtonIfaceAddonsPath.Size = New-Object System.Drawing.Size(320,30)
    $ButtonIfaceAddonsPath.Text = $Addons.config.IfaceAddonsFolder
    $ButtonIfaceAddonsPath.FlatStyle = "Popup"
    $ButtonIfaceAddonsPath.BackColor = $StandardButtonColor
    $ButtonIfaceAddonsPath.ForeColor = $StandardButtonTextColor
    $ButtonIfaceAddonsPath.Font = [System.Drawing.Font]::new($Addons.config.HighlightFont, 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($ButtonIfaceAddonsPath)

    $ButtonIfaceAddonsPath.Add_Click({
    
        SetIfaceAddonsFolder

    })

    UpdateAddonsTable
    $LoadSpinner.Visible = $false
    $SplashScreen.Dispose()
    $ListViewBox.TabIndex = 0
    $main_form.ShowDialog()


    $main_form.Dispose()
    $Search_form.Dispose()
    $SplashScreen.Dispose()
    $change_form.Dispose()
    
}

# Checks for available updates from curseforge and refreshes the addon listview
Function UpdateAddonsTable {

    $SMOSKVersion.Load($SMOSKVersionPath)
    
    $ButtonRefresh.Text = ""
    $ButtonRefresh.BackgroundImage = [System.Drawing.Image]::FromFile(".\Resources\updating.png")
    $ButtonRefresh.BackgroundImageLayout = "Zoom"
    $ListViewBox.BeginUpdate()
    $ResetViewBox.BeginUpdate()
    $ElvUIViewBox.BeginUpdate()
    $BuffViewBox.BeginUpdate()
    

    #*** BG Schedules
    $now = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date), 'Central European Standard Time') 

    $WSGStart = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date -Date "2020-06-05"), 'Central European Standard Time') 
    While ($WSGStart -lt $now) {
        $WSGEnd = $WSGStart + (New-TimeSpan -Days 4)
        if (($now -lt $WSGEnd) -and ($now -gt $WSGStart)) {
            Break
        } else {
            $WSGStart += (New-TimeSpan -Days 28)
        }
    }

    $ABStart = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date -Date "2020-06-12"), 'Central European Standard Time') 
    While ($ABStart -lt $now) {
        $ABEnd = $ABStart + (New-TimeSpan -Days 4)
        if (($now -lt $ABEnd) -and ($now -gt $ABStart)) {
            Break
        } else {
            $ABStart += (New-TimeSpan -Days 28)
        }
    }

    $AVStart = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date -Date "2020-06-26"), 'Central European Standard Time') 
    While ($AVStart -lt $now) {
        $AVEnd = $AVStart + (New-TimeSpan -Days 4)
        if (($now -lt $AVEnd) -and ($now -gt $AVStart)) {
            Break
        } else {
            $AVStart += (New-TimeSpan -Days 28)
        }
    }
     
    $WSGEnd = $WSGStart + (New-TimeSpan -Days 4)
    $ABEnd  = $ABStart + (New-TimeSpan -Days 4)
    $AVEnd = $AVStart + (New-TimeSpan -Days 4)

    $BGS = (@(@("Warsong Gulch", $WSGStart,$WSGEnd), @("Arathi Basin" ,$ABStart,$ABEnd), @("Alterac Valey", $AVStart, $AVEnd)))  | sort-object @{Expression={$_[1]}}
 
    IF (($now -ge $BGS[0][1]) -and ($now -le $BGS[0][2]) ) {
        
        $LabelBattleground.Text = ("BG weekend is Active 
                


ends on 

" + ($BGS[0][2]).ToString("dddd yyyy-MM-dd"))
                $LabelBattlegroundInternal.Text = $BGS[0][0]

    }else{

        $LabelBattleground.Text = ("Next BG weekend is 
        


starts on 

" + ($BGS[0][1]).ToString("dddd yyyy-MM-dd") )
        $LabelBattlegroundInternal.Text = $BGS[0][0]
    }


    #*** Darkmoon fair
    [datetime]$DayOfMonth = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date -Date (Get-date -Format "yyyy-MM-01")), 'Central European Standard Time')
    $CurrentDay  = $DayOfMonth.ToString("dddd")
    $Friday = (get-date -Date "2020-08-14").ToString("dddd")
    $CurrentMonth = [int]$DayOfMonth.ToString("MM")
    if ($CurrentMonth % 2 -eq 0){
        $DarkmoonLocation = "Mulgore"
    } else {
        $DarkmoonLocation = "Elwynn Forest"
    }
    


    While ($CurrentDay -ne $Friday) {
        

        $DayOfMonth += (New-TimeSpan -Days 1)
        $CurrentDay  = $DayOfMonth.ToString("dddd") 
    }
    [datetime]$DarkMoonStart = $DayOfMonth + (New-TimeSpan -Days 3)
    [datetime]$DarkMoonEnd = $DarkMoonStart + (New-TimeSpan -Days 6)
    [datetime]$now = get-date -Format "yyyy-MM-dd"

  
    if (($now -ge $DarkMoonStart) -and ($now -le $DarkMoonEnd)) {
        

        $LabelDarkmoon.Text = ("Darkmoon Faire 
is active in 




and ends on " + $DarkMoonEnd.ToString("dddd"))
        $LabelDarkmoonInternal.Text = $DarkmoonLocation
    } elseif ($now -lt $DarkMoonStart) {
        $LabelDarkmoon.Text = ("Darkmoon Faire 
arrives in
          

                
        and will open on 
        " + $DarkMoonStart.ToString("dddd (yyyy-MM-dd)"))
        
        $LabelDarkmoonInternal.Text = $DarkmoonLocation 
    } elseif ($now -gt $DarkMoonEnd) {


        [datetime]$DayOfMonth = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date -Date (Get-date -Format "yyyy-MM-01")), 'Central European Standard Time')
        $DayOfMonth += (New-TimeSpan -Days ([datetime]::DaysInMonth([int]$DayOfMonth.ToString("yyyy"), [int]$DayOfMonth.ToString("MM") )))
        $CurrentDay  = $DayOfMonth.ToString("dddd")
        $Friday = (get-date -Date "2020-08-14").ToString("dddd")
        $CurrentMonth = [int]$DayOfMonth.ToString("MM")
        if ($CurrentMonth % 2 -eq 0){
            $DarkmoonLocation = "Mulgore"
        } else {
            $DarkmoonLocation = "Elwynn Forest"
        }
        


        While ($CurrentDay -ne $Friday) {
            

            $DayOfMonth += (New-TimeSpan -Days 1)
            $CurrentDay  = $DayOfMonth.ToString("dddd") 
        }
        [datetime]$DarkMoonStart = $DayOfMonth + (New-TimeSpan -Days 3)
        [datetime]$DarkMoonEnd = $DarkMoonStart + (New-TimeSpan -Days 6)
        [datetime]$now = get-date -Format "yyyy-MM-dd"

        
        $LabelDarkmoon.Text = ("Darkmoon Faire 
have departed for
        

        
and will open on 
" + $DarkMoonStart.ToString("dddd (yyyy-MM-dd)"))
        
        $LabelDarkmoonInternal.Text = $DarkmoonLocation 


    }

    $LabelDarkmoon.Update()

    #*** BuffTimers Europe

    Try {
        $ZGReset = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date -Date "2020-08-11 09:00"), 'Central European Standard Time')
        $MCBWLAQ40Reset = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date -Date "2020-08-12 09:00"), 'Central European Standard Time')
        $OnyxiaReset = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date -Date "2020-08-11 09:00"), 'Central European Standard Time')
    } catch {
        $ZGReset = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date -Date "2020-08-11 09.00"), 'Central European Standard Time')
        $MCBWLAQ40Reset = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date -Date "2020-08-12 09.00"), 'Central European Standard Time')
        $OnyxiaReset = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date -Date "2020-08-11 09.00"), 'Central European Standard Time')
    }
    
    $now = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date), 'Central European Standard Time') 

    
    #*** ZG
    while ($ZGReset -lt $now) {
        $ZGReset += New-TimeSpan -Days 3
    }

    #*** MC/BWL/AQ40  
    while ($MCBWLAQ40Reset -lt $now) {
        $MCBWLAQ40Reset += New-TimeSpan -Days 7
    }

    #*** Onyxia
    while ($OnyxiaReset -lt $now) {
        $OnyxiaReset += New-TimeSpan -Days 5
    }

    $Resets = @(("AQ20_ZG",$ZGReset),("AQ40_BWL_MC",$MCBWLAQ40Reset),("Onyxia",$OnyxiaReset)) | sort-object @{Expression={$_[1]}}


    $ResetViewBox.Clear()
    $ResetViewBox.Columns.Add("Instance")
    $ResetViewBox.Columns.Add("Next reset")
    $ResetViewBox.Columns.Add("Date")
    $ResetViewBox.Columns[0].Width = 150
    $ResetViewBox.Columns[1].Width = 150
    $ResetViewBox.Columns[2].Width = -2

    $i=0
    While ($i -lt 3) {

        $ResetViewBox_Item = New-Object System.Windows.Forms.ListViewItem($Resets[$i][0])
        $ResetViewBox_Item.SubItems.Add(($Resets[$i][1]).ToString("dddd"))
        $ResetViewBox_Item.SubItems.Add(($Resets[$i][1]).ToString("yyyy-MM-dd HH:mm"))
        if ($i % 2 -eq 0) {
            $ResetViewBox_Item.BackColor = [System.Drawing.Color]::Black
        } else {
            $ResetViewBox_Item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#272727")
        }
        
        $ResetViewBox_Item.ForeColor = [System.Drawing.Color]::Snow
        $ResetViewBox.Items.AddRange($ResetViewBox_Item)
        $i++
    }




    #*** Version
    if ($version -eq $SMOSKVersion.smosk.changelog.logentry[0].version) {
        $ButtonVersion.BackgroundImage = [System.Drawing.Image]::FromFile(".\Resources\update_ok.png")
        $ToolTipButtonVersion.SetToolTip($ButtonVersion,"SMOSK! is up to date")
        $ButtonVersion.Text = "v " + $Version
    } else {
        $ButtonVersion.BackgroundImage = [System.Drawing.Image]::FromFile(".\Resources\update.png")
        $ToolTipButtonVersion.SetToolTip($ButtonVersion,"Update available!")
        $ButtonVersion.Text = "v " + $Version
    }

    
    
    if($LabelBuffsHeader.SelectedItem -eq "Nethergarde Keep.xml") {
        NethergardeKeepBuffSchedule
    }
    BuffPlaning

   


    

    if ($null -ne $Addons.config.Addon ) {

        $Addons.Load($XMLPath)
        $LoadSpinner.Update()
        $ListViewBox.Clear()
        $ListViewBox.Columns.Add("PID")
        $ListViewBox.Columns.Add("Name")
        $ListViewBox.Columns.Add("Version")
        $ListViewBox.Columns.Add("LatestVersion")
        $ListViewBox.Columns.Add("Description")

        
        $AddonRemovedFromProject = @()

        if ($null -eq $Addons.config.Addon.Length) {
            
            $nrAddons = 1

        } else {
            $nrAddons = $Addons.config.Addon.Length

        }
        
        $i = 0; # Odd/Even index determines Background color on rows
        $si = 0; # Subindex keeping trak on where to insert item that has an update available

        #*** Getting properties for all installed addons and sorting them by name *********
        $BuildBody = @()
        foreach ($addon in ($Addons.config.addon | Sort-Object Name)) {
            $BuildBody += $addon.id
        }


        $MethodError = $true
        while ($MethodError) {
            
            Try {
                if ($BuildBody.Length -gt 1) {

                    $body = $BuildBody | ConvertTo-Json
                    
                    $response = (Invoke-RestMethod -uri "https://addons-ecs.forgesvc.net/api/v2/addon" -Body $body -Method Post -ContentType "application/json" -TimeoutSec 5) | Sort-Object Name
                } else {
                    
                    $response = Invoke-RestMethod -uri ("https://addons-ecs.forgesvc.net/api/v2/addon/" + $body ) -TimeoutSec 5
                    
                }
                $MethodError = $false

            } catch {
                if (Test-Path ".\Resources\error_log.txt") {
                    "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\error_log.txt" -Append
                    $_ | Out-File ".\Resources\error_log.txt" -Append
                } else {
                    "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\error_log.txt"
                    $_ | Out-File ".\Resources\error_log.txt" -Append
        
                }
            }
        }

        #****************************************************************************
        
        Foreach ($record in $response) {
            $numberDone = ([int]($i+1) + [int]$si)
            $LoadSpinner.Text = "Refreshing 
            
" + $record.name + "

" + $numberDone + " / " + $nrAddons
            $LoadSpinner.Update()
            
            $LabelSplashStatus.Text = $numberDone.ToString() + " / " + $nrAddons + "

" + $record.name
            


            $subnode = ($Addons.config.Addon | Where-Object ID -eq $record.id)
            if ($null -eq $subnode.Website) {

                $child = $Addons.CreateElement("Website")
                
                $subnode.AppendChild($child)

                $subnode.Website = $record.websiteUrl
            }

        

            
            $LabelSplashStatus.Update()
            $LoadSpinner.Update()
            

            $ListView_Item = New-Object System.Windows.Forms.ListViewItem($record.ID)
            $ListView_Item.SubItems.Add($record.Name)

            $currentVersion = ($Addons.config.Addon | Where-Object ID -eq $record.id).CurrentVersion
            $latestVersion = ($Addons.config.Addon | Where-Object ID -eq $record.id).LatestVersion

            
            if ($currentVersion -match "\d") {

                $temp =  ($currentVersion -replace "[a-z,A-Z,-]" , "" -replace " ", "" -replace "_","" -replace [regex]::Escape("[]"),"" -replace [regex]::Escape("()"),"").Trim(".")

                $ListView_Item.SubItems.Add($temp)

            } elseif ($currentVersion -ne "Imported, Update to display version.") {

                $ListView_Item.SubItems.Add("Not specified")

            } else {

                $ListView_Item.SubItems.Add("Imported, Update to display version.")
            }
            
            

            $AddonInfo = $record | 
                Select-Object -ExpandProperty LatestFiles |
                    Where-Object {
                        ($_.GameVersionFlavor -eq "wow_classic") -and ($_.ReleaseType -eq "1") 
                    }
            
            if ($null -eq $AddonInfo) {
                $AddonRemovedFromProject += $subnode.Name
                DeleteAddon -ID $record.ID
                Continue
            }

            if ($null -ne $AddonInfo) {
                $AddonInfo = $AddonInfo[0]

            }

            ($Addons.config.addon | Where-Object ID -EQ $Record.ID).LatestVersion = $AddonInfo.displayName 

           


            if ($AddonInfo.displayName -match "\d") {
               

                $temp =  ($AddonInfo.displayName -replace "[a-z,A-Z,-]" , "" -replace " ", "" -replace "_","").Trim(".")

                $ListView_Item.SubItems.Add($temp)

            } else {

                $ListView_Item.SubItems.Add("Not specified")

            }

            


            $ListView_Item.SubItems.Add($record.summary)

            #Deciding row BGcolor
        
            if ($currentVersion -EQ $LatestVersion) {
                if ($i % 2 -eq 0) {
                    $ListView_Item.BackColor = [System.Drawing.Color]::Black
                    $ListView_Item.ForeColor = [System.Drawing.Color]::LightGray
                } else {
                    $ListView_Item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#272727")
                    $ListView_Item.ForeColor = [System.Drawing.Color]::Snow
                }

                $ListViewBox.Items.AddRange($ListView_Item)
                $i++

            } else {
                
                if ($si % 2 -eq 0) {
                    $ListView_Item.ForeColor = [System.Drawing.Color]::Black
                    $ListView_Item.BackColor = [System.Drawing.Color]::Orange
                } else {
                    $ListView_Item.ForeColor = [System.Drawing.Color]::Black
                    $ListView_Item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#e49400")
                }
                
                $ListViewBox.Items.Insert($si,$ListView_Item)
                $si++
            }

        }

        

        
        
        $ListViewBox.AutoResizeColumns(2)
        $ListViewBox.Columns[2].Width = 100
        $ListViewBox.Columns[3].Width = 100
        $ListViewBox.Columns[4].Width = 940 - ($ListViewBox.Columns[0].Width + $ListViewBox.Columns[1].Width + $ListViewBox.Columns[2].Width + $ListViewBox.Columns[3].Width)
        
        if($AddonRemovedFromProject.length -gt 0) {
            $addonstring = ""
            foreach ($removedAddon in $AddonRemovedFromProject) {
                $addonstring += $removedAddon + "
"
            }
            [System.Windows.MessageBox]::Show('These addons have been removed or moved to another project ID on CurseForge.
            
'  + $addonstring +'
Go to "Find More Addons" to reinstall the addon if it have been moved to another project ID','Addon removed','OK','Information')
        }
        
        
        
    }
    

    #*** update ElvUI section 

    $ElvUIViewBox.Clear()
    $ElvUIViewBox.Columns.Add("Name")
    $ElvUIViewBox.Columns.Add("Version")
    $ElvUIViewBox.Columns.Add("LatestVersion")
    $ElvUIViewBox.Columns.Add("Updated")
    $ElvUIViewBox.Columns[0].Width = 75
    $ElvUIViewBox.Columns[1].Width = 50
    $ElvUIViewBox.Columns[2].Width = 85
    $ElvUIViewBox.Columns[$ElvUIViewBox.Columns.Count - 1].Width = -2


    if ($null -eq $Addons.config.ElvUI) {
        $subnode = $Addons.SelectSingleNode("config")
            
        $child = $Addons.CreateElement("ElvUI")

        $SubChildVersion = $Addons.CreateElement("CurrentVersion")
        $SubChildLatestVersion = $Addons.CreateElement("LatestVersion")
        $SubChildDate = $Addons.CreateElement("DateUpdated")
        
        $child.AppendChild($SubChildVersion)
        $child.AppendChild($SubChildLatestVersion)
        $child.AppendChild($SubChildDate)
        
        $child.CurrentVersion = ""
        $child.LatestVersion = ""
        $child.DateUpdated = ""

        $subnode.AppendChild($child)
        
        
        #


    } else {
        if ($null -eq $Addons.config.ElvUI.LatestVersion) {
            $subnode = $Addons.config.SelectSingleNode("ElvUI")
            
            $child = $Addons.CreateElement("LatestVersion")

            $subnode.AppendChild($child)

            $Addons.config.ElvUI.LatestVersion = ""
        }
        if ($null -eq $Addons.config.ElvUI.DateUpdated) {

            $subnode = $Addons.config.SelectSingleNode("ElvUI")
            
            $child = $Addons.CreateElement("DateUpdated")

            $subnode.AppendChild($child)

            $Addons.config.ElvUI.DateUpdated = ""
            
           

        }

        

    } 

    $MethodError = $true
    while ($MethodError) {
        try {
            $ElvUILatestVersion = (Invoke-RestMethod -uri "https://git.tukui.org/elvui/elvui-classic/-/tags?format=atom")[0].title
            $MethodError = $false

        } catch {
            if (Test-Path ".\Resources\error_log.txt") {
                "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\error_log.txt" -Append
                $_ | Out-File ".\Resources\error_log.txt" -Append
            } else {
                "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\error_log.txt"
                $_ | Out-File ".\Resources\error_log.txt" -Append
    
            }
        }
    }
    




    $Addons.config.ElvUI.LatestVersion = $ElvUILatestVersion
    if ($Addons.config.ElvUI.CurrentVersion -eq "") {
        $ButtonElvUI.Text = "Install"
        $ButtonElvUI.BackColor = $StandardButtonColor
        $ButtonElvUI.ForeColor = [System.Drawing.Color]::White

    } else {

        if ($Addons.config.ElvUI.CurrentVersion -ne $ElvUILatestVersion) {
            $ButtonElvUI.Text = "Update available"
            $ButtonElvUI.BackColor = [System.Drawing.Color]::Orange
            $ButtonElvUI.ForeColor = [System.Drawing.Color]::Black
        } else {
            $ButtonElvUI.Text = "Up to date (click to reinstall)"
            $ButtonElvUI.BackColor = $StandardButtonColor
            $ButtonElvUI.ForeColor = [System.Drawing.Color]::White

        }

        

    }

    $ElvUIViewBox_Item = New-Object System.Windows.Forms.ListViewItem("ElvUI Classic")
    $ElvUIViewBox_Item.SubItems.Add($Addons.config.ElvUI.CurrentVersion)
    $ElvUIViewBox_Item.SubItems.Add($Addons.config.ElvUI.LatestVersion)
    $ElvUIViewBox_Item.SubItems.Add($Addons.config.ElvUI.DateUpdated)
    $ElvUIViewBox_Item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
    $ElvUIViewBox_Item.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $ElvUIViewBox.Items.AddRange($ElvUIViewBox_Item)
    
    if ($null -eq $Addons.config.Addon.Length) {
        if ($si -gt 0) {
            $LabelInstalledAddons.Text = "1 Addon installed, " + $si + "Update available"
        } else {
            $LabelInstalledAddons.Text = "1 Addon installed"
        }
    } else {
        if ($si -gt 0) {
            $LabelInstalledAddons.Text = $Addons.config.Addon.Length.ToString() + " Addons installed, " + $si + " Updates available"
        } else {
            $LabelInstalledAddons.Text = $Addons.config.Addon.Length.ToString() + " Addons installed"
        }
    }
    
    Try {
        $Addons.save($XMLPath)
    } catch {
        if (Test-Path ".\Resources\error_log.txt") {
            "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\error_log.txt" -Append
            $_ | Out-File ".\Resources\error_log.txt" -Append
        } else {
            "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\error_log.txt"
            $_ | Out-File ".\Resources\error_log.txt" -Append

        }
    }
        
    $ListViewBox.EndUpdate()
    $ResetViewBox.EndUpdate()
    $ElvUIViewBox.EndUpdate()
    $BuffViewBox.EndUpdate()
    $ButtonRefresh.Text = "Refresh"
    $ButtonRefresh.BackgroundImage = $null
    
}


Function NethergardeKeepBuffSchedule {

    try {
        $BuffsXML = New-Object System.Xml.XmlDocument
        $BuffPath = ".\BuffSchedules\Nethergarde Keep.xml"

        $BuffsXML.AppendChild(($BuffsXML.CreateXmlDeclaration("1.0","UTF-8",$null)))
        $Root = $BuffsXML.CreateNode("element", "RealmBuffs",$null)
        
        $Buffday = $BuffsXML.CreateNode("element", "Today", $null)


   
        $BuffParse = (Invoke-WebRequest -Uri "https://docs.google.com/spreadsheets/d/1YZbvGiUlRzVGYWwSTU7JeYoHtDUZW6JnXoqA1WEim84/htmlview?usp=sharing&pru=AAABc6XNR3U*ofU_hgCnK_odzu3J7DewXA" -TimeoutSec 5)

        $regex = "<tbody>.*<\/tbody>"
        $matches = select-string -InputObject $BuffParse -Pattern $regex -AllMatches | % { $_.Matches } | % { $_.Value }
        $regex = "(<tr .+?</tr>)"
        $matches = select-string -InputObject $matches -Pattern $regex -AllMatches | % { $_.Matches } | % { $_.Value }

        $i = 0
        $today = ( [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date), 'Central European Standard Time') )
        


        if ([int]$today.ToString("dd") -eq [int]$today.ToString("MM")){
            $DayEqMonth = 1
        } else {
            $DayEqMonth = 0
        }

        $today = ">" + [int]$today.ToString("dd") + "<"

        foreach ($row in $matches) {
            if ($row.Contains($today)) {
                if ($DayEqMonth -eq 0){
                    break
                } else {
                    $DayEqMonth = 0
                }
                
                
            }
            $i += 1
        }

        $regex = "(<td .+?</td>)"
        $tds = select-string -InputObject $matches[$i+1] -Pattern $regex -AllMatches | % { $_.Matches } | % { $_.Value }
        $dayOfWeek = ( get-date ).DayOfWeek.value__ 
        if ($dayOfWeek -eq 0) {
            $dayOfWeek = 7
        }
        
        $Buffs = $tds[$dayOfWeek] -replace "(<td .+?>)" , "" -replace "(<div .+?>)" , "" -replace "</div>","" -replace "</td>",""
        $Buffs = $Buffs.Trim("<br>")
        $BuffTimes = $Buffs -split "<br>"
                    
    
        
        foreach ($line in $BuffTimes) {
            $currentLine = $line.Split("|")
            $currentLine = $currentLine -replace "Player: ","" -replace "Reset: ","" -replace "Head: ",""

            $CurrentBuff = $BuffsXML.CreateNode("element", "Buff", $null)
        

            $BuffTime = $BuffsXML.CreateNode("element", "Time", $null)
            $Buffname = $BuffsXML.CreateNode("element", "Name", $null)
            $BuffGuild = $BuffsXML.CreateNode("element", "Guild", $null)
            $BuffReset = $BuffsXML.CreateNode("element", "Reset", $null)
            


            $CurrentBuff.AppendChild($BuffTime)
            $CurrentBuff.AppendChild($Buffname)
            $CurrentBuff.AppendChild($BuffGuild)
            $CurrentBuff.AppendChild($BuffReset)

            $CurrentBuff.Time = $currentLine[0].Trim() -replace "&lt;","<" -replace "&gt;",">"
            $CurrentBuff.Name = $currentLine[1].Trim() -replace "&lt;","<" -replace "&gt;",">"
            $CurrentBuff.Guild = $currentLine[2].Trim() -replace "&lt;","<" -replace "&gt;",">"
            $CurrentBuff.Reset = $currentLine[3].Trim() -replace "&lt;","<" -replace "&gt;",">"


            $Buffday.AppendChild($CurrentBuff)

            
            
        }

        $Root.AppendChild($Buffday)

        $BuffsXML.AppendChild($Root)
        $BuffsXML.Save($BuffPath)
    } catch {
        if (Test-Path ".\Resources\error_log.txt") {
            "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\error_log.txt" -Append
            $_ | Out-File ".\Resources\error_log.txt" -Append
        } else {
            "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\error_log.txt"
            $_ | Out-File ".\Resources\error_log.txt" -Append

        }
    }
    
}

Function Buffplaning {
     #*** Buffplaning *****************************************************************

     
 
     
    if ($LabelBuffsHeader.Selecteditem.ToString() -eq "Nethergarde Keep") {
        NethergardeKeepBuffSchedule
        $BuffsXML = New-Object System.Xml.XmlDocument
        $BuffPath = (".\BuffSchedules\" + $LabelBuffsHeader.SelectedItem + ".xml")
        $BuffsXML.Load($BuffPath)
        $TodayBuffs = $BuffsXML.RealmBuffs.Today.Buff
    } else {
        $BuffsXML = New-Object System.Xml.XmlDocument
        
        $BuffPath = (".\BuffSchedules\" + $LabelBuffsHeader.SelectedItem + ".xml")
       
        $BuffsXML.Load($BuffPath)
        $WeekDayNumber = ( [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date), 'Central European Standard Time') ).DayOfWeek.value__

        if ($WeekDayNumber -eq 1 ) {
            $TodayBuffs = $BuffsXML.RealmBuffs.Monday.Buff
        } elseif ($WeekDayNumber -eq 2 ) {
            $TodayBuffs = $BuffsXML.RealmBuffs.Tuesday.Buff
        } elseif ($WeekDayNumber -eq 3 ) {
            $TodayBuffs = $BuffsXML.RealmBuffs.Wednesday.Buff
        } elseif ($WeekDayNumber -eq 4 ) {
            $TodayBuffs = $BuffsXML.RealmBuffs.Thursday.Buff
        } elseif ($WeekDayNumber -eq 5 ) {
            $TodayBuffs = $BuffsXML.RealmBuffs.Friday.Buff
        } elseif ($WeekDayNumber -eq 6 ) {
            $TodayBuffs = $BuffsXML.RealmBuffs.Saturday.Buff
        } elseif ($WeekDayNumber -eq 0 ) {
            $TodayBuffs = $BuffsXML.RealmBuffs.Sunday.Buff
        }
    }
 
    $BuffViewBox.Clear()
    $BuffViewBox.Columns.Add("ServerTime")
    $BuffViewBox.Columns.Add("Buff")
    $BuffViewBox.Columns.Add("Player/Guild")
    $BuffViewBox.Columns.Add("Reset")
 
    
 
    $i = 0
    foreach ($buff in $TodayBuffs) {
        

        $BuffView_Item = New-Object System.Windows.Forms.ListViewItem($buff.Time)
        $BuffView_Item.SubItems.Add($buff.Name)
        $BuffView_Item.SubItems.Add($buff.Guild)
        $BuffView_Item.SubItems.Add($buff.Reset)

        
        

        $i++
        $InTime = ($buff.Time).Split(":")
        $hour = ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date), 'Central European Standard Time')).ToString("HH")
        $Minute = ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date), 'Central European Standard Time')).ToString("mm")

        
        
        if  ($hour -lt $InTime[0]) {
            $BuffView_Item.ForeColor = [System.Drawing.Color]::Snow
            
        } else {
            if (($hour -eq $InTime[0]) -and ($Minute -lt $InTime[1] )) {
                $BuffView_Item.ForeColor = [System.Drawing.Color]::Snow
            } else {
                $BuffView_Item.ForeColor = [System.Drawing.Color]::Orange
                $BuffView_Item.Font = [System.Drawing.Font]::new($Addons.config.DetailFont, 8, [System.Drawing.FontStyle]::Regular)
            }
            
        }
        
        
        if ($i % 2 -eq 0) {
            $BuffView_Item.BackColor = [System.Drawing.Color]::Black
        } else {
            $BuffView_Item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#272727")
        }

        $BuffViewBox.Items.Insert(0,$BuffView_Item)
        $BuffViewBox.Columns[0].Width = 75
        $BuffViewBox.Columns[1].Width = 75
        $BuffViewBox.Columns[2].Width = 150
        $BuffViewBox.Columns[3].Width = -2
        
        
    }
}

Function ImportCurrentAddons {
    
    $LoadSpinner.Text = "Compairing your addon folders to possible matches on CurseForge..."
    $LoadSpinner.Update()
    $CurrentAddons = Get-ChildItem -Directory $Addons.config.IfaceAddonsFolder | Select-Object Name
    $IDArray = [System.Collections.ArrayList]@()
    foreach ($Folder in $CurrentAddons) {
        $LoadSpinner.Text = "Trying to match" + "
        
'" + $Folder.Name + "'"
        $MethodError = $true
        while ($MethodError) {
            try {
                $Url  = "https://addons-ecs.forgesvc.net/api/v2/addon/search?&gameId=1&sort=downloadCount&gameVersionFlavor=wow_classic&searchFilter=" + $Folder.Name

                $PossibleMatches = (Invoke-RestMethod -Uri $Url -TimeoutSec 5 )
                Start-Sleep -Seconds 1
                $MethodError = $false

            } catch {
                if (Test-Path ".\Resources\error_log.txt") {
                    "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\error_log.txt" -Append
                    $_ | Out-File ".\Resources\error_log.txt" -Append
                } else {
                    "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\error_log.txt"
                    $_ | Out-File ".\Resources\error_log.txt" -Append
        
                }
            }
        }

        foreach ($Match in $PossibleMatches) {
    
            $Modules = ($Match | Select-Object -ExpandProperty LatestFiles | Where-Object gameVersionFlavor -eq wow_classic | Select-Object -ExpandProperty modules | Select-Object foldername)
        
            foreach ($Module in $Modules) {
                
                if ($Folder.name -eq $Module.foldername) {
                    $IDArray.Add($Match.id)
                } 
            }
        } 
    }
   
    $IDArray = $IDArray | Select-Object -Unique

    foreach ($UniqID in $IDArray) {
        $LoadSpinner.Text = "Importing ID: " + $UniqID.ToString()
        $LoadSpinner.Update()
        if ($null -eq $UniqID){
            continue
        } else {
            NewAddon -ID $UniqID.ToString() -ImportOnly $true
        }
    }
   
}

Function CurseForgeSearch {

    Param($SearchTerm)

    $Global:SearchResult = Invoke-RestMethod -uri ("https://addons-ecs.forgesvc.net/api/v2/addon/search?&gameId=1&sort=downloadCount&gameVersionFlavor=wow_classic&searchFilter=" + $SearchTerm) -TimeoutSec 20
    $Global:SearchResult = ($Global:SearchResult | sort-object -property name)
    $SearchOutput = [System.Collections.ArrayList]@()
    foreach ($Result in $Global:SearchResult) {

        $SearchOutput.Add(@($Result.id, $Result.name,$Result.summary))
    }

    $ListSearchResults.Enabled = $false
    $ListSearchResults.Clear()
    $ListSearchResults.Columns.Add("PID")
    $ListSearchResults.Columns.Add("Name")

    $i = 0
    foreach ($record in $SearchOutput){
        
        $ListSearch_Item = New-Object System.Windows.Forms.ListViewItem($record[0])
        $ListSearch_Item.SubItems.Add($record[1])
        $ListSearch_Item.ToolTipText = $record[2]

        $ListSearchResults.Items.AddRange($ListSearch_Item)

        $ListSearch_Item.ForeColor = [System.Drawing.Color]::Snow

        if ($i % 2 -eq 0) {
            $ListSearch_Item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
        } else {
            $ListSearch_Item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#272727")
        }
        $i++
    }

    $LabelSearchResult.Text = "Search results (" + $i.ToString() + ")"

    $ListSearchResults.AutoResizeColumns(2)
    $ListSearchResults.Columns[$ListSearchResults.Columns.Count - 1].Width = -2
    $ListSearchResults.Enabled = $true

    

}

Function makeChangelog {
    $LogText = ""

    foreach ($logentry in $SMOSKVersion.smosk.changelog.logentry) {
        $LogText += "---------------------------------------------------- " + $logentry.version + " ----------------------------------------------------
"
        foreach ($change in $logentry.change) {
            $LogText += "- " + $change + "
"
        }
    
        $LogText += "


"
        
    }

    $Changelogbox.Text = $LogText
}

Function makeUpdateLog {
    $LogText = "Latest updates (Descending)

"

    $UpdateLog = $Addons.config.Addon
    [Array]::Reverse($UpdateLog)
    
    foreach ($entry in $UpdateLog) {
        $LogText += $entry.DateUpdated+ " - " + $entry.name + "
"
    }
    

    $Changelogbox.Text = $LogText
}

Function InstallElvUI {

    Invoke-WebRequest -uri "https://git.tukui.org/elvui/elvui-classic/-/archive/master/elvui-classic-master.zip" -OutFile ".\Downloads\elvui-classic-master.zip" -TimeoutSec 20

    if (Test-Path ($Addons.config.IfaceAddonsFolder + "\ElvUI")){
        Remove-Item -LiteralPath ($Addons.config.IfaceAddonsFolder + "\ElvUI") -Force -Recurse
        
    }
    if (Test-Path ($Addons.config.IfaceAddonsFolder + "\ElvUI_OptionsUI")){
       
        Remove-Item -LiteralPath ($Addons.config.IfaceAddonsFolder + "\ElvUI_OptionsUI") -Force -Recurse
    }

    Unzip -zipfile ".\Downloads\elvui-classic-master.zip" -outpath ".\Downloads"

    Copy-Item -Path ".\Downloads\elvui-classic-master\ElvUI" -Destination ($Addons.config.IfaceAddonsFolder + "\ElvUI\" ) -recurse -Force
    Copy-Item -Path ".\Downloads\elvui-classic-master\ElvUI_OptionsUI" -Destination ($Addons.config.IfaceAddonsFolder + "\ElvUI_OptionsUI\" ) -recurse -Force

    Remove-Item -LiteralPath ".\Downloads\elvui-classic-master" -force -Recurse
    Remove-Item -LiteralPath ".\Downloads\elvui-classic-master.zip" -force -Recurse

    
    $ElvUIVersion = (Invoke-RestMethod -uri "https://git.tukui.org/elvui/elvui-classic/-/tags?format=atom")[0].title

    $Addons.config.ElvUI.CurrentVersion = $ElvUIVersion
    $Addons.config.ElvUI.DateUpdated = (Get-Date -Format "yyyy-MM-dd").ToString()

    $Addons.Save($XMLPath)

}

Function PullNewResources {
    #*** pull new resources if missing
    if ($Addons.config.Version -ne "3.1.1") {

        $Updater = New-Object System.Xml.XmlDocument
        $XMLPathUpdater = "https://www.smosk.net/downloads/UpdateState.xml"
        $Updater.Load($XMLPathUpdater)
       
        $url = "https://www.smosk.net/downloads/AddonManager.zip"
        $outfile = ".\Downloads\updater.zip"

        Invoke-WebRequest -Uri $url -OutFile $outfile

        Unzip -outpath ".\Downloads\" -zipfile $outfile

        foreach ($file in $Updater.files.file) {
            Copy-Item -Path $file.from -Destination $file.to -Recurse -Force
        }


        #*** Cleanup
        Remove-Item -LiteralPath ".\Downloads\AddonManager\" -Force -Recurse
        Remove-Item -LiteralPath ".\Downloads\updater.zip" -Force -Recurse


        $Addons.config.Version = "3.1.1"
        $Addons.Save($XMLPath)

    }

}

try {
$global:ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = "Stop"





#*** Create XML object and load addon database
$Addons = New-Object System.Xml.XmlDocument
$XMLPath = ".\Resources\Save.xml"
$Addons.Load($XMLPath)






$OSInfo = (get-computerinfo | select-object -property OSName, OSVersion)

$SMOSKVersion = New-Object System.Xml.XmlDocument
$SMOSKVersionPath = "https://www.smosk.net/downloads/version.xml"
$SMOSKVersion.Load($SMOSKVersionPath)

#*** Download latest updater
PullNewResources

#***  Render the GUI
DrawGUI


} catch {
    
    if (Test-Path ".\Resources\error_log.txt") {
        "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\error_log.txt" -Append
        $_ | Out-File ".\Resources\error_log.txt" -Append
    } else {
        "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\error_log.txt"
        $_ | Out-File ".\Resources\error_log.txt" -Append
        
    }
    [System.Windows.MessageBox]::Show("Something have caused the program to fail. See error log for more info.
.\Resources\error_log.txt",'SMOSK! Error','OK','Information')

}
