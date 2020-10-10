
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework




function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath) 
}






Function update {


    $url = "https://www.smosk.net/downloads/AddonManager.zip"
    $outfile = ".\Downloads\updater.zip"

    if (Test-Path .\Downloads\AddonManager) {
        Remove-Item -LiteralPath ".\Downloads\AddonManager\" -Force -Recurse
    }
    if (Test-Path .\Downloads\updater.zip) {
        Remove-Item -LiteralPath ".\Downloads\updater.zip" -Force -Recurse
    }


    Invoke-WebRequest -Uri $url -OutFile $outfile


    Unzip -outpath ".\Downloads\" -zipfile $outfile

    Copy-Item -Path ".\Downloads\AddonManager\SMOSK.exe" -Destination ".\SMOSK.exe" -Recurse -Force
    Copy-Item -Path ".\Downloads\AddonManager\Uncompiled script\SMOSK_AddonManager.ps1" -Destination ".\Uncompiled script\SMOSK_AddonManager.ps1" -Recurse -Force


    Remove-Item -LiteralPath ".\Downloads\AddonManager\" -Force -Recurse
    Remove-Item -LiteralPath ".\Downloads\updater.zip" -Force -Recurse

   
    #[System.Windows.MessageBox]::Show("Updated to latest Version of SMOSK!",'SMOSK! Updater','OK','Information')

}

Function DrawGUI {

    #*** Close Smosk.exe ******************************************************************************************************
    $CloseSMOSK = New-Object System.Windows.Forms.Form
    $CloseSMOSK.Text ="SMOSK - Classic Addon Manager"
    $CloseSMOSK.minimumSize = New-Object System.Drawing.Size(500,250) 
    $CloseSMOSK.maximumSize = New-Object System.Drawing.Size(500,250) 
    $CloseSMOSK.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen 
    $CloseSMOSK.AutoSize = $true
    $CloseSMOSK.SizeGripStyle = "Hide"
    $CloseSMOSK.FormBorderStyle = [System.Windows.Forms.BorderStyle]::"None"
    $CloseSMOSK.BackColor = [System.Drawing.Color]::Black
    $CloseSMOSK.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\Splash.png")
    $CloseSMOSK.BackgroundImageLayout = "Zoom"


    #*** Button close
    $ButtonClose = New-Object System.Windows.Forms.Button
    $ButtonClose.Name = "ButtonCloseMainForm"
    $ButtonClose.Anchor = "Top","Left"
    $ButtonClose.Location = New-Object System.Drawing.Point(475, 5)
    $ButtonClose.Size = New-Object System.Drawing.Size(20, 20)
    $ButtonClose.TextAlign = "BottomCenter"
    $ButtonClose.FlatStyle = "PopUp"
    $ButtonClose.UseVisualStyleBackColor = $true
    $ButtonClose.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\close.png")
    $ButtonClose.BackgroundImageLayout = "Zoom"
    $ButtonClose.ForeColor = [System.Drawing.Color]::White
    $ButtonClose.BackColor = [System.Drawing.Color]::Black
    $ButtonClose.UseMnemonic = $true
    $ButtonClose.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $CloseSMOSK.Controls.Add($ButtonClose)

    #*** Button minimize
    $ButtonMinimize = New-Object System.Windows.Forms.Button
    $ButtonMinimize.Name = "ButtonCloseMainForm"
    $ButtonMinimize.Anchor = "Top","Left"
    $ButtonMinimize.Location = New-Object System.Drawing.Point(450, 5)
    $ButtonMinimize.Size = New-Object System.Drawing.Size(20, 20)
    #$ButtonMinimize.Text = "_"
    $ButtonMinimize.FlatStyle = "PopUp"
    $ButtonMinimize.UseVisualStyleBackColor = $true
    $ButtonMinimize.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\minimize.png")
    $ButtonMinimize.BackgroundImageLayout = "Zoom"
    $ButtonMinimize.ForeColor = [System.Drawing.Color]::White
    $ButtonMinimize.BackColor = [System.Drawing.Color]::Black
    
    $ButtonMinimize.Add_Click({
        $CloseSMOSK.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
    })

    $CloseSMOSK.Controls.Add($ButtonMinimize)

    #*** Label 
    $LabelUpdate = New-Object System.Windows.Forms.Label
    $LabelUpdate.Text = "SMOSK! Updater" 
    $LabelUpdate.Location  = New-Object System.Drawing.Point(0,50)
    $LabelUpdate.Size = New-Object System.Drawing.Size(500,50)
    $LabelUpdate.TextAlign = "MiddleCenter"
    $LabelUpdate.BackColor = [System.Drawing.Color]::Transparent
    $LabelUpdate.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $LabelUpdate.Font = [System.Drawing.Font]::new("Georgia", 10, [System.Drawing.FontStyle]::Bold)
    $CloseSMOSK.Controls.Add($LabelUpdate)

    #*** Label 
    $LabelStatus = New-Object System.Windows.Forms.Label
    $LabelStatus.Text = "Smosk.exe is still running
click update to close the program and continue" 
    $LabelStatus.Location  = New-Object System.Drawing.Point(2,120)
    $LabelStatus.Size = New-Object System.Drawing.Size(496,50)
    $LabelStatus.TextAlign = "MiddleCenter"
    $LabelStatus.Image = [System.Drawing.Image]::FromFile(".\Resources\splash_text_bg.png")
    $LabelStatus.BackColor = [System.Drawing.Color]::Transparent
    $LabelStatus.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffa500")
    $LabelStatus.Font = [System.Drawing.Font]::new("Georgia", 10, [System.Drawing.FontStyle]::Bold)
    $CloseSMOSK.Controls.Add($LabelStatus)


    #*** Button Continue
    $ButtonContinue = New-Object System.Windows.Forms.Button
    $ButtonContinue.Location = New-Object System.Drawing.Size(200,150)
    $ButtonContinue.Size = New-Object System.Drawing.Size(100,40)
    $ButtonContinue.Text = "Update"
    $ButtonContinue.FlatStyle = "Popup"
    $ButtonContinue.Anchor = "Bottom,Left"
    $ButtonContinue.ForeColor = [System.Drawing.Color]::White
    $ButtonContinue.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $ButtonContinue.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
    $CloseSMOSK.Controls.Add($ButtonContinue)

    $ButtonContinue.Add_Click({
        if ($Global:Updated -eq 0) {
            $ButtonContinue.Enabled = $false
            $LabelStatus.text = "Updating.."
            get-process | where-object {$_.path -eq (resolve-path -LiteralPath ".\SMOSK.exe").Path} | Stop-Process -Force
            update
            $LabelStatus.Text = "Updated to latest Version of SMOSK!"
            $LabelStatus.ForeColor = [System.Drawing.Color]::LightGreen
            $ButtonContinue.Text = "Close and start SMOSK!"
            $ButtonContinue.Enabled = $true
            $Global:Updated = 1
            
        } else {
            Start-Process ".\SMOSK.exe"
            $CloseSMOSK.Dispose()
        }
    })

 



    $CloseSMOSK.ShowDialog()
    
    $CloseSMOSK.Dispose()

    
}



try {

    if(get-process | where-object {$_.path -eq (resolve-path -LiteralPath ".\SMOSK.exe").Path}){
        $Global:Updated = 0
        DrawGUI
    } else {
        update
    }

} catch {
    $OSInfo = (get-computerinfo | select-object -property OSName, OSVersion)
    if (Test-Path ".\Resources\update_log.txt") {
        "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\update_log.txt" -Append
        $_ | Out-File ".\Resources\update_log.txt" -Append
    } else {
        "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\update_log.txt"
        $_ | Out-File ".\Resources\update_log.txt" -Append
        
    }
    [System.Windows.MessageBox]::Show("Something have caused the updater to fail. 

Make sure that the download folder is empty.

See error log for more info.
.\Resources\update_log.txt",'SMOSK! Error','OK','Information')

}




# SIG # Begin signature block
# MIInHAYJKoZIhvcNAQcCoIInDTCCJwkCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB12FkYQU8Lqcpe
# Ptq6mSqonxUl6lEDbe2YUnlxmgU5A6CCELYwggU0MIIEHKADAgECAhArWUCBCE0v
# PH+0zcxWMEdkMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAkdCMRswGQYDVQQI
# ExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNVBAoT
# D1NlY3RpZ28gTGltaXRlZDEkMCIGA1UEAxMbU2VjdGlnbyBSU0EgQ29kZSBTaWdu
# aW5nIENBMB4XDTIwMTAwNjAwMDAwMFoXDTIxMTAwNjIzNTk1OVowfTELMAkGA1UE
# BhMCU0UxDzANBgNVBBEMBjg5MiA0MTEQMA4GA1UEBwwHRG9tc2rDtjEZMBcGA1UE
# CQwQRG9tc2rDtnbDpGdlbiA4NjEXMBUGA1UECgwOSm9oYW4gRXJpa3Nzb24xFzAV
# BgNVBAMMDkpvaGFuIEVyaWtzc29uMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
# CgKCAQEA3/MXCxi47cYpdEbevmHD9rL7B0T0D4jO8Sw55lgZAoNfmqNz2hMEL27r
# CWa3zTiw7dITeWwKCzbqSeOqjNj5RrC5aaX8HFm021oEgcfyIXOdiSt8tGCmZ0p3
# QHPHi9QebXOMXyvKOvu25vvQTKwds8b3oBDHzRMcc/pEk6u/sbjRA17aR42/c9J4
# Eh49FtbaYpKMmvz0auHNFItXOMTxJnLRNPx/6m2SHQTKSUyFN2VzV0br4fJmFPtz
# WYa0XT7hHLn/HL9Hxm4dLE83yh2oSYGHgZL4atUgPnycprbsvLcByXoxaLO6EOwW
# xfkiY3LCGinV11g8LaegYgngQBwiMQIDAQABo4IBrzCCAaswHwYDVR0jBBgwFoAU
# DuE6qFM6MdWKvsG7rWcaA4WtNA4wHQYDVR0OBBYEFOOPhZ93itf+CxMWKBv7xP08
# iVntMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsG
# AQUFBwMDMBEGCWCGSAGG+EIBAQQEAwIEEDBKBgNVHSAEQzBBMDUGDCsGAQQBsjEB
# AgEDAjAlMCMGCCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQUzAIBgZn
# gQwBBAEwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5zZWN0aWdvLmNvbS9T
# ZWN0aWdvUlNBQ29kZVNpZ25pbmdDQS5jcmwwcwYIKwYBBQUHAQEEZzBlMD4GCCsG
# AQUFBzAChjJodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29SU0FDb2RlU2ln
# bmluZ0NBLmNydDAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20w
# HQYDVR0RBBYwFIESam9oZXJpODVAZ21haWwuY29tMA0GCSqGSIb3DQEBCwUAA4IB
# AQAng7eJh4DTmpITv8ehhUcuO3pJ4WFKFDxKY6TVKXC4XnHHwTEOsTgbsQeQoVW4
# Ffve/soxi5ob6FdL/dk/5SQYymStdTd4Jhhx4+QAFYg3dULNe6/kRyvmI5jKqru3
# tz6eOA7zJWxXQHsPAleOewkTVNEYQ3Hx0IRsyvG/9Jd/fScvAic26oH+xiuh3Zj3
# BBZQygJ2XH1Xe+t1NsDz9QaY3x0wYYTz20+ORS5IyqKFh5ijgr1rI+FB5iZDodXo
# qIQvEBSjZ37EMy3djiQdQ3ywCu6KQzBQMqff7L0DILeFvapu4KpXJDN+fc5/An7V
# 7NMnCpE1VmuywgIHPgxwm8scMIIFgTCCBGmgAwIBAgIQOXJEOvkit1HX02wQ3TE1
# lTANBgkqhkiG9w0BAQwFADB7MQswCQYDVQQGEwJHQjEbMBkGA1UECAwSR3JlYXRl
# ciBNYW5jaGVzdGVyMRAwDgYDVQQHDAdTYWxmb3JkMRowGAYDVQQKDBFDb21vZG8g
# Q0EgTGltaXRlZDEhMB8GA1UEAwwYQUFBIENlcnRpZmljYXRlIFNlcnZpY2VzMB4X
# DTE5MDMxMjAwMDAwMFoXDTI4MTIzMTIzNTk1OVowgYgxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJzZXkgQ2l0eTEeMBwGA1UE
# ChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYDVQQDEyVVU0VSVHJ1c3QgUlNB
# IENlcnRpZmljYXRpb24gQXV0aG9yaXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAgBJlFzYOw9sIs9CsVw127c0n00ytUINh4qogTQktZAnczomfzD2p
# 7PbPwdzx07HWezcoEStH2jnGvDoZtF+mvX2do2NCtnbyqTsrkfjib9DsFiCQCT7i
# 6HTJGLSR1GJk23+jBvGIGGqQIjy8/hPwhxR79uQfjtTkUcYRZ0YIUcuGFFQ/vDP+
# fmyc/xadGL1RjjWmp2bIcmfbIWax1Jt4A8BQOujM8Ny8nkz+rwWWNR9XWrf/zvk9
# tyy29lTdyOcSOk2uTIq3XJq0tyA9yn8iNK5+O2hmAUTnAU5GU5szYPeUvlM3kHND
# 8zLDU+/bqv50TmnHa4xgk97Exwzf4TKuzJM7UXiVZ4vuPVb+DNBpDxsP8yUmazNt
# 925H+nND5X4OpWaxKXwyhGNVicQNwZNUMBkTrNN9N6frXTpsNVzbQdcS2qlJC9/Y
# gIoJk2KOtWbPJYjNhLixP6Q5D9kCnusSTJV882sFqV4Wg8y4Z+LoE53MW4LTTLPt
# W//e5XOsIzstAL81VXQJSdhJWBp/kjbmUZIO8yZ9HE0XvMnsQybQv0FfQKlERPSZ
# 51eHnlAfV1SoPv10Yy+xUGUJ5lhCLkMaTLTwJUdZ+gQek9QmRkpQgbLevni3/GcV
# 4clXhB4PY9bpYrrWX1Uu6lzGKAgEJTm4Diup8kyXHAc/DVL17e8vgg8CAwEAAaOB
# 8jCB7zAfBgNVHSMEGDAWgBSgEQojPpbxB+zirynvgqV/0DCktDAdBgNVHQ4EFgQU
# U3m/WqorSs9UgOHYm8Cd8rIDZsswDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQF
# MAMBAf8wEQYDVR0gBAowCDAGBgRVHSAAMEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6
# Ly9jcmwuY29tb2RvY2EuY29tL0FBQUNlcnRpZmljYXRlU2VydmljZXMuY3JsMDQG
# CCsGAQUFBwEBBCgwJjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuY29tb2RvY2Eu
# Y29tMA0GCSqGSIb3DQEBDAUAA4IBAQAYh1HcdCE9nIrgJ7cz0C7M7PDmy14R3iJv
# m3WOnnL+5Nb+qh+cli3vA0p+rvSNb3I8QzvAP+u431yqqcau8vzY7qN7Q/aGNnwU
# 4M309z/+3ri0ivCRlv79Q2R+/czSAaF9ffgZGclCKxO/WIu6pKJmBHaIkU4MiRTO
# ok3JMrO66BQavHHxW/BBC5gACiIDEOUMsfnNkjcZ7Tvx5Dq2+UUTJnWvu6rvP3t3
# O9LEApE9GQDTF1w52z97GA1FzZOFli9d31kWTz9RvdVFGD/tSo7oBmF0Ixa1DVBz
# J0RHfxBdiSprhTEUxOipakyAvGp4z7h/jnZymQyd/teRCBaho1+VMIIF9TCCA92g
# AwIBAgIQHaJIMG+bJhjQguCWfTPTajANBgkqhkiG9w0BAQwFADCBiDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5
# MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJU
# cnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTgxMTAyMDAwMDAw
# WhcNMzAxMjMxMjM1OTU5WjB8MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRl
# ciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQKEw9TZWN0aWdv
# IExpbWl0ZWQxJDAiBgNVBAMTG1NlY3RpZ28gUlNBIENvZGUgU2lnbmluZyBDQTCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAIYijTKFehifSfCWL2MIHi3c
# fJ8Uz+MmtiVmKUCGVEZ0MWLFEO2yhyemmcuVMMBW9aR1xqkOUGKlUZEQauBLYq79
# 8PgYrKf/7i4zIPoMGYmobHutAMNhodxpZW0fbieW15dRhqb0J+V8aouVHltg1X7X
# FpKcAC9o95ftanK+ODtj3o+/bkxBXRIgCFnoOc2P0tbPBrRXBbZOoT5Xax+YvMRi
# 1hsLjcdmG0qfnYHEckC14l/vC0X/o84Xpi1VsLewvFRqnbyNVlPG8Lp5UEks9wO5
# /i9lNfIi6iwHr0bZ+UYc3Ix8cSjz/qfGFN1VkW6KEQ3fBiSVfQ+noXw62oY1YdMC
# AwEAAaOCAWQwggFgMB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0G
# A1UdDgQWBBQO4TqoUzox1Yq+wbutZxoDha00DjAOBgNVHQ8BAf8EBAMCAYYwEgYD
# VR0TAQH/BAgwBgEB/wIBADAdBgNVHSUEFjAUBggrBgEFBQcDAwYIKwYBBQUHAwgw
# EQYDVR0gBAowCDAGBgRVHSAAMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwu
# dXNlcnRydXN0LmNvbS9VU0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5
# LmNybDB2BggrBgEFBQcBAQRqMGgwPwYIKwYBBQUHMAKGM2h0dHA6Ly9jcnQudXNl
# cnRydXN0LmNvbS9VU0VSVHJ1c3RSU0FBZGRUcnVzdENBLmNydDAlBggrBgEFBQcw
# AYYZaHR0cDovL29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEA
# TWNQ7Uc0SmGk295qKoyb8QAAHh1iezrXMsL2s+Bjs/thAIiaG20QBwRPvrjqiXgi
# 6w9G7PNGXkBGiRL0C3danCpBOvzW9Ovn9xWVM8Ohgyi33i/klPeFM4MtSkBIv5rC
# T0qxjyT0s4E307dksKYjalloUkJf/wTr4XRleQj1qZPea3FAmZa6ePG5yOLDCBax
# q2NayBWAbXReSnV+pbjDbLXP30p5h1zHQE1jNfYw08+1Cg4LBH+gS667o6XQhACT
# PlNdNKUANWlsvp8gJRANGftQkGG+OY96jk32nw4e/gdREmaDJhlIlc5KycF/8zoF
# m/lv34h/wCOe0h5DekUxwZxNqfBZslkZ6GqNKQQCd3xLS81wvjqyVVp4Pry7bwMQ
# JXcVNIr5NsxDkuS6T/FikyglVyn7URnHoSVAaoRXxrKdsbwcCtp8Z359LukoTBh+
# xHsxQXGaSynsCz1XUNLK3f2eBVHlRHjdAd6xdZgNVCT98E7j4viDvXK6yz067vBe
# F5Jobchh+abxKgoLpbn0nu6YMgWFnuv5gynTxix9vTp3Los3QqBqgu07SqqUEKTh
# DfgXxbZaeTMYkuO1dfih6Y4KJR7kHvGfWocj/5+kUZ77OYARzdu1xKeogG/lU9Tg
# 46LC0lsa+jImLWpXcBw8pFguo/NbSwfcMlnzh6cabVgxghW8MIIVuAIBATCBkDB8
# MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYD
# VQQHEwdTYWxmb3JkMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxJDAiBgNVBAMT
# G1NlY3RpZ28gUlNBIENvZGUgU2lnbmluZyBDQQIQK1lAgQhNLzx/tM3MVjBHZDAN
# BglghkgBZQMEAgEFAKB8MBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqG
# SIb3DQEJBDEiBCD/I2kxxStuLF9OlOGvlNEDOSif2kxlmCaVII/zVu5rgjANBgkq
# hkiG9w0BAQEFAASCAQAemNSz/RFhtSy6HG2ynVBhtdPe55T3KHuJBLqIssGYK1cp
# z3Eooxb4tL5AoWEwIw5tGFY7FaO0isUwUdSLFtv7nt8uwDSBc0hCsDXn+eNnerSI
# N51DWmch9fqe+cPggywFGsaH8b+hLiG7ZOkpU8+ejPHK+ThlJ7sX4XlPwOF/xBU3
# jNRmf+gz2uH9MFC1U0M4uyMH74chyLBlkLInhNDO+Fylj9msjEBYFeGQgFEEUWGt
# MRtLJu8iANg5GpfP7TnKUX8hsKVkZo7a1FfOWbE0gcDwvoYsrvwMnsrbKKh+ieFS
# 6be8eOLZDbDjqlVaDRqBEszVHZHJoO+6SZrEjkdMoYITfjCCE3oGCisGAQQBgjcD
# AwExghNqMIITZgYJKoZIhvcNAQcCoIITVzCCE1MCAQMxDzANBglghkgBZQMEAgIF
# ADCCAQ0GCyqGSIb3DQEJEAEEoIH9BIH6MIH3AgEBBgorBgEEAbIxAgEBMDEwDQYJ
# YIZIAWUDBAIBBQAEIL6Fh5dWiMMr4EOYQzZwQUIyR7mtPyg4+y3yeVR47DJOAhUA
# vQXHotyRkObUeyj6iqhpOUg+mSwYDzIwMjAxMDA4MDU0MDQ2WqCBiqSBhzCBhDEL
# MAkGA1UEBhMCR0IxGzAZBgNVBAgMEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UE
# BwwHU2FsZm9yZDEYMBYGA1UECgwPU2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDDCNT
# ZWN0aWdvIFJTQSBUaW1lIFN0YW1waW5nIFNpZ25lciAjMaCCDfowggcGMIIE7qAD
# AgECAhA9GjVyMBWCYzDQE3F+gkEIMA0GCSqGSIb3DQEBDAUAMH0xCzAJBgNVBAYT
# AkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZv
# cmQxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDElMCMGA1UEAxMcU2VjdGlnbyBS
# U0EgVGltZSBTdGFtcGluZyBDQTAeFw0xOTA1MDIwMDAwMDBaFw0zMDA4MDEyMzU5
# NTlaMIGEMQswCQYDVQQGEwJHQjEbMBkGA1UECAwSR3JlYXRlciBNYW5jaGVzdGVy
# MRAwDgYDVQQHDAdTYWxmb3JkMRgwFgYDVQQKDA9TZWN0aWdvIExpbWl0ZWQxLDAq
# BgNVBAMMI1NlY3RpZ28gUlNBIFRpbWUgU3RhbXBpbmcgU2lnbmVyICMxMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAy1FQ/1b+/HhjcAGTWp4Y9DtT9gev
# IWz1og99HXAthHRIi5yKlQU9WYT5kYB5USzZirfBC5q6CorNZk8DiwG7MMqrvdvA
# TxJe/ArM4kWwATiKu03n1BxUmO05WM9bwi9FmDEK+TU4uDEubbQeOXLhuCq+n4yM
# GqVGrgsrTJn+LEv8KLkiOmYX0KpWiiHA85YktNCFJmu68G9kmHmmrb1c2FNrKwrW
# coqFRuMNGAbaxntBVjabFT7xahGg92b1GNCAVWOHaGbrDnlVglyj7Um4cYaekzew
# a6PqYmyjrpbouf2Lq8b2WVsAPFcgGC1wA6ec75LreaHHXex8tI9L3+td/KMg3ZI4
# 5WpROmuFnEygmAhpWwbnKhnQlZOLO2uKBQkp2Nba2+Ny+lxKL3sVVoYyv38FCZ0t
# Ks9Q4eZhINvHBoBcThRGvq5XcaKqbDCTHH53ywbpV82R9dUzchzh2spu6/MP7Hlb
# uyee6B7+L/K7f+nl0GfruA18pCtZA4uV7SIozfosO8cWEa/j1rFQZ2nFjvV50K3/
# h8z4f6r5ou1h+MiNadqx9FGR62dX0WQR62TLA71JVTpFQxgsJWzRLwwtb/VBNSSg
# 8mNZFl/ZpOksTtu7MRLGbfhbbgPcyxWPG41y7NsPFZDWEk7u4gAxJZM1b2pbpRJj
# QAGKuWmIOoi4DxkCAwEAAaOCAXgwggF0MB8GA1UdIwQYMBaAFBqh+GEZIA/DQXdF
# KI7RNV8GEgRVMB0GA1UdDgQWBBRvTYYH2DInniwp0tATA4CB3QWDKTAOBgNVHQ8B
# Af8EBAMCBsAwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDBA
# BgNVHSAEOTA3MDUGDCsGAQQBsjEBAgEDCDAlMCMGCCsGAQUFBwIBFhdodHRwczov
# L3NlY3RpZ28uY29tL0NQUzBEBgNVHR8EPTA7MDmgN6A1hjNodHRwOi8vY3JsLnNl
# Y3RpZ28uY29tL1NlY3RpZ29SU0FUaW1lU3RhbXBpbmdDQS5jcmwwdAYIKwYBBQUH
# AQEEaDBmMD8GCCsGAQUFBzAChjNodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3Rp
# Z29SU0FUaW1lU3RhbXBpbmdDQS5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3Nw
# LnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4ICAQDAaO2z2NRQm+/TdcsPO/ck
# 03o3RY0s7xb7UaksH7UltYqfXQvCGyB0jWYPNsuq9jYND36PS0p0Q2WsDSr2Cu1r
# bcUJOO0AG/jl3KYKQAVH74TKCbxDZoO/n+3bjj3RQWSxcAItA1dbGG8cLMsesgDo
# ugkvW4EENbmpY22OCMUY0eEhrPkSChTAEtt+JZ2sHRDAWqWD0h8aZlX8myri7DdX
# juXfljD4wJMLQxj5Am+pUa+4VwrzHAdpOY83nG3Xka6lLknpSt6z0Iy/OZANwIHO
# 8CoHOgymLVHScvNTxvm97+8MaUl3nyxWxOmhCD0HrsUe1oQix7x9QxtYOGJO0QUl
# hMVC+B8v9tv6q4xU7EWKbBJNMFpS5aQXCSLm72/1X4ZD36EtvUpGkqCBlixhl39A
# b9g/jDVaq9HGoDuFZlSA7x8a9fGbsKEnfbLnC8/2LZxYE5SphvxFUqIobX90D1KR
# SXrpEvipO7CS/X2RFOlbbUiU8siW7gU4s8XsMD/hByAEsdiLvP2zPm/yAlMG9KDt
# yZpyo5dfAPvLY9DozXT9dcnUNkW6exJZcu3n8npQAHj4Q5pG2N+/VNRescfRvBuD
# 9CvnC+hHyFOezBqs9vqKdVNsIIWp1bhquiSOiisIkZ83BBz2b6LdNKqR/8YVLh5C
# GgkpT/TGzeKRotNADI544zCCBuwwggTUoAMCAQICEDAPb6zdZph0fKlGNqd4Lbkw
# DQYJKoZIhvcNAQEMBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVy
# c2V5MRQwEgYDVQQHEwtKZXJzZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVT
# VCBOZXR3b3JrMS4wLAYDVQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24g
# QXV0aG9yaXR5MB4XDTE5MDUwMjAwMDAwMFoXDTM4MDExODIzNTk1OVowfTELMAkG
# A1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMH
# U2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSUwIwYDVQQDExxTZWN0
# aWdvIFJTQSBUaW1lIFN0YW1waW5nIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAyBsBr9ksfoiZfQGYPyCQvZyAIVSTuc+gPlPvs1rAdtYaBKXOR4O1
# 68TMSTTL80VlufmnZBYmCfvVMlJ5LsljwhObtoY/AQWSZm8hq9VxEHmH9EYqzcRa
# ydvXXUlNclYP3MnjU5g6Kh78zlhJ07/zObu5pCNCrNAVw3+eolzXOPEWsnDTo8Tf
# s8VyrC4Kd/wNlFK3/B+VcyQ9ASi8Dw1Ps5EBjm6dJ3VV0Rc7NCF7lwGUr3+Az9ER
# CleEyX9W4L1GnIK+lJ2/tCCwYH64TfUNP9vQ6oWMilZx0S2UTMiMPNMUopy9Jv/T
# UyDHYGmbWApU9AXn/TGs+ciFF8e4KRmkKS9G493bkV+fPzY+DjBnK0a3Na+WvtpM
# YMyou58NFNQYxDCYdIIhz2JWtSFzEh79qsoIWId3pBXrGVX/0DlULSbuRRo6b83X
# hPDX8CjFT2SDAtT74t7xvAIo9G3aJ4oG0paH3uhrDvBbfel2aZMgHEqXLHcZK5OV
# mJyXnuuOwXhWxkQl3wYSmgYtnwNe/YOiU2fKsfqNoWTJiJJZy6hGwMnypv99V9sS
# dvqKQSTUG/xypRSi1K1DHKRJi0E5FAMeKfobpSKupcNNgtCN2mu32/cYQFdz8HGj
# +0p9RTbB942C+rnJDVOAffq2OVgy728YUInXT50zvRq1naHelUF6p4MCAwEAAaOC
# AVowggFWMB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQW
# BBQaofhhGSAPw0F3RSiO0TVfBhIEVTAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/
# BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUd
# IAAwUAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VT
# RVJUcnVzdFJTQUNlcnRpZmljYXRpb25BdXRob3JpdHkuY3JsMHYGCCsGAQUFBwEB
# BGowaDA/BggrBgEFBQcwAoYzaHR0cDovL2NydC51c2VydHJ1c3QuY29tL1VTRVJU
# cnVzdFJTQUFkZFRydXN0Q0EuY3J0MCUGCCsGAQUFBzABhhlodHRwOi8vb2NzcC51
# c2VydHJ1c3QuY29tMA0GCSqGSIb3DQEBDAUAA4ICAQBtVIGlM10W4bVTgZF13wN6
# MgstJYQRsrDbKn0qBfW8Oyf0WqC5SVmQKWxhy7VQ2+J9+Z8A70DDrdPi5Fb5WEHP
# 8ULlEH3/sHQfj8ZcCfkzXuqgHCZYXPO0EQ/V1cPivNVYeL9IduFEZ22PsEMQD43k
# +ThivxMBxYWjTMXMslMwlaTW9JZWCLjNXH8Blr5yUmo7Qjd8Fng5k5OUm7Hcsm1B
# bWfNyW+QPX9FcsEbI9bCVYRm5LPFZgb289ZLXq2jK0KKIZL+qG9aJXBigXNjXqC7
# 2NzXStM9r4MGOBIdJIct5PwC1j53BLwENrXnd8ucLo0jGLmjwkcd8F3WoXNXBWia
# p8k3ZR2+6rzYQoNDBaWLpgn/0aGUpk6qPQn1BWy30mRa2Coiwkud8TleTN5IPZs0
# lpoJX47997FSkc4/ifYcobWpdR9xv1tDXWU9UIFuq/DQ0/yysx+2mZYm9Dx5i1xk
# zM3uJ5rloMAMcofBbk1a0x7q8ETmMm8c6xdOlMN4ZSA7D0GqH+mhQZ3+sbigZSo0
# 4N6o+TzmwTC7wKBjLPxcFgCo0MR/6hGdHgbGpm0yXbQ4CStJB6r97DDa8acvz7f9
# +tCjhNknnvsBZne5VhDhIG7GrrH5trrINV0zdo7xfCAMKneutaIChrop7rRaALGM
# q+P5CslUXdS5anSevUiumDGCBCwwggQoAgEBMIGRMH0xCzAJBgNVBAYTAkdCMRsw
# GQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDElMCMGA1UEAxMcU2VjdGlnbyBSU0EgVGlt
# ZSBTdGFtcGluZyBDQQIQPRo1cjAVgmMw0BNxfoJBCDANBglghkgBZQMEAgIFAKCC
# AWswGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0y
# MDEwMDgwNTQwNDZaMD8GCSqGSIb3DQEJBDEyBDBzb6iwGKHRJh50JJZaeNUw6aOD
# Qt+l4WdiuQfqtcVBdaY7aFbPGl6ULeP7S5cFgiMwge0GCyqGSIb3DQEJEAIMMYHd
# MIHaMIHXMBYEFCXIrHNOSFC3+NkTkagbkkk2ZZ9hMIG8BBQC1luV4oNwwVcAlfqI
# +SPdk3+tjzCBozCBjqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBK
# ZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRS
# VVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlv
# biBBdXRob3JpdHkCEDAPb6zdZph0fKlGNqd4LbkwDQYJKoZIhvcNAQEBBQAEggIA
# RYS678rDCqr4gMAgyXCrllCwpfztcUNWk3Uqnlg5PNekWhwWVYX5daFPSYtDn1Uk
# Hk8gmzk75GCy1UANCe3m34zpKkqWXgw6Pn3wUVStaayMPfIXw2nid/fk4fe/Az1Z
# 9Qoav6369Hos3kr2rsi9zZoK+/TeQkB4lxnSnYS1anbKGL9XlWNvVR+/A9mkrZjn
# AIAJ9fs9yKGnelrHVSiYdU5G5L8RLbKljKaTdjUkGOtIvgi6yoUIRCMI8oeMqtof
# aJ7/5dmxC5+Ot0Kwf5cFnpK6uz5g/vrIG924eYzpcvY85bjMo8WAMcZn1xZp9Okh
# 7tpK3y9sgQrCnWD9UaAQ1rvK5HjqWgA6uZ+9t/O6dhmoPslAJHyeKEjOn0hvqGoX
# SaOXUDYgfXjc7vInpEJXC9EpPixN3P/OKZnTjHiI/pjRXsIjEEQ6AgmFb97lKCiR
# KtWmKnvMlhAhClRwgyoC01vR7FXWqHFs3oPr7DiE4eECa7BsXFCXPi3nTZed0uaU
# OQ0TcYmw2LQfH2759bHzjE5QtLnmU6IoiQc7PJ1uMAtSeqNzY08vbugYBNgb4kKV
# AUcUKExkKS9wAeQCm3q9+G8UmOGM5yDticSI0AIbMoYXMS57yDSAilFloQpAWzgI
# MIVZ504xM6vfMc+VauFZ+5Jo3G7DIPDw62rIkj87Rs4=
# SIG # End signature block
