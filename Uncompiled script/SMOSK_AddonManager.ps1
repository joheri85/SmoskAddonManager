$Version = "2.3.7"
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
        

        $AddonToInstall = Invoke-RestMethod -Uri $Url -TimeoutSec 20
        $AddonInfo = $AddonToInstall | 
            Select-Object -ExpandProperty LatestFiles  |
                Where-Object {($_.GameVersionFlavor -eq "wow_classic") -and ($_.ReleaseType -eq "1")  }
        
        if ($null -ne $AddonInfo.length -and $null -ne $AddonInfo){

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
           
            $child.AppendChild($SubChildID)
            $child.AppendChild($SubChildName)
            $child.AppendChild($SubChildDownloadLink)
            $child.AppendChild($SubChildDescription)
            $child.AppendChild($SubChildVersion)
            $child.AppendChild($SubChildLVersion)
            $child.AppendChild($SubChildModules)
           
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


            if ($ImportOnly) { 
                $child.CurrentVersion = "Imported, Update to display version."
                
            } else {
                $child.CurrentVersion = $AddonInfo.displayName.ToString()
            }
            $subnode.AppendChild($child)
        
            $Addons.Save($XMLPath)
            
            if ($ImportOnly -eq $false) { 
                $OutFile = (".\Downloads\" + $AddonInfo.fileName)
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
        $textBoxIfaceAddonsPath.Text = $Path
        $Addons.Save($XMLPath)

    }
    
}





Function DrawGUI {

    $CreamText = [System.Drawing.ColorTranslator]::FromHtml("#f1c898")

    $global:dragging = $false
    $global:mouseDragX = 0
    $global:mouseDragY = 0



    $workareaWidth = 0
    $workareaHeight = 0
    foreach ($screen in ([System.Windows.Forms.Screen]::AllScreens) ) {
        $workareaWidth += [int]($screen | Select-Object -ExpandProperty WorkingArea).Width
        $workareaHeight += [int]($screen | Select-Object -ExpandProperty WorkingArea).Height
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
    $LabelSplash.Location  = New-Object System.Drawing.Point(0,70)
    $LabelSplash.Size = New-Object System.Drawing.Size(500,50)
    $LabelSplash.TextAlign = "MiddleCenter"
    $LabelSplash.BackColor = [System.Drawing.Color]::Transparent
    $LabelSplash.ForeColor = [System.Drawing.Color]::White
    $LabelSplash.Font = [System.Drawing.Font]::new("Georgia", 12, [System.Drawing.FontStyle]::Bold)
    $SplashScreen.Controls.Add($LabelSplash)

     #*** Label Splash
     $LabelSplashStatus = New-Object System.Windows.Forms.Label
     $LabelSplashStatus.Text = "Loading..." 
     $LabelSplashStatus.Location  = New-Object System.Drawing.Point(0,180)
     $LabelSplashStatus.Size = New-Object System.Drawing.Size(500,50)
     $LabelSplashStatus.TextAlign = "MiddleCenter"
     $LabelSplashStatus.BackColor = [System.Drawing.Color]::Transparent
     $LabelSplashStatus.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffa500")
     $LabelSplashStatus.Font = [System.Drawing.Font]::new("Georgia", 10, [System.Drawing.FontStyle]::Bold)
     $SplashScreen.Controls.Add($LabelSplashStatus)

    #*** Progressbar
    $SplashProgress = New-Object System.Windows.Forms.Label
    $SplashProgress.Location  = New-Object System.Drawing.Point(2,243)
    $SplashProgress.Size = New-Object System.Drawing.Size(494,5)
    $SplashProgress.BackColor = [System.Drawing.Color]::White
    $SplashProgress.ForeColor = [System.Drawing.Color]::White
    $SplashProgress.BorderStyle = "Fixed3D"
    $SplashScreen.Controls.Add($SplashProgress)
    $SplashProgress.BringToFront()

    $SplashScreen.Show()
    $LabelSplash.Update()

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
    $LabelMoveSearchForm.Font = [System.Drawing.Font]::new("Georgia", 12, [System.Drawing.FontStyle]::Bold)
    $LabelMoveSearchForm.ForeColor = $CreamText
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
    $LabelSearchString.Font = [System.Drawing.Font]::new("Georgia", 12, [System.Drawing.FontStyle]::Bold)
    $Search_form.Controls.Add($LabelSearchString)

    #*** Textbox Search String
    $textBoxSearchString = New-Object System.Windows.Forms.TextBox
    $textBoxSearchString.Location = New-Object System.Drawing.Size(10,70)
    $textBoxSearchString.Size = New-Object System.Drawing.Size(400,20)
    $textBoxSearchString.ForeColor = [System.Drawing.Color]::White
    $textBoxSearchString.BackColor = [System.Drawing.Color]::Black
    $textBoxSearchString.Font = [System.Drawing.Font]::new("Georgia", 12, [System.Drawing.FontStyle]::Bold)
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
    $ButtonDoSearch.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $ButtonDoSearch.ForeColor = [System.Drawing.Color]::White
    $ButtonDoSearch.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
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
    $LabelSearchResult.Font = [System.Drawing.Font]::new("Georgia", 12, [System.Drawing.FontStyle]::Bold)
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
    $ListSearchResults.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)
    
    $ListSearchResults.Add_click({
        $url = ("https://addons-ecs.forgesvc.net/api/v2/addon/" + $ListSearchResults.SelectedItems[0].Text)
        $LabelSearchDescriptionText.Text = "Loading description..."
        $thumbnail = (Invoke-RestMethod -uri $url -TimeoutSec 20 | Select-Object -ExpandProperty attachments)
        if ($null -ne $thumbnail) {
            $pictureBox.Load($thumbnail[0].thumbnailUrl)
        } else {
            $pictureBox.image = $null
        }
        
        $LabelSearchDescriptionText.Text = (Invoke-RestMethod -Uri $url).summary
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
    $LablePictureBox.Font = [System.Drawing.Font]::new("Georgia", 12, [System.Drawing.FontStyle]::Bold)
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
    $LabelSearchDescription.Font = [System.Drawing.Font]::new("Georgia", 12, [System.Drawing.FontStyle]::Bold)
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
    $ButtonWebURL.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $ButtonWebURL.ForeColor = [System.Drawing.Color]::White
    $ButtonWebURL.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
    $Search_form.Controls.Add($ButtonWebURL)

    $ButtonWebURL.Add_Click({
        $ListSearchResults.SelectedItems[0]
        if ($null -ne $ListSearchResults.SelectedItems[0]){
            Start-Process (Invoke-RestMethod -Uri ("https://addons-ecs.forgesvc.net/api/v2/addon/" + $ListSearchResults.SelectedItems[0].Text) -TimeoutSec 20).WebSiteUrl
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
    $ButtonInstallSearchSelect.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $ButtonInstallSearchSelect.ForeColor = [System.Drawing.Color]::White
    $ButtonInstallSearchSelect.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
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
    $LabelSearchDescriptionText.Font = [System.Drawing.Font]::new("Arial", 10, [System.Drawing.FontStyle]::Bold)
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
    $LabelMoveMainForm.Size = New-Object System.Drawing.Size(920, 30)
    $LabelMoveMainForm.Anchor = "Top","Left"
    $LabelMoveMainForm.BorderStyle = "None"
    $LabelMoveMainForm.Text = "SMOSK - Classic Addon Manager"
    $LabelMoveMainForm.Font = [System.Drawing.Font]::new("Georgia", 12, [System.Drawing.FontStyle]::Bold)
    $LabelMoveMainForm.ForeColor = $CreamText
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
    #$ButtonCloseMainForm.Text = "X"
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
    #$ButtonMinimizeMainForm.Text = "_"
    $ButtonMinimizeMainForm.FlatStyle = "PopUp"
    $ButtonMinimizeMainForm.UseVisualStyleBackColor = $true
    $ButtonMinimizeMainForm.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\minimize.png")
    $ButtonMinimizeMainForm.BackgroundImageLayout = "Zoom"
    $ButtonMinimizeMainForm.ForeColor = [System.Drawing.Color]::White
    $ButtonMinimizeMainForm.BackColor = [System.Drawing.Color]::Black
    #$ButtonMinimizeMainForm.BorderStyle = "FixedSingle"
    #$ButtonMinimizeMainForm.UseMnemonic = $true
    
    $ButtonMinimizeMainForm.Add_Click({
        $main_form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
    })

    $main_form.Controls.Add($LabelMoveMainForm)
    $main_form.Controls.Add($ButtonMinimizeMainForm)
    $main_form.Controls.Add($ButtonCloseMainForm)

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
    $LoadSpinner.Font = [System.Drawing.Font]::new("Georgia", 10, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LoadSpinner)
    $LoadSpinner.BringToFront()

     #*** LoadSpinnerProgress
     $LoadSpinnerProgress = New-Object System.Windows.Forms.Label
     $LoadSpinnerProgress.Location  = New-Object System.Drawing.Point(370,235)
     $LoadSpinnerProgress.Size = New-Object System.Drawing.Size(250,5)
     $LoadSpinnerProgress.Anchor = "Bottom,Right"
     $LoadSpinnerProgress.BackColor = [System.Drawing.Color]::White
     $LoadSpinnerProgress.ForeColor = [System.Drawing.Color]::White
     $LoadSpinnerProgress.BorderStyle = "Fixed3D"
     $main_form.Controls.Add($LoadSpinnerProgress)
     $LoadSpinnerProgress.BringToFront()

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
    $LabelInstalledAddons.Font = [System.Drawing.Font]::new("Georgia", 12, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelInstalledAddons)

    #*** Label LegendSelected Color
    $LabelSelectedColor = New-Object System.Windows.Forms.Label
    $LabelSelectedColor.Location  = New-Object System.Drawing.Point(710,35)
    $LabelSelectedColor.Size = New-Object System.Drawing.Size(10,10)
    $LabelSelectedColor.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0078d7")
    $LabelSelectedColor.BorderStyle = "FixedSingle"
    $LabelSelectedColor.Anchor = "Top,Right"
    $main_form.Controls.Add($LabelSelectedColor)

    #*** Label LegendSelected Text
    $LabelSelectedText = New-Object System.Windows.Forms.Label
    $LabelSelectedText.Text = "Selected"
    $LabelSelectedText.Location  = New-Object System.Drawing.Point(720,30)
    $LabelSelectedText.Size = New-Object System.Drawing.Size(60,20)
    $LabelSelectedText.TextAlign = "MiddleLeft"
    $LabelSelectedText.Anchor = "Top,Right"
    $LabelSelectedText.BackColor = [System.Drawing.Color]::Transparent
    $LabelSelectedText.ForeColor = [System.Drawing.Color]::White
    $LabelSelectedText.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelSelectedText)

    #*** Label LegendUpToDate Color
    $LabelUpToDateColor = New-Object System.Windows.Forms.Label
    $LabelUpToDateColor.Location  = New-Object System.Drawing.Point(790,35)
    $LabelUpToDateColor.Size = New-Object System.Drawing.Size(10,10)
    $LabelUpToDateColor.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#c7c7c7")
    $LabelUpToDateColor.BorderStyle = "FixedSingle"
    $LabelUpToDateColor.Anchor = "Top,Right"
    $main_form.Controls.Add($LabelUpToDateColor)

    #*** Label LegendUpToDate Text
    $LabelUpToDateText = New-Object System.Windows.Forms.Label
    $LabelUpToDateText.Text = "Up to date"
    $LabelUpToDateText.Location  = New-Object System.Drawing.Point(800,30)
    $LabelUpToDateText.Size = New-Object System.Drawing.Size(60,20)
    $LabelUpToDateText.TextAlign = "MiddleLeft"
    $LabelUpToDateText.Anchor = "Top,Right"
    $LabelUpToDateText.BackColor = [System.Drawing.Color]::Transparent
    $LabelUpToDateText.ForeColor = [System.Drawing.Color]::White
    $LabelUpToDateText.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelUpToDateText)

    #*** Label LegendUpdateAvailable Color
    $LabelUpdateAvailableText = New-Object System.Windows.Forms.Label
    $LabelUpdateAvailableText.Location  = New-Object System.Drawing.Point(870,35)
    $LabelUpdateAvailableText.Size = New-Object System.Drawing.Size(10,10)
    $LabelUpdateAvailableText.BackColor = [System.Drawing.Color]::Orange
    $LabelUpdateAvailableText.BorderStyle = "FixedSingle"
    $LabelUpdateAvailableText.Anchor = "Top,Right"
    $main_form.Controls.Add($LabelUpdateAvailableText)

    #*** Label LegendUpToDate Text
    $LabelUpdateAvailableColor = New-Object System.Windows.Forms.Label
    $LabelUpdateAvailableColor.Text = "Update available"
    $LabelUpdateAvailableColor.Location  = New-Object System.Drawing.Point(880,30)
    $LabelUpdateAvailableColor.Size = New-Object System.Drawing.Size(100,20)
    $LabelUpdateAvailableColor.TextAlign = "MiddleLeft"
    $LabelUpdateAvailableColor.Anchor = "Top,Right"
    $LabelUpdateAvailableColor.BackColor = [System.Drawing.Color]::Transparent
    $LabelUpdateAvailableColor.ForeColor = [System.Drawing.Color]::White
    $LabelUpdateAvailableColor.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelUpdateAvailableColor)

    #*** Addon List
    $ListViewBox = New-Object System.Windows.Forms.ListView
    $ListViewBox.Location = New-Object System.Drawing.Point(10,60)
    $ListViewBox.Size     = New-Object System.Drawing.Size(950,410)
    $ListViewBox.Anchor = 'Top, Bottom, Left, Right'
    $ListViewBox.View = 'Details'
    $ListViewBox.GridLines = $false
    $ListViewBox.BackColor = [System.Drawing.Color]::Black
    $ListViewBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
    $ListViewBox.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)
    $ListViewBox.FullRowSelect = $true
    $ListViewBox.MultiSelect = $true

    
    $ListViewBox.Add_click({
        
    })

    $ListViewBox.Add_DoubleClick({
        Start-Process (Invoke-RestMethod -uri ("https://addons-ecs.forgesvc.net/api/v2/addon/" + $ListViewBox.SelectedItems[0].Text)).websiteUrl
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
    $ButtonRefresh.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $ButtonRefresh.ForeColor = [System.Drawing.Color]::White
    $ButtonRefresh.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($ButtonRefresh)

    $ButtonRefresh.Add_Click({
        $LoadSpinner.Text = "Refreshing...

May take some time depending on API response time"
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
    $ButtonUpdateSelected.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $ButtonUpdateSelected.ForeColor = [System.Drawing.Color]::White
    $ButtonUpdateSelected.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
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
        $ToolTipUpdateAll.SetToolTip($ButtonUpdateAll,"Updates all addons addons that have a new version on CurseForge.")        
        $ButtonUpdateAll.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
        $ButtonUpdateAll.ForeColor = [System.Drawing.Color]::White
        $ButtonUpdateAll.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
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
    $ButtonOpenSearch.Size = New-Object System.Drawing.Size(320,55)
    $ButtonOpenSearch.Text = "Find more addons"
    $ButtonOpenSearch.Anchor = "Bottom,Left"
    $ButtonOpenSearch.FlatStyle = "Popup"
    $ToolTipOpenSearch = New-Object System.Windows.Forms.ToolTip
    $ToolTipOpenSearch.SetToolTip($ButtonOpenSearch,"Search and install more addons from CurseForge.")  
    $ButtonOpenSearch.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $ButtonOpenSearch.ForeColor = [System.Drawing.Color]::White
    $ButtonOpenSearch.Font = [System.Drawing.Font]::new("Georgia", 12, [System.Drawing.FontStyle]::Bold)
    $ButtonOpenSearch.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\search.png")
    $ButtonOpenSearch.BackgroundImageLayout = "Zoom"
    $main_form.Controls.Add($ButtonOpenSearch)

    $ButtonOpenSearch.Add_Click({
        $Search_form.ShowDialog()

    })

    #*** Label Popular addons
    $LabelPopular = New-Object System.Windows.Forms.Label
    $LabelPopular.Text = "Popular addons (Click to install)"
    $LabelPopular.Location  = New-Object System.Drawing.Point(10,540)
    $LabelPopular.Size = New-Object System.Drawing.Size(320,30)
    $LabelPopular.TextAlign = "MiddleCenter"
    $LabelPopular.Anchor = "Bottom,Left"
    $LabelPopular.BackColor = [System.Drawing.Color]::Transparent
    $LabelPopular.ForeColor = [System.Drawing.Color]::White
    $LabelPopular.Font = [System.Drawing.Font]::new("Georgia", 12, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelPopular)

    #*** Button Popular CommunityDKP
    $ButtonP1 = New-Object System.Windows.Forms.Button
    $ButtonP1.Location = New-Object System.Drawing.Size(10,570)
    $ButtonP1.Size = New-Object System.Drawing.Size(100,40)
    $ButtonP1.Text = "CommunityDKP"
    $ButtonP1.FlatStyle = "Popup"
    $ButtonP1.Anchor = "Bottom,Left"
    $ButtonP1.ForeColor = [System.Drawing.Color]::White
    $ButtonP1.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $ButtonP1.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($ButtonP1)

    $ButtonP1.Add_Click({
        $LoadSpinner.Visible = $true
        NewAddon -ID "390738" -ImportOnly $false
        UpdateAddonsTable
        $LoadSpinner.Visible = $false
    })

    #*** Button Popular DBM
    $ButtonP2 = New-Object System.Windows.Forms.Button
    $ButtonP2.Location = New-Object System.Drawing.Size(120,570)
    $ButtonP2.Size = New-Object System.Drawing.Size(100,40)
    $ButtonP2.Text = "Deadly Boss Mods"
    $ButtonP2.FlatStyle = "Popup"
    $ButtonP2.Anchor = "Bottom,Left"
    $ButtonP2.ForeColor = [System.Drawing.Color]::White
    $ButtonP2.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")

    $ButtonP2.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($ButtonP2)

    $ButtonP2.Add_Click({
        $LoadSpinner.Visible = $true
        NewAddon -ID "3358" -ImportOnly $false
        UpdateAddonsTable
        $LoadSpinner.Visible = $false
    })

    #*** Button Popular Details
    $ButtonP3 = New-Object System.Windows.Forms.Button
    $ButtonP3.Location = New-Object System.Drawing.Size(230,570)
    $ButtonP3.Size = New-Object System.Drawing.Size(100,40)
    $ButtonP3.Text = "Details! 
    Damage Meter"
    $ButtonP3.FlatStyle = "Popup"
    $ButtonP3.Anchor = "Bottom,Left"
    $ButtonP3.ForeColor = [System.Drawing.Color]::White
    $ButtonP3.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $ButtonP3.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($ButtonP3)

    $ButtonP3.Add_Click({
        $LoadSpinner.Visible = $true
        NewAddon -ID "61284" -ImportOnly $false
        UpdateAddonsTable
        $LoadSpinner.Visible = $false
    })

    #*** Label ElvUI
    $LabelElvUI = New-Object System.Windows.Forms.Label
    $LabelElvUI.Text = "ElvUI"
    $LabelElvUI.Location  = New-Object System.Drawing.Point(340,540)
    $LabelElvUI.Size = New-Object System.Drawing.Size(200,30)
    $LabelElvUI.TextAlign = "MiddleCenter"
    $LabelElvUI.Anchor = "Bottom,Left"
    $LabelElvUI.BackColor = [System.Drawing.Color]::Transparent
    $LabelElvUI.ForeColor = [System.Drawing.Color]::White
    $LabelElvUI.Font = [System.Drawing.Font]::new("Georgia", 12, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelElvUI)
    

    #*** Button ElvUI
    $ButtonElvUI = New-Object System.Windows.Forms.Button
    $ButtonElvUI.Location = New-Object System.Drawing.Size(340,570)
    $ButtonElvUI.Size = New-Object System.Drawing.Size(200,90)
    <#
    if (Test-Path ($Addons.config.IfaceAddonsFolder + "\ElvUI")) {
        $ButtonElvUI.Text = ("Update ElvUI

CurrentVersion " + $Addons.config.ElvUI.CurrentVersion)
    } else {
        $ButtonElvUI.Text = "Install ElvUI"version
    }
    #>
    $ButtonElvUI.FlatStyle = "Popup"
    $ButtonElvUI.Anchor = "Bottom,Left"
    $ButtonElvUI.ForeColor = [System.Drawing.Color]::White
    $ButtonElvUI.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $ButtonElvUI.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($ButtonElvUI)

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

    #*** Button Popular WeakAuras2
    $ButtonP4 = New-Object System.Windows.Forms.Button
    $ButtonP4.Location = New-Object System.Drawing.Size(10,620)
    $ButtonP4.Size = New-Object System.Drawing.Size(100,40)
    $ButtonP4.Text = "WeakAuras 2"
    $ButtonP4.Anchor = "Bottom,Left"
    $ButtonP4.FlatStyle = "Popup"
    $ButtonP4.ForeColor = [System.Drawing.Color]::White
    $ButtonP4.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $ButtonP4.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($ButtonP4)

    $ButtonP4.Add_Click({
        $LoadSpinner.Visible = $true
        NewAddon -ID "65387" -ImportOnly $false
        UpdateAddonsTable
        $LoadSpinner.Visible = $false
    })

    #*** Button Popular AtlasLoot
    $ButtonP5 = New-Object System.Windows.Forms.Button
    $ButtonP5.Location = New-Object System.Drawing.Size(120,620)
    $ButtonP5.Size = New-Object System.Drawing.Size(100,40)
    $ButtonP5.Text = "AtlasLootClassic"
    $ButtonP5.FlatStyle = "Popup"
    $ButtonP5.Anchor = "Bottom,Left"
    $ButtonP5.ForeColor = [System.Drawing.Color]::White
    $ButtonP5.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $ButtonP5.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($ButtonP5)

    $ButtonP5.Add_Click({
        $LoadSpinner.Visible = $true
        NewAddon -ID "326516" -ImportOnly $false
        UpdateAddonsTable
        $LoadSpinner.Visible = $false
    })

    #*** Button Popular Questie
    $ButtonP6 = New-Object System.Windows.Forms.Button
    $ButtonP6.Location = New-Object System.Drawing.Size(230,620)
    $ButtonP6.Size = New-Object System.Drawing.Size(100,40)
    $ButtonP6.Text = "Questie"
    $ButtonP6.FlatStyle = "Popup"
    $ButtonP6.Anchor = "Bottom,Left"
    $ButtonP6.ForeColor = [System.Drawing.Color]::White
    $ButtonP6.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $ButtonP6.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($ButtonP6)

    $ButtonP6.Add_Click({
        $LoadSpinner.Visible = $true
        NewAddon -ID "334372" -ImportOnly $false
        UpdateAddonsTable
        $LoadSpinner.Visible = $false
    })

    #*** Button Import Current addons
    $ButtonImport = New-Object System.Windows.Forms.Button
    $ButtonImport.Location = New-Object System.Drawing.Size(860,700)
    $ButtonImport.Size = New-Object System.Drawing.Size(100,40)
    $ButtonImport.Text = "Import installed addons"
    $ButtonImport.FlatStyle = "Popup"
    $ButtonImport.Anchor = "Bottom,Right"
    $ToolTipImport = New-Object System.Windows.Forms.ToolTip
    $ToolTipImport.SetToolTip($ButtonImport,"Searches through your addons folder and matching excisting addons with possible matches on CurseForge and adds them to the list") 
    $ButtonImport.ForeColor = [System.Drawing.Color]::White
    $ButtonImport.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $ButtonImport.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
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
     $LabelVersion = New-Object System.Windows.Forms.Label
     $LabelVersion.Text = "Version " + $Version
     $LabelVersion.Anchor = "Bottom,Right"
     $LabelVersion.Location  = New-Object System.Drawing.Point(760,740)
     $LabelVersion.Size = New-Object System.Drawing.Size(200,20)
     $LabelVersion.TextAlign = "MiddleRight"
     $LabelVersion.BackColor = [System.Drawing.Color]::Transparent
     if ($version -eq $SMOSKVersion.smosk.version) {
        $LabelVersion.ForeColor = [System.Drawing.Color]::LightGray
     } else {
        $LabelVersion.ForeColor = [System.Drawing.Color]::Orange
     }
     $LabelVersion.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
     $main_form.Controls.Add($LabelVersion)

     $LabelVersion.add_Click(
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
    $LabelCreator.Size = New-Object System.Drawing.Size(300,20)
    $LabelCreator.TextAlign = "MiddleLeft"
    $LabelCreator.Anchor = "Bottom,Left"
    $LabelCreator.BackColor = [System.Drawing.Color]::Transparent
    $LabelCreator.ForeColor = [System.Drawing.Color]::LightGray
    $LabelCreator.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
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
    $ButtonDeleteAddon.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
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

    #*** Label IfaceAddons
    $LabelIfaceAddons = New-Object System.Windows.Forms.Label
    $LabelIfaceAddons.Text = "WoW Classic addons path"
    $LabelIfaceAddons.Location  = New-Object System.Drawing.Point(10,680)
    $LabelIfaceAddons.Size = New-Object System.Drawing.Size(500,30)
    $LabelIfaceAddons.TextAlign = "MiddleLeft"
    $LabelIfaceAddons.Anchor = "Bottom,Left"
    $LabelIfaceAddons.BackColor = [System.Drawing.Color]::Transparent
    $LabelIfaceAddons.ForeColor = [System.Drawing.Color]::White
    $LabelIfaceAddons.Font = [System.Drawing.Font]::new("Georgia", 12, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelIfaceAddons)

    #*** Label buffplaning header
    $LabelBuffsHeader = New-Object System.Windows.Forms.Label
    $LabelBuffsHeader.Location  = New-Object System.Drawing.Point(550,540)
    $LabelBuffsHeader.Text = "Nethergarde-Keep Buffplaning " + (Get-Date -Format "yyyy-MM-dd")
    $LabelBuffsHeader.Size = New-Object System.Drawing.Size(425,30)
    $LabelBuffsHeader.Anchor = "Bottom,Left"
    $LabelBuffsHeader.TextAlign = "MiddleCenter"
    $LabelBuffsHeader.BackColor = [System.Drawing.Color]::Transparent
    $LabelBuffsHeader.ForeColor = [System.Drawing.Color]::White
    $LabelBuffsHeader.Font = [System.Drawing.Font]::new("Georgia", 10, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelBuffsHeader)


    #*** Label buffplaning
    $LabelBuffs = New-Object System.Windows.Forms.Button
    $LabelBuffs.Location  = New-Object System.Drawing.Point(550,570)
    $LabelBuffs.Size = New-Object System.Drawing.Size(425,90)
    $LabelBuffs.TextAlign = "TopCenter"
    $LabelBuffs.FlatStyle = "Popup"
    $LabelBuffs.Anchor = "Bottom,Left"
    $LabelBuffs.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $LabelBuffs.ForeColor = [System.Drawing.Color]::White
    $LabelBuffs.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Bold)
    $main_form.Controls.Add($LabelBuffs)

    $LabelBuffs.Add_Click({
        
       Start-Process "https://docs.google.com/spreadsheets/d/1YZbvGiUlRzVGYWwSTU7JeYoHtDUZW6JnXoqA1WEim84/htmlview?usp=sharing&pru=AAABc6XNR3U*ofU_hgCnK_odzu3J7DewXA"

     })

    

     #*** Textbox IfaceAddonsPath
     $textBoxIfaceAddonsPath = New-Object System.Windows.Forms.TextBox
     $textBoxIfaceAddonsPath.Location = New-Object System.Drawing.Size(10,710)
     $textBoxIfaceAddonsPath.Size = New-Object System.Drawing.Size(500,20)
     $textBoxIfaceAddonsPath.Enabled = $false
     $textBoxIfaceAddonsPath.Anchor = "Bottom,Left"
     $textBoxIfaceAddonsPath.BackColor = [System.Drawing.Color]::Black
     $textBoxIfaceAddonsPath.ForeColor = [System.Drawing.Color]::White
     $textBoxIfaceAddonsPath.Font = [System.Drawing.Font]::new("Georgia", 12, [System.Drawing.FontStyle]::Bold)
     $textBoxIfaceAddonsPath.Text = $Addons.config.IfaceAddonsFolder
     $main_form.Controls.Add($textBoxIfaceAddonsPath)
 
     #*** Button IfaceAddonsPatch 
     $ButtonIfaceAddonsPath = New-Object System.Windows.Forms.Button
     $ButtonIfaceAddonsPath.Location = New-Object System.Drawing.Size(520,710)
     $ButtonIfaceAddonsPath.Size = New-Object System.Drawing.Size(75,26)
     $ButtonIfaceAddonsPath.Text = "Browse"
     $ButtonIfaceAddonsPath.FlatStyle = "Popup"
     $ButtonIfaceAddonsPath.Anchor = "Bottom,Left"
     $ButtonIfaceAddonsPath.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
     $ButtonIfaceAddonsPath.ForeColor = [System.Drawing.Color]::White
     $ButtonIfaceAddonsPath.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
     $main_form.Controls.Add($ButtonIfaceAddonsPath)
 
     $ButtonIfaceAddonsPath.Add_Click({
        
        SetIfaceAddonsFolder

     })

    UpdateAddonsTable
    $LoadSpinner.Visible = $false
    $SplashScreen.Hide()
    $ListViewBox.TabIndex = 0
    $main_form.ShowDialog()


    $main_form.Dispose()
    $Search_form.Dispose()
    $SplashScreen.Dispose()
    
}

# Checks for available updates from curseforge and refreshes the addon listview
Function UpdateAddonsTable {

    $SMOSKVersion.Load($SMOSKVersionPath)
    if ($version -eq $SMOSKVersion.smosk.version) {
        $LabelVersion.ForeColor = [System.Drawing.Color]::LightGray
        $LabelVersion.Text = "Version " + $Version
    } else {
        $LabelVersion.ForeColor = [System.Drawing.Color]::Orange
        $LabelVersion.Text = "Version " + $Version + " - Update available"
    }

    $BuffTimes = (Invoke-RestMethod -Uri "https://docs.google.com/spreadsheets/d/1YZbvGiUlRzVGYWwSTU7JeYoHtDUZW6JnXoqA1WEim84/htmlview?usp=sharing&pru=AAABc6XNR3U*ofU_hgCnK_odzu3J7DewXA") -split '<td class="s10 softmerge" dir="ltr">'

    $BuffTimes = $BuffTimes[1] -split "</td>"

    $BuffTimes = $BuffTimes[0] -split "<br>" , "" -replace "</div>" , ""

    $BuffTimes = $BuffTimes.split(">")

    $first, $rest= $BuffTimes
    $buffplaning = "
"
    foreach ($line in $rest) {
        $buffplaning += ($line + "

")

    }

    $LabelBuffs.Text = $buffplaning


    if ($null -ne $Addons.config.Addon ) {

        $Addons.Load($XMLPath)
        $ListViewBox.Visible = $false
        $LoadSpinner.Update()
        $ListViewBox.Clear()
        $ListViewBox.Columns.Add("PID")
        $ListViewBox.Columns.Add("Name")
        $ListViewBox.Columns.Add("Version")
        $ListViewBox.Columns.Add("LatestVersion")
        $ListViewBox.Columns.Add("Description")

        $LoadSpinnerProgress.Visible = $true
        $LoadSpinnerProgress.BringToFront()
        

        if ($null -eq $Addons.config.Addon.Length) {
            
            $nrAddons = 1

        } else {
            $nrAddons = $Addons.config.Addon.Length

        }
        
        $i = 0; # Odd/Even index determines Background color on rows
        $si = 0; # Subindex keeping trak on where to insert item that has an update available

        #*** Getting properties for all installed addons and sorting them by name *********
        $body = @()
        foreach ($addon in ($Addons.config.addon | Sort-Object Name)) {
            $body += $addon.id
        }
        
        if ($body.Length -gt 1) {
            $body = $body | ConvertTo-Json

            $response = (Invoke-RestMethod -uri "https://addons-ecs.forgesvc.net/api/v2/addon" -Body $body -Method Post -ContentType "application/json" -TimeoutSec 20) | Sort-Object Name
        } else {

            $response = Invoke-RestMethod -uri ("https://addons-ecs.forgesvc.net/api/v2/addon/" + $body)
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

            #*** Update progressbar on refresh view and spalshscreen
            $Progress = ([int]$LoadSpinner.Width / [int]$nrAddons) * [int]$numberDone
            $LoadSpinnerProgress.Width = $Progress
            $LoadSpinnerProgress.Update()
            $LabelSplashStatus.Update()
            $SplashProgress.Width = ([int]$Progress * 2) - 4
            $SplashProgress.Update()

            $ListView_Item = New-Object System.Windows.Forms.ListViewItem($record.ID)
            $ListView_Item.SubItems.Add($record.Name)

            $currentVersion = ($Addons.config.Addon | Where-Object ID -eq $record.id).CurrentVersion
            $latestVersion = ($Addons.config.Addon | Where-Object ID -eq $record.id).LatestVersion

            
            if ($currentVersion -match "\d") {

                $temp =  ($currentVersion -replace "[a-z,A-Z,-]" , "" -replace " ", "" -replace "_","").Trim(".")

                $ListView_Item.SubItems.Add($temp)

            } else {

                $ListView_Item.SubItems.Add("Not specified")

            }
            
            

            $AddonInfo = $record | 
                Select-Object -ExpandProperty LatestFiles |
                    Where-Object {
                        ($_.GameVersionFlavor -eq "wow_classic") -and ($_.ReleaseType -eq "1") 
                    }
            
            if ($null -ne $AddonInfo) {
                $AddonInfo = $AddonInfo[0]

            }

            ($Addons.config.addon | Where-Object ID -EQ $Record.ID).LatestVersion = $AddonInfo.displayName 
            $Addons.save($XMLPath)

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
                    $ListView_Item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#e0e0e0")
                } else {
                    $ListView_Item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#c7c7c7")
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

        if ($null -eq $Addons.config.Addon.Length) {

            $LabelInstalledAddons.Text = "1 Addon installed, " + $si + " Updates available"
            
        } else {

            $LabelInstalledAddons.Text = $Addons.config.Addon.Length.ToString() + " Addons installed, " + $si + " Updates available"
            
        }

        
        $LoadSpinnerProgress.Visible = $false
        $ListViewBox.AutoResizeColumns(2)
        $ListViewBox.Columns[2].Width = 100
        $ListViewBox.Columns[3].Width = 100
        $ListViewBox.Columns[4].Width = 940 - ($ListViewBox.Columns[0].Width + $ListViewBox.Columns[1].Width + $ListViewBox.Columns[2].Width + $ListViewBox.Columns[3].Width)
        
        $ListViewBox.Visible = $true
        
        $ElvUILatestVersion = (Invoke-RestMethod -uri "https://git.tukui.org/elvui/elvui-classic/-/tags?format=atom")[0].title

        if ($Addons.config.ElvUI.CurrentVersion -ne $ElvUILatestVersion) {
            $ButtonElvUI.Text = "New version available
    Click to update
    V" + $Addons.config.ElvUI.CurrentVersion + " > V" + $ElvUILatestVersion
            $ButtonElvUI.BackColor = [System.Drawing.Color]::Orange
            $ButtonElvUI.ForeColor = [System.Drawing.Color]::Black
        } else {
            $ButtonElvUI.Text = "You have the latest version
    Click to re-install
    V" + $ElvUILatestVersion
            $ButtonElvUI.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
            $ButtonElvUI.ForeColor = [System.Drawing.Color]::White

        }
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

        $Url  = "https://addons-ecs.forgesvc.net/api/v2/addon/search?&gameId=1&sort=downloadCount&gameVersionFlavor=wow_classic&searchFilter=" + $Folder.Name

        $PossibleMatches = (Invoke-RestMethod -Uri $Url -TimeoutSec 20)

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

    $SearchResult = Invoke-RestMethod -uri ("https://addons-ecs.forgesvc.net/api/v2/addon/search?&gameId=1&sort=downloadCount&gameVersionFlavor=wow_classic&searchFilter=" + $SearchTerm) -TimeoutSec 20
    $SearchResult = ($SearchResult | sort-object -property name)
    $SearchOutput = [System.Collections.ArrayList]@()
    foreach ($Result in $SearchResult) {

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

        if ($i % 2 -eq 0) {
            $ListSearch_Item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#e0e0e0")
        } else {
            $ListSearch_Item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#c7c7c7")
        }
        $i++
    }

    $LabelSearchResult.Text = "Search results (" + $i.ToString() + ")"

    $ListSearchResults.AutoResizeColumns(2)
    $ListSearchResults.Columns[$ListSearchResults.Columns.Count - 1].Width = -2
    $ListSearchResults.Enabled = $true

    

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

    $ElvUIExcist = $Addons.config.ElvUI
    $ElvUIVersion = (Invoke-RestMethod -uri "https://git.tukui.org/elvui/elvui-classic/-/tags?format=atom")[0].title
    if ($null -eq $ElvUIExcist) {
            $subnode = $Addons.SelectSingleNode("config")
            
            $child = $Addons.CreateElement("ElvUI")

            $SubChildVersion = $Addons.CreateElement("CurrentVersion")
           
            $child.AppendChild($SubChildVersion)
           
            $child.CurrentVersion = $ElvUIVersion
            
            $subnode.AppendChild($child)
           
    } else {
        $Addons.config.ElvUI.CurrentVersion = $ElvUIVersion

    }

    $Addons.Save($XMLPath)

}

Function PullNewResources {
    #*** pull new resources if missing
    if ($Addons.config.Version -ne "2.2.0") {
       
        $url = "http://www.smosk.net/downloads/AddonManager.zip"
        $outfile = ".\Downloads\updater.zip"

        Invoke-WebRequest -Uri $url -OutFile $outfile

        Unzip -outpath ".\Downloads\" -zipfile $outfile

        Copy-Item -Path ".\Downloads\AddonManager\Resources\wallpaper_search.png" -Destination ".\Resources\wallpaper_search.png" -Recurse -Force
        Copy-Item -Path ".\Downloads\AddonManager\Resources\close.png" -Destination ".\Resources\close.png" -Recurse -Force
        Copy-Item -Path ".\Downloads\AddonManager\Resources\minimize.png" -Destination ".\Resources\minimize.png" -Recurse -Force
        Copy-Item -Path ".\Downloads\AddonManager\Resources\search.png" -Destination ".\Resources\search.png" -Recurse -Force

        Copy-Item -Path ".\Downloads\AddonManager\Update_SMOSK.exe" -Destination ".\Update_SMOSK.exe" -Recurse -Force

        Remove-Item -LiteralPath ".\Downloads\AddonManager\" -Force -Recurse
        Remove-Item -LiteralPath ".\Downloads\updater.zip" -Force -Recurse
        
        $Addons.config.Version = "2.2.0"
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

$SMOSKVersion = New-Object System.Xml.XmlDocument
$SMOSKVersionPath = "http://www.smosk.net/downloads/version.xml"
$SMOSKVersion.Load($SMOSKVersionPath)

#*** Download latest updater
PullNewResources

#***  Render the GUI
DrawGUI


} catch {
    $OSInfo = (get-computerinfo | select-object -property OSName, OSVersion)
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
