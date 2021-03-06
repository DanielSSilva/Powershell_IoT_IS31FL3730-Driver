# Implement your module commands in this script.

New-Variable -Name "TotalRegisters" -Value 11 -Option Constant -Scope Script
New-Variable -Name "CurrentRegisterValues" -Value @() -Scope Script
New-Variable -Name "Alphabet" -Value  @{
	"A" = 0x3E, 0x05, 0x3E
	"B" = 0x1F, 0x15, 0x0A
	"C" = 0x0E, 0x11, 0x11
	"D" = 0x1F, 0x11, 0x0E
	"E" = 0x1F, 0x15, 0x11
	"F" = 0x1F, 0x05, 0x01
	"G" = 0x0E, 0x11, 0x1D
	"H" = 0x1F, 0x04, 0x1F
	"I" = 0x11, 0x1F, 0x11
	"J" = 0x09, 0x11, 0x0F
	"K" = 0x1F, 0x04, 0x1B
	"L" = 0x1F, 0x10, 0x10
	"M" = 0x1F, 0x02, 0x04, 0x02, 0x1F
	"N" = 0x1F, 0x02, 0x0C, 0x1F
	"O" = 0x0E, 0x11, 0x0E
	"P" = 0x1F, 0x09, 0x06
	"Q" = 0x0E, 0x11, 0x09, 0x16
	"R" = 0x1F, 0x09, 0x16
	"S" = 0x12, 0x15, 0x09
	"T" = 0x01, 0x1F, 0x01
	"U" = 0x0F, 0x10, 0x10, 0x0F
	"V" = 0x0F, 0x10, 0x0F
	"W" = 0x0F, 0x10, 0x08,0x10,0x0F
	"X" = 0x1D, 0x04, 0x1D
	"Y" = 0x03, 0x1C, 0x03
	"Z" = 0x19, 0x15, 0x13
	"1" = 0x12, 0x1F, 0x10
	"2" = 0x19, 0x15, 0x12
	"3" = 0x11, 0x15, 0x0A
	"4" = 0x0E, 0x09, 0x1C
	"5" = 0x17, 0x15, 0x09
	"6" = 0x0E, 0x15, 0x08
	"7" = 0x19, 0x05, 0x03
	"8" = 0x0A, 0x15, 0x0A
	"9" = 0x02, 0x15, 0x0E
	"0" = 0x0E, 0x15, 0x0E
	"!" = 0x17
	"?" = 0x01, 0x15, 0x02
	"=" = 0x0A, 0x0A, 0x0A
	"/" = 0x10, 0x08, 0x04, 0x02
	"\" = 0x02, 0x04, 0x08, 0x10
	"|" = 0x1F
	"#" = 0x0A, 0x1F, 0x0A, 0x1F, 0x0A
	"&" = 0x0A, 0x15, 0x0A, 0x10
	" " = 0X00,0X00
	"-" = 0x04,0x04,0x04
	":" = 0x0A
	"'" = 0x03
	'"' = 0x03,0x03
	"(" = 0x0E,0x11
	")" = 0x11,0x0E
	"[" = 0x1F,0x11
	"]" = 0x11,0x1F
	"{" = 0x04,0x1B,0x11
	"}" = 0x11,0x1B,0x04
	"," = 0x10,0x08
	"." = 0x18,0x18
} -Scope Script

function Select-ScrollpHat {
        [int]$DeviceAddress = 0x60
        ######### Configuration Register and Value #########
        [int]$ConfigurationRegisterAddress = 0x00
        [int]$ConfigurationRegisterValue = 0x1B
        $Script:Device = Get-I2CDevice -Id $DeviceAddress -FriendlyName phat
        Set-I2CRegister -Device $Device -Register $ConfigurationRegisterAddress -Data $ConfigurationRegisterValue
        $Script:Device
}

#Combine the following two Functions to define the LEDs' brightness. Maximum brightness:
# - Set-PhatBrightnessByNumber 255
# - Set-PhatBrightness Highest
#Lowest:
# - Set-PhatBrightnessByNumber 1
# - Set-PhatBrightness Lowest
function Set-PhatBrightnessByNumber{
	[CmdletBinding()]
        param (
            [Parameter(Mandatory=$true)]
            [ValidateRange(0,255)]
            [int]$Intensity
		)
	[int]$PWMRegisterAddress = 0x19
	Set-I2CRegister -Device $Script:Device -Register $PWMRegisterAddress -Data $Intensity
	Update-PhatRegisters
}

function Set-PhatBrightness{
    [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true)]
            [ValidateSet('Lowest','Low', 'Medium', 'High', 'Highest')]
            [string]$Intensity
        )

        if($Intensity -eq 'Highest')
        {
            Write-Warning "This brightness setting causes some weird noise on my phat. I assume that's using too much energy. Use at your own risk!"
        }


        [int]$LightningEffectRegisterAddress = 0x0D
        $IntensityMap = @{
            Lowest = [convert]::toint32('1000',2)
            Low = [convert]::toint32('1001',2)
            Medium = [convert]::toint32('1110',2)
            High = [convert]::toint32('0001',2)
            Highest = [convert]::toint32('0111',2)
        }
    Set-I2CRegister -Device $Script:Device -Register $LightningEffectRegisterAddress -Data $IntensityMap[$Intensity]
    Update-PhatRegisters
}

function Write-PhatString {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline=$True)]
        [string]$text,
        [int]$WaitMiliseconds = 40,
        [System.Management.Automation.SwitchParameter]$forever,
        [int]$iterations = 0
    )
    Set-PhatLedsOff
    if($forever -or $iterations -gt 0)
    {
        $text +="  "
    }
    do
    {
        for($i =0; $i -lt $text.Length ; ++$i)
        {
            Write-PhatChar $text[$i]
                #After Writing the char, make sure to leave a space.
  #          Write-Host "Wrote char $($text[$i])"
            if($Script:CurrentRegisterValues.Count -lt $Script:TotalRegisters){ #We can still set an white column
                $Script:CurrentRegisterValues += 0
                Set-I2CRegister -Device $Script:Device -Register $Script:CurrentRegisterValues.Count -Data 0
            }
            Update-PhatRegisters
            Start-Sleep -Milliseconds $WaitMiliseconds
        }
        $iterations -=1
  #      Write-Host $iterations
    }while($iterations -gt 0 -OR $forever)
}

function Write-PhatChar {
    param(
        [ValidateLength(1,1)]
        [string]$char
    )

    #get respective bits from hashtable
    $bitsArray = $Script:Alphabet[$char] # this is an array with required data
    $totalRegistersRequired = $Script:CurrentRegisterValues.Count + $bitsArray.Count

    $registers = ($Script:CurrentRegisterValues.Count+1) .. $totalRegistersRequired

    if($totalRegistersRequired -gt $Script:TotalRegisters ) # this means that we will need to start shifting
    {
        $i = 0
        $wroteWhiteSpace = $false
        while($i -lt $bitsArray.Count)
        {
			if( $Script:CurrentRegisterValues.Count -ge $Script:TotalRegisters)
			{
				#send the first value out.
				$null, $Script:CurrentRegisterValues = $Script:CurrentRegisterValues

				#SHIFT!
				for($j = 1 ; $j -le 10; ++$j) #10 because we will leave the 11 to the new value
				{
					Set-I2CRegister -Device $Script:Device -Register $j -Data $Script:CurrentRegisterValues[$j-1]
					Update-PhatRegisters ########EDITED
				}
				#start by writing a white column
				if($wroteWhiteSpace -eq $false)
				{
					Set-I2CRegister -Device $Script:Device -Register 0xB -Data 0
					$Script:CurrentRegisterValues+= 0
					#Update-PhatRegisters
					$wroteWhiteSpace = $true
					continue
				}
			}

            Set-I2CRegister -Device $Script:Device -Register 0xB -Data $bitsArray[$i]
            $Script:CurrentRegisterValues += $bitsArray[$i++]
            Update-PhatRegisters
            #Start-Sleep -Milliseconds 5
        }
        return
    }
    #if we get here, this is one of the first letters
    $i = 0
    foreach($register in $registers)
    {
        Set-I2CRegister -Device $Script:Device -Register $register -Data $bitsArray[$i]
        $Script:CurrentRegisterValues += $bitsArray[$i++]
    }
}

function Update-PhatRegisters{
    [int]$UpdateRegisterAddress = 0x0C
    [int]$UpdateValue = 0xFF # for what I understood, it can be any value " A write operation of any 8-bit value to the Update Column Register is required to update the Data Registers"
    Set-I2CRegister -Device $Script:Device -Register $UpdateRegisterAddress -Data $UpdateValue
}

function Set-PhatLedsOff {
    foreach ($register in @(1 .. $Script:TotalRegisters)) {
        Set-I2CRegister -Device $Script:Device -Register $register -Data 0x0
    }
    $Script:CurrentRegisterValues = @()
    Update-PhatRegisters
}

function Set-PhatCrazyLeds () {
    $brightnessValues = 'Lowest','Low', 'Medium', 'High', 'Highest'
    $iteration
    while($true)
    {
        $randomRegister = Get-Random -Minimum 1 -Maximum 11
        $randomValue = Get-Random -Minimum 0 -Maximum 17

        Set-I2CRegister -Device $Script:Device -Register $randomRegister -Data $randomValue
        #if($iteration % 4 -eq 0)
        #{
            $brightnessIndex = Get-Random -Minimum 0 -Maximum ($brightnessValues.Count-1)
            Set-PhatBrightness -Intensity ($brightnessValues[$brightnessIndex])
        #}

        Update-PhatRegisters
        Start-Sleep -Milliseconds 30
        #++$iteration
    }
}

function Get-SpotifyCurrentlyPlayingInfo()
{
    $header = @{"Authorization" = "Bearer $(Get-Content -Path "/home/pi/token.txt")"}
	
	$trackInfo = ((Invoke-WebRequest -Uri "https://api.spotify.com/v1/me/player/currently-playing?market=PT" -Headers $header).Content | ConvertFrom-Json).item

$trackInfo.Artists[0].Name + " - "+ $trackInfo.name
}

Select-ScrollpHat
Set-PhatBrightness -Intensity Lowest
Set-PhatBrightnessByNumber 10

# Export only the functions using PowerShell standard verb-noun naming.
# Be sure to list each exported functions in the FunctionsToExport field of the module manifest file.
# This improves performance of command discovery in PowerShell.
Export-ModuleMember -Function *-*
