$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot '.local/test-recording'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
Add-Type -AssemblyName System.Speech
$speech = New-Object System.Speech.Synthesis.SpeechSynthesizer
$voices = $speech.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Culture.Name -like 'fr-*' }
if ($voices.Count -gt 0) { $speech.SelectVoice($voices[0].VoiceInfo.Name) }
$speech.Rate = -1
$speech.SetOutputToWaveFile("$outputDir/meeting.wav")
$speech.Speak('Bonjour à tous. Nous faisons un test de notre application de notes de réunion. Le premier sujet concerne la page de connexion. Nous décidons de conserver le bouton violet et de simplifier le formulaire. Alexandre préparera une maquette pour jeudi. Le deuxième sujet concerne les enregistrements. Nous allons utiliser OBS pour enregistrer les réunions en local. Le fichier vidéo restera sur notre ordinateur. Pour le premier test, nous ne mettrons pas de synchronisation dans le cloud. Il reste une question ouverte : faut-il ajouter un export PDF ? Nous prendrons cette décision après les retours des utilisateurs. Merci à tous, la réunion est terminée.')
$speech.Dispose()
$config = Get-Content "$projectRoot/.runtime/runtime.json" -Raw | ConvertFrom-Json
& $config.ffmpeg -y -v error -f lavfi -i 'color=c=0x252239:s=1280x720:r=10' -i "$outputDir/meeting.wav" -vf "drawtext=text='MEMORA  /  REUNION SIMULEE':fontcolor=white:fontsize=44:x=80:y=90,drawtext=text='01   Interface et maquette':fontcolor=0xb9acff:fontsize=32:x=80:y=240,drawtext=text='02   Enregistrement local avec OBS':fontcolor=white:fontsize=32:x=80:y=320,drawtext=text='03   Export PDF - question ouverte':fontcolor=white:fontsize=32:x=80:y=400" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -shortest "$outputDir/meeting.mkv"
if ($LASTEXITCODE -ne 0) { throw 'Test recording generation failed' }
Write-Host "$outputDir/meeting.mkv"
